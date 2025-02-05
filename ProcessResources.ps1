# Import functions from separate scripts
. "$PSScriptRoot\PseudoCostCalculations.ps1"
. "$PSScriptRoot\ExportFunctions.ps1"
. "$PSScriptRoot\LoggingFunctions.ps1"
. "$PSScriptRoot\ResourceProcessingFunctions.ps1"

# Main execution block
try {
    # Define subscription ID
    $subscriptionId = (az account show --query "id" -o tsv).Trim()
    if (-not $subscriptionId) {
        throw "Failed to retrieve subscription ID. Please ensure you are logged in to Azure."
    }

    # Define paths
    $csvDir = Join-Path $PSScriptRoot "output\csv"
    $jsonDir = Join-Path $PSScriptRoot "output\json"
    
    # Verify required CSV files exist
    $csvFiles = @{
        'ServiceMap' = Join-Path $csvDir "AzureServiceMap.csv"
        'UserRoles' = Join-Path $csvDir "AzureUserRoles.csv"
        'ResourceGraph' = Join-Path $csvDir "AzureResourceGraph.csv"
    }
    
    foreach ($file in $csvFiles.GetEnumerator()) {
        if (-not (Test-Path $file.Value)) {
            if ($file.Key -eq 'ResourceGraph') {
                $warningMessage = "Resource Graph data not found: $($file.Value). Continuing without it."
                Write-Warning $warningMessage
                Write-Message -message $warningMessage -type "WARNING"
                $csvFiles.Remove('ResourceGraph')
            } else {
                $errorMessage = "Required CSV file not found: $($file.Value). Please run Generate CSVs first."
                throw $errorMessage
            }
        }
    }

    $serviceMap = Import-Csv -Path $csvFiles['ServiceMap']
    $resourceGraphData = if ($csvFiles.ContainsKey('ResourceGraph')) {
        Import-Csv -Path $csvFiles['ResourceGraph']
    } else { @() }

    # Merge Resource Graph data with service map
    if ($resourceGraphData.Count -gt 0) {
        Write-Message -message "Merging Resource Graph data with service map..."
        foreach ($resource in $serviceMap) {
            $graphData = $resourceGraphData | Where-Object { 
                $_.name -eq $resource.name -and 
                $_.resourceGroup -eq $resource.resourceGroup 
            } | Select-Object -First 1
            
            if ($graphData) {
                $resource | Add-Member -NotePropertyName "ResourceGraphProperties" -NotePropertyValue $graphData.properties -Force
            }
        }
    }

    # Create json output directory if it doesn't exist
    if (-not (Test-Path $jsonDir)) {
        New-Item -ItemType Directory -Force -Path $jsonDir | Out-Null
    }

    # Calculate total estimated cost including role assignments
    $totalCost = Get-EstimatedCost -resourceType 'roleassignments' -operationCount 1
    foreach ($resource in $serviceMap) {
        $resourceType = $resource.type.ToLower()
        $totalCost += Get-EstimatedCost -resourceType $resourceType
    }

    Write-Host "Total estimated cost for all operations: `$$([math]::Round($totalCost, 2)) USD"
    Write-Host "This will process $(($serviceMap | Measure-Object).Count) resources and generate detailed JSON files."
    $confirmation = Read-Host "Do you want to proceed? (yes/no/ask)"
    
    if ($confirmation.ToLower() -eq "no") {
        Write-Message -message "Operation cancelled by user" -type "INFO"
        Write-Host "Operation cancelled by user"
        exit 2  # Special exit code for user cancellation
    }

    # Set global confirmation mode based on user input
    $confirmationMode = $confirmation.ToLower()

    # Increase the depth limit for JSON serialization
    $depthLimit = 10

    # Define refresh interval in days (0 to refresh all resources)
    $refreshIntervalDays = 30

    # Process individual resources
    $allRelationships = @()
    $processedResources = @()
    $skippedResources = @()
    $mappedResources = @()
    foreach ($resource in $serviceMap) {
        $result = Process-Resource -resource $resource -jsonDir $jsonDir -confirmationMode $confirmationMode -depthLimit $depthLimit -refreshIntervalDays $refreshIntervalDays
        switch ($result.Status) {
            "Processed" {
                $processedResources += $result.Resource
                $allRelationships += $result.Relationships
                Write-Message -message "Successfully processed resource: $($result.Resource.name)" -type "INFO"
                Write-Host "Successfully processed resource: $($result.Resource.name)"
            }
            "Skipped" {
                $mappedResources += $result.Resource
                Write-Message -message "[INFO] Skipped - file exists for $($result.Resource.name)" -type "INFO"
            }
            "Failed" {
                $skippedResources += $result.Resource
            }
        }
    }

    # Export relationships for visualization (only for successfully processed resources)
    if ($processedResources.Count -gt 0) {
        $resourceMapping = @{
            resources = $processedResources + $mappedResources | ForEach-Object {
                @{
                    id = $_.name
                    type = $_.type
                    resourceGroup = $_.resourceGroup
                    location = $_.location
                    properties = if ($_.DetailedProperties) { 
                        $_.DetailedProperties | ConvertFrom-Json 
                    } else { 
                        $null 
                    }
                }
            }
            relationships = $allRelationships
            metadata = @{
                subscriptionId = $subscriptionId
                generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                resourceCount = $processedResources.Count + $mappedResources.Count
                relationshipCount = $allRelationships.Count
            }
        }

        Export-JsonToFile -Data $resourceMapping -FilePath (Join-Path $jsonDir "AzureResourceMapping.json") -Description "complete resource mapping"

        Write-Host "`nResource processing completed"
        Write-Message -message "Resource processing completed" -type "INFO"
        Write-Host "Resource mapping and details are available in: $jsonDir"
    } else {
        Write-Host "`nNo resources were processed, skipping relationship export."
        Write-Message -message "No resources were processed, skipping relationship export." -type "INFO"
    }

    # Reporting
    Write-Host "`nSummary Report:"
    Write-Host "Total resources in service map: $($serviceMap.Count)"
    Write-Host "Processed resources: $($processedResources.Count)"
    Write-Host "Skipped resources: $($skippedResources.Count)"
    if ($skippedResources.Count -gt 0) {
        Write-Host "`nSkipped Resources:"
        $skippedResources | ForEach-Object { Write-Host " - $($_.name) in $($_.resourceGroup)" }
        $skippedResources | Export-Csv -Path (Join-Path $csvDir "SkippedResources.csv") -NoTypeInformation
        Write-Host "`nSkipped resources have been exported to: $(Join-Path $csvDir "SkippedResources.csv")"
    }
}
catch {
    $errorMessage = "Failed to process resources: $_"
    Write-Error $errorMessage
    Write-Message -message $errorMessage -type "ERROR"
    exit 1
}
