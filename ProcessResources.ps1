# Import functions from separate scripts
. "$PSScriptRoot\PseudoCostCalculations.ps1"
. "$PSScriptRoot\ExportFunctions.ps1"
. "$PSScriptRoot\LoggingFunctions.ps1"



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

    # Process role assignments with confirmation if needed
    $roleAssignments = $null
    if (Confirm-Costs -operation "Retrieve role assignments" -resourceType 'roleassignments' -confirmationMode $confirmationMode) {
        try {
            Write-Message -message "Retrieving role assignments..."
            Write-Host "Retrieving role assignments..."
            $roleAssignmentsResult = az role assignment list --all 2>&1
            if ($LASTEXITCODE -eq 0) {
                $roleAssignments = $roleAssignmentsResult | ConvertFrom-Json
                Export-JsonToFile -Data $roleAssignments -FilePath (Join-Path $jsonDir "RoleAssignments_Detailed.json") -Description "role assignments"
            } else {
                $warningMessage = "Failed to get role assignments: $roleAssignmentsResult"
                Write-Warning $warningMessage
                Write-Message -message $warningMessage -type "WARNING"
            }
        }
        catch {
            $warningMessage = "Failed to process role assignments: $_"
            Write-Warning $warningMessage
            Write-Message -message $warningMessage -type "WARNING"
        }
    } else {
        Write-Message -message "Skipping role assignments processing..." -type "INFO"
        Write-Host "Skipping role assignments processing..."
    }

    # Increase the depth limit for JSON serialization
    $depthLimit = 10

    # Process individual resources
    $allRelationships = @()
    $processedResources = @()
    foreach ($resource in $serviceMap) {
        $resourceType = $resource.type.ToLower()
        $fileName = "$($resource.name)_details.json"
        $outputPath = Join-Path $jsonDir $fileName
        
        try {
            $details = switch -Wildcard ($resourceType) {
                "*networksecuritygroups*" {
                    if (-not (Confirm-Costs -operation "Get NSG rules for $($resource.name)" -resourceType 'networksecuritygroups' -confirmationMode $confirmationMode)) {
                        Write-Host "Skipping NSG rules for $($resource.name) due to user choice"
                        continue
                    }
                    $rules = az network nsg rule list --resource-group $resource.resourceGroup --nsg-name $resource.name 2>&1
                    if ($LASTEXITCODE -ne 0) { throw $rules }
                    $rules | ConvertFrom-Json
                }
                "*virtualnetworks*" {
                    if (-not (Confirm-Costs -operation "Get VNet details for $($resource.name)" -resourceType 'virtualnetworks' -confirmationMode $confirmationMode)) {
                        Write-Host "Skipping VNet details for $($resource.name) due to user choice"
                        continue
                    }
                    $vnet = az network vnet show --resource-group $resource.resourceGroup --name $resource.name 2>&1
                    if ($LASTEXITCODE -ne 0) { throw $vnet }
                    $vnet | ConvertFrom-Json
                }
                "*virtualmachines*" {
                    if (-not (Confirm-Costs -operation "Get VM details for $($resource.name)" -resourceType 'virtualmachines' -confirmationMode $confirmationMode)) {
                        Write-Host "Skipping VM details for $($resource.name) due to user choice"
                        continue
                    }
                    $vm = az vm show --resource-group $resource.resourceGroup --name $resource.name 2>&1
                    if ($LASTEXITCODE -ne 0) { throw $vm }
                    $vm | ConvertFrom-Json
                }
                default {
                    if (-not (Confirm-Costs -operation "Get details for $($resource.name)" -resourceType $resourceType -confirmationMode $confirmationMode)) {
                        Write-Host "Skipping details for $($resource.name) due to user choice"
                        continue
                    }
                    $resourceDetails = az resource show --name $resource.name --resource-type $resource.type --resource-group $resource.resourceGroup 2>&1
                    if ($LASTEXITCODE -ne 0) { throw $resourceDetails }
                    $resourceDetails | ConvertFrom-Json
                }
            }
            
            if ($null -ne $details) {
                # Extract and store relationships
                $relationships = @()
                if ($details.properties.PSObject.Properties.Name -contains "networkInterfaces") {
                    $relationships += @{
                        sourceId = $resource.name
                        targetId = $details.properties.networkInterfaces.id
                        type = "uses"
                    }
                }
                if ($details.properties.PSObject.Properties.Name -contains "virtualNetwork") {
                    $relationships += @{
                        sourceId = $resource.name
                        targetId = $details.properties.virtualNetwork.id
                        type = "belongs_to"
                    }
                }
                $allRelationships += $relationships

                Export-JsonToFile -Data $details -FilePath $outputPath -Description "resource details for $($resource.name)"
                $resource | Add-Member -NotePropertyName "DetailedProperties" -NotePropertyValue ($details | ConvertTo-Json -Depth $depthLimit -Compress) -Force
                $processedResources += $resource
                Write-Message -message "Successfully processed resource: $($resource.name)" -type "INFO"
                Write-Host "Successfully processed resource: $($resource.name)"
            }
        }
        catch {
            $warningMessage = "Failed to get details for resource: $($resource.name). Error: $_"
            Write-Warning $warningMessage
            Write-Message -message $warningMessage -type "WARNING"
            # Add the resource to processed resources even if details retrieval failed
            $processedResources += $resource
        }
    }

    # Export relationships for visualization (only for successfully processed resources)
    $resourceMapping = @{
        resources = $processedResources | ForEach-Object {
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
            resourceCount = $processedResources.Count
            relationshipCount = $allRelationships.Count
        }
    }

    Export-JsonToFile -Data $resourceMapping -FilePath (Join-Path $jsonDir "AzureResourceMapping.json") -Description "complete resource mapping"

    Write-Host "`nResource processing completed"
    Write-Message -message "Resource processing completed" -type "INFO"
    Write-Host "Resource mapping and details are available in: $jsonDir"
}
catch {
    $errorMessage = "Failed to process resources: $_"
    Write-Error $errorMessage
    Write-Message -message $errorMessage -type "ERROR"
    exit 1
}
