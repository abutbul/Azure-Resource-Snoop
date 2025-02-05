param (
    [string]$csvPath = "output/csv/SkippedResources.csv"
)

# Import logging functions
. "$PSScriptRoot/LoggingFunctions.ps1"

if (-not (Test-Path $csvPath)) {
    Write-Message -message "CSV file not found: $csvPath" -type "ERROR"
    exit 1
}

try {
    Write-Message -message "Starting to process skipped resources from: $csvPath" -type "INFO"
    $skippedResources = Import-Csv -Path $csvPath
    $allResourceDetails = @()
    foreach ($resource in $skippedResources) {
        Write-Message -message "Processing resource: $($resource.name)" -type "INFO"
        
        # Construct ResourceId from available fields
        $resourceId = "/subscriptions/$((Get-AzContext).Subscription.Id)/resourceGroups/$($resource.resourceGroup)/providers/$($resource.type)/$($resource.name)"
        $resource | Add-Member -NotePropertyName "ResourceId" -NotePropertyValue $resourceId -Force
        
        # Attempt to gather resource details using Azure CLI
        Write-Message -message "Attempting to get details for ResourceId: $resourceId" -type "INFO"
        $cliOutput = az resource show --ids $resourceId 2>&1
        if ($LASTEXITCODE -eq 0) {
            $resourceDetailsCli = $cliOutput | ConvertFrom-Json
            $allResourceDetails += $resourceDetailsCli
            $safeName = $resource.name -replace '/', '_'
            $detailPath = Join-Path "output/json" "Skipped_${safeName}_CLI.json"
            New-Item -ItemType Directory -Force -Path (Split-Path $detailPath) | Out-Null
            $resourceDetailsCli | ConvertTo-Json -Depth 10 | Out-File $detailPath
            Write-Message -message "Azure CLI details saved to $detailPath" -type "INFO"
        } else {
            Write-Message -message "Azure CLI failed for resource $($resource.name), switching to PowerShell command" -type "WARNING"
            try {
                $resourceDetailsPS = Get-AzResource -ResourceId $resourceId -ErrorAction Stop
                $allResourceDetails += $resourceDetailsPS
                $safeName = $resource.name -replace '/', '_'
                $detailPath = Join-Path "output/json" "Skipped_${safeName}_PS.json"
                New-Item -ItemType Directory -Force -Path (Split-Path $detailPath) | Out-Null
                $resourceDetailsPS | ConvertTo-Json -Depth 10 | Out-File $detailPath
                Write-Message -message "PowerShell details saved to $detailPath" -type "INFO"
            } catch {
                Write-Message -message "Failed to get details via PowerShell for resource $($resource.name). Error: $_" -type "WARNING"
            }
        }
    }
    # Save all resource details to a single JSON file
    $allResourceDetails | ConvertTo-Json -Depth 10 | Out-File "output/json/skipped_resources_details.json"
    Write-Message -message "All resource details saved to output/json/skipped_resources_details.json" -type "INFO"
    Write-Message -message "Processing of skipped resources completed successfully" -type "INFO"
    exit 0
}
catch {
    Write-Message -message "An error occurred while processing skipped resources: $_" -type "ERROR"
    exit 1
}
