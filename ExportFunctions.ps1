function Export-JsonToFile {
    param(
        [Parameter(Mandatory = $true)]
        $Data,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$Description = "data",

        [Parameter(Mandatory = $false)]
        [int]$Depth = 100
    )
    
    try {
        $Data | ConvertTo-Json -Depth $Depth | Set-Content -Path $FilePath -Force
        Write-Host "Successfully exported $Description to: $FilePath"
    }
    catch {
        Write-Warning "Failed to export $Description to $FilePath. Error: $_"
        throw
    }
}
