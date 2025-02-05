# This script generates CSV files from the Azure resources. It collects data from various Azure services and formats it into CSV files for further processing.

# Dot-source the logging functions
. "$PSScriptRoot\LoggingFunctions.ps1"

try {
    Write-Message "Verifying Azure authentication..."
    
    # Dot-source the AzureLogin script to import its functions
    . "$PSScriptRoot\AzureLogin.ps1" -CheckLoginOnly

    try {
        Write-Message "Starting CSV generation..."
        
        # Define output paths
        $outputDir = Join-Path $PSScriptRoot "output\csv"
        $serviceMapPath = Join-Path $outputDir "AzureServiceMap.csv"
        $userRolesPath = Join-Path $outputDir "AzureUserRoles.csv"
        $resourceGraphPath = Join-Path $outputDir "AzureResourceGraph.csv"
        
        # Create output directory if it doesn't exist
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
            Write-Message "Created output directory: $outputDir"
        }

        # Get all resources and export to service map
        Write-Message "Retrieving Azure resources..."
        $resources = az resource list --query "[].{name:name, type:type, resourceGroup:resourceGroup, location:location}" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get resources: $resources"
        }

        # Define Azure Resource Graph query for services and network dependencies
        $resourceQuery = @"
Resources
| where type in (
    'microsoft.compute/virtualmachines',
    'microsoft.web/sites',
    'microsoft.logic/workflows',
    'microsoft.network/virtualnetworks',
    'microsoft.network/privateendpoints',
    'microsoft.network/publicipaddresses',
    'microsoft.network/networksecuritygroups'
)
| project name, type, resourceGroup, location, properties
"@

        # Check if Azure Resource Graph is enabled
        $resourceGraphEnabled = $false
        try {
            Write-Message "Checking if Azure Resource Graph is enabled..."
            $registrationState = (Get-AzResourceProvider -ProviderNamespace Microsoft.ResourceGraph).RegistrationState
            if ($registrationState -eq "Registered") {
                $resourceGraphEnabled = $true
            }
            Write-Message "Azure Resource Graph enabled: $resourceGraphEnabled"
        } catch {
            Write-Message "Failed to check Azure Resource Graph status: $_" -type "WARNING"
        }

        if ($resourceGraphEnabled) {
            try {
                Write-Message "Executing Azure Resource Graph query..."
                $additionalResources = Search-AzGraph -Query $resourceQuery -ErrorAction Stop
                Write-Message "Azure Resource Graph query executed successfully"
                
                # Export Resource Graph results to separate CSV
                $additionalResources | Export-Csv -Path $resourceGraphPath -NoTypeInformation
                Write-Message "Resource Graph data exported to: $resourceGraphPath"

                # Combine resources for service map
                $allResources = $resources | ConvertFrom-Json
                $allResources += $additionalResources
                $allResources | Export-Csv -Path $serviceMapPath -NoTypeInformation
                Write-Message "Service map exported to: $serviceMapPath"
            } catch {
                Write-Message "Failed to query Azure Resource Graph: $_" -type "ERROR"
                throw
            }
        } else {
            # Export resources from az resource list to service map
            $resources | ConvertFrom-Json | Export-Csv -Path $serviceMapPath -NoTypeInformation
            Write-Message "Service map exported to: $serviceMapPath"
        }

        # Get role assignments and export to user roles
        Write-Message "Retrieving role assignments..."
        $roles = az role assignment list --all --query "[].{principalName:principalName, roleDefinitionName:roleDefinitionName, scope:scope}" 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get role assignments: $roles"
        }
        $roles | ConvertFrom-Json | Export-Csv -Path $userRolesPath -NoTypeInformation
        Write-Message "User roles exported to: $userRolesPath"

        Write-Message "`nCSV generation completed successfully"
    }
    catch {
        Write-Message "Failed to generate CSVs: $_" -type "ERROR"
        throw
    }
}
catch {
    Write-Message "Failed to generate CSVs: $_" -type "ERROR"
    exit 1
}