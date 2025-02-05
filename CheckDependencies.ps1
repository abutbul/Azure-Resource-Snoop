# This script checks for any dependencies required by the application. It ensures that all necessary modules and tools are installed before running the main scripts.
function Install-AzureCLI {
    if (Get-Command az -ErrorAction SilentlyContinue) {
        Write-Host "Azure CLI is already installed."
        return $true
    }

    Write-Host "Installing Azure CLI using winget..."
    try {
        # Check if winget is available
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw "Winget is not installed. Please install App Installer from the Microsoft Store."
        }

        $process = Start-Process winget -ArgumentList "install --id Microsoft.AzureCLI -e --source winget --accept-source-agreements --accept-package-agreements" -Wait -PassThru -NoNewWindow
        if ($process.ExitCode -ne 0) {
            throw "Winget installation failed with exit code: $($process.ExitCode)"
        }

        # Refresh environment path
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        # Verify installation
        if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
            throw "Azure CLI installation completed but 'az' command is not available. Try restarting your terminal."
        }

        Write-Host "Azure CLI installed successfully."
        return $true
    }
    catch {
        Write-Error "Failed to install Azure CLI: $_"
        return $false
    }
}

function Install-AzPowerShell {
    if (Get-Module -ListAvailable -Name Az) {
        Write-Host "Azure PowerShell is already installed."
        return $true
    }

    Write-Host "Installing Azure PowerShell..."
    try {
        Install-Module -Name Az -AllowClobber -Force -Scope CurrentUser
        if (-not (Get-Module -ListAvailable -Name Az)) {
            throw "Azure PowerShell installation completed but 'Az' module is not available"
        }

        Write-Host "Azure PowerShell installed successfully."
        return $true
    }
    catch {
        Write-Error "Failed to install Azure PowerShell: $_"
        return $false
    }
}

function Test-Dependencies {
    Write-Host "Checking Azure CLI..."
    if (Get-Command az -ErrorAction SilentlyContinue) {
        Write-Host "Azure CLI is installed."
    } else {
        Write-Host "Azure CLI is not installed."
    }

    Write-Host "Checking Azure PowerShell..."
    if (Get-Module -ListAvailable -Name Az) {
        Write-Host "Azure PowerShell is installed."
    } else {
        Write-Host "Azure PowerShell is not installed."
    }
}

function Uninstall-AzureCLI {
    Write-Host "Uninstalling Azure CLI..."
    try {
        $process = Start-Process winget -ArgumentList "uninstall --id Microsoft.AzureCLI -e --source winget" -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "winget uninstallation failed with exit code: $($process.ExitCode)"
        }
        Write-Host "Azure CLI uninstalled successfully."
    }
    catch {
        Write-Error "Failed to uninstall Azure CLI: $_"
    }
}

function Uninstall-AzPowerShell {
    Write-Host "Uninstalling Azure PowerShell..."
    try {
        Uninstall-Module -Name Az -AllVersions -Force
        Write-Host "Azure PowerShell uninstalled successfully."
    }
    catch {
        Write-Error "Failed to uninstall Azure PowerShell: $_"
    }
}

function Show-DependencyMenu {
    param (
        [int]$recursionCount = 0
    )

    if ($recursionCount -gt 100) {
        Write-Error "Maximum menu recursion depth reached. Exiting..."
        exit
    }

    try {
        Write-Host "Azure Dependencies Management"
        Write-Host ""

        $menuItems = @(
            "Check Dependencies",
            "Install Dependencies",
            "Uninstall Dependencies",
            "Exit"
        )

        $choice = Show-Menu -MenuItems $menuItems

        switch ($choice) {
            "Check Dependencies" { 
                Test-Dependencies
                Show-DependencyMenu -recursionCount ($recursionCount + 1)
            }
            "Install Dependencies" {
                if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
                    if (-not (Install-AzureCLI)) {
                        throw "Failed to install Azure CLI."
                    }
                } else {
                    Write-Host "Azure CLI is already installed."
                }

                if (-not (Get-Module -ListAvailable -Name Az)) {
                    if (-not (Install-AzPowerShell)) {
                        throw "Failed to install Azure PowerShell."
                    }
                } else {
                    Write-Host "Azure PowerShell is already installed."
                }
                Show-DependencyMenu -recursionCount ($recursionCount + 1)
            }
            "Uninstall Dependencies" {
                if (Get-Command az -ErrorAction SilentlyContinue) {
                    Uninstall-AzureCLI
                } else {
                    Write-Host "Azure CLI is not installed."
                }

                if (Get-Module -ListAvailable -Name Az) {
                    Uninstall-AzPowerShell
                } else {
                    Write-Host "Azure PowerShell is not installed."
                }
                Show-DependencyMenu -recursionCount ($recursionCount + 1)
            }
            "Exit" { 
                return 
            }
            default { 
                Write-Host "Invalid choice. Please try again."
                Start-Sleep -Seconds 2
                Show-DependencyMenu -recursionCount ($recursionCount + 1)
            }
        }
    }
    catch {
        Write-Error "An unexpected error occurred: $_"
        exit 1
    }
}

Show-DependencyMenu