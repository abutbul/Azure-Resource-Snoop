function Process-Resource {
    param (
        [Parameter(Mandatory=$true)]
        [pscustomobject]$resource,
        [Parameter(Mandatory=$true)]
        [string]$jsonDir,
        [Parameter(Mandatory=$true)]
        [string]$confirmationMode,
        [Parameter(Mandatory=$true)]
        [int]$depthLimit,
        [Parameter(Mandatory=$true)]
        [int]$refreshIntervalDays
    )

    $resourceType = $resource.type.ToLower()
    $fileNameDetails = "$($resource.name)_details.json"
    $fileName = "$($resource.name).json"
    $outputPathDetails = Join-Path $jsonDir $fileNameDetails
    $outputPath = Join-Path $jsonDir $fileName

    # Check if the JSON file already exists and its creation time
    if (Test-Path $outputPathDetails) {
        $fileCreationTime = (Get-Item $outputPathDetails).CreationTime
        $daysOld = (New-TimeSpan -Start $fileCreationTime -End (Get-Date)).Days
        if ($daysOld -le $refreshIntervalDays) {
            return @{ Status = "Skipped"; Resource = $resource }
        }
    } elseif (Test-Path $outputPath) {
        $fileCreationTime = (Get-Item $outputPath).CreationTime
        $daysOld = (New-TimeSpan -Start $fileCreationTime -End (Get-Date)).Days
        if ($daysOld -le $refreshIntervalDays) {
            return @{ Status = "Skipped"; Resource = $resource }
        }
    }

    try {
        $details = switch -Wildcard ($resourceType) {
            "*networksecuritygroups*" {
                if (-not (Confirm-Costs -operation "Get NSG rules for $($resource.name)" -resourceType 'networksecuritygroups' -confirmationMode $confirmationMode)) {
                    return @{ Status = "Skipped"; Resource = $resource }
                }
                $rules = az network nsg rule list --resource-group $resource.resourceGroup --nsg-name $resource.name 2>&1
                if ($LASTEXITCODE -ne 0) { throw $rules }
                $rules | ConvertFrom-Json
            }
            "*virtualnetworks*" {
                if (-not (Confirm-Costs -operation "Get VNet details for $($resource.name)" -resourceType 'virtualnetworks' -confirmationMode $confirmationMode)) {
                    return @{ Status = "Skipped"; Resource = $resource }
                }
                $vnet = az network vnet show --resource-group $resource.resourceGroup --name $resource.name 2>&1
                if ($LASTEXITCODE -ne 0) { throw $vnet }
                $vnet | ConvertFrom-Json
            }
            "*virtualmachines*" {
                if (-not (Confirm-Costs -operation "Get VM details for $($resource.name)" -resourceType 'virtualmachines' -confirmationMode $confirmationMode)) {
                    return @{ Status = "Skipped"; Resource = $resource }
                }
                $vm = az vm show --resource-group $resource.resourceGroup --name $resource.name 2>&1
                if ($LASTEXITCODE -ne 0) { throw $vm }
                $vm | ConvertFrom-Json
            }
            "*roleassignments*" {
                if (-not (Confirm-Costs -operation "Retrieve role assignments" -resourceType 'roleassignments' -confirmationMode $confirmationMode)) {
                    return @{ Status = "Skipped"; Resource = $resource }
                }
                try {
                    Write-Message -message "Retrieving role assignments..."
                    Write-Host "Retrieving role assignments..."
                    $roleAssignmentsResult = az role assignment list --all 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $roleAssignments = $roleAssignmentsResult | ConvertFrom-Json
                        Export-JsonToFile -Data $roleAssignments -FilePath (Join-Path $jsonDir "roleassignments_details.json") -Description "role assignments"
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
            }
            default {
                if (-not (Confirm-Costs -operation "Get details for $($resource.name)" -resourceType $resourceType -confirmationMode $confirmationMode)) {
                    return @{ Status = "Skipped"; Resource = $resource }
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

            Export-JsonToFile -Data $details -FilePath $outputPathDetails -Description "resource details for $($resource.name)"
            $resource | Add-Member -NotePropertyName "DetailedProperties" -NotePropertyValue ($details | ConvertTo-Json -Depth $depthLimit -Compress) -Force
            return @{ Status = "Processed"; Resource = $resource; Relationships = $relationships }
        }
    }
    catch {
        $warningMessage = "Failed to get details for resource: $($resource.name). Error: $_"
        Write-Warning $warningMessage
        Write-Message -message $warningMessage -type "WARNING"
        return @{ Status = "Failed"; Resource = $resource }
    }
}
