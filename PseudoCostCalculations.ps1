# PseudoCostCalculations.ps1

function Get-EstimatedCost {
    param (
        [string]$resourceType,
        [int]$operationCount = 1
    )
    
    # Define cost mapping for different resource types
    $costMap = @{
        'networksecuritygroups' = 0.002
        'virtualnetworks' = 0.003
        'virtualmachines' = 0.005
        'roleassignments' = 0.001
        'default' = 0.001
    }

    # Get base cost for the resource type
    $baseCost = $costMap[$resourceType.ToLower()] ?? $costMap['default']
    return [math]::Round($baseCost * $operationCount, 3)
}

function Confirm-Costs {
    param (
        [string]$operation,
        [string]$resourceType,
        [int]$operationCount = 1,
        [string]$confirmationMode
    )
    
    $estimatedCost = Get-EstimatedCost -resourceType $resourceType -operationCount $operationCount
    
    switch ($confirmationMode) {
        "yes" { return $true }
        "no" { return $false }
        "ask" {
            Write-Host "The operation '$operation' may incur an estimated cost of `$$estimatedCost USD."
            $confirmation = Read-Host "Do you wish to continue? (yes/no)"
            return $confirmation.ToLower() -eq "yes"
        }
    }
}
