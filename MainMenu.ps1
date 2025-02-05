<#
.SYNOPSIS
Azure Service Map Application menu interface.

.DESCRIPTION
Provides an interactive menu interface for the Azure Service Map Application.
The script handles various Azure-related operations including dependency checking,
authentication, CSV generation, and resource processing.

.NOTES
Version: 1.0
Author: David
Requires: PSMenu module
#>

# Ensure PSGallery repository is registered
if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Default
}

# Ensure PSMenu is installed
if (-not (Get-Module -ListAvailable -Name PSMenu)) {
    Install-Module -Name PSMenu -Scope CurrentUser -Force
}

try {
    Import-Module PSMenu -ErrorAction Stop
} catch {
    Write-Error "Failed to import PSMenu module: $_"
    exit
}

if (-not (Get-Command -Name Show-Menu -Module PSMenu -ErrorAction SilentlyContinue)) {
    Write-Error "Show-Menu function not found in PSMenu module."
    exit
}

# Initialize global variables at the start of each session
$global:LastAction = "First run"
$global:LastOutcome = "N/A"

function Show-MainMenu {
    <#
    .SYNOPSIS
    Displays the main menu of the Azure Service Map Application.

    .DESCRIPTION
    Presents an interactive menu with options for various Azure operations.
    Tracks and displays the last action and its outcome.
    Implements recursion protection to prevent stack overflow.

    .PARAMETER recursionCount
    Tracks the number of times the menu has been recursively called.
    Used to prevent stack overflow.

    .EXAMPLE
    Show-MainMenu
    Shows the main menu at the root level.

    .EXAMPLE
    Show-MainMenu -recursionCount 1
    Shows the main menu with recursion tracking.
    #>
    param (
        [int]$recursionCount = 0
    )

    # Prevent stack overflow with recursion limit
    if ($recursionCount -gt 100) {
        Write-Error "Maximum menu recursion depth reached. Exiting..."
        exit
    }

    try {
        # Clear-Host  # Removed to prevent clearing the screen
        Write-Host "Azure Service Map Application"
        Write-Host "Last action: $global:LastAction Outcome: $global:LastOutcome"
        Write-Host ""

        $menuItems = @(
            "Check Dependencies",
            "Authenticate with Azure",
            "Generate Basic CSVs (Service Map and User Roles)",
            "Process Resources (Generate Detailed JSON Files)",
            "Process Skipped Resources",  # New menu option
            "Exit"
        )

        $choice = Show-Menu -MenuItems $menuItems

        switch ($choice) {
            "Check Dependencies" { 
                try {
                    & .\CheckDependencies.ps1
                    $global:LastAction = "Check Dependencies"
                    $global:LastOutcome = "Success"
                    Show-MainMenu -recursionCount ($recursionCount + 1)
                }
                catch {
                    Write-Error "Error in Check Dependencies: $_"
                    exit 1
                }
            }
            "Authenticate with Azure" { 
                try {
                    & .\AzureLogin.ps1
                    $global:LastAction = "Authenticate with Azure"
                    $global:LastOutcome = "Success"
                    Show-MainMenu -recursionCount ($recursionCount + 1)
                }
                catch {
                    Write-Error "Error in Authenticate with Azure: $_"
                    exit 1
                }
            }
            "Generate Basic CSVs (Service Map and User Roles)" { 
                try {
                    & .\GenerateCSVs.ps1
                    $global:LastAction = "Generate CSVs"
                    $global:LastOutcome = "Success"
                    Show-MainMenu -recursionCount ($recursionCount + 1)
                }
                catch {
                    Write-Error "Error in Generate CSVs: $_"
                    exit 1
                }
            }
            "Process Resources (Generate Detailed JSON Files)" { 
                try {
                    & .\ProcessResources.ps1
                    if ($LASTEXITCODE -eq 2) {
                        $global:LastAction = "Process Resources"
                        $global:LastOutcome = "Cancelled by user"
                    } elseif ($LASTEXITCODE -eq 0) {
                        $global:LastAction = "Process Resources"
                        $global:LastOutcome = "Success"
                    } else {
                        $global:LastAction = "Process Resources"
                        $global:LastOutcome = "Failed"
                    }
                    Show-MainMenu -recursionCount ($recursionCount + 1)
                }
                catch {
                    $global:LastAction = "Process Resources"
                    $global:LastOutcome = "Error: $($_.Exception.Message)"
                    Write-Error "Error in Process Resources: $_"
                    Show-MainMenu -recursionCount ($recursionCount + 1)
                }
            }
            "Process Skipped Resources" {  # New case for processing skipped resources
                try {
                    & .\ProcessSkippedResources.ps1
                    if ($LASTEXITCODE -eq 2) {
                        $global:LastAction = "Process Skipped Resources"
                        $global:LastOutcome = "Cancelled by user"
                    } elseif ($LASTEXITCODE -eq 0) {
                        $global:LastAction = "Process Skipped Resources"
                        $global:LastOutcome = "Success"
                    } else {
                        $global:LastAction = "Process Skipped Resources"
                        $global:LastOutcome = "Failed"
                    }
                    Show-MainMenu -recursionCount ($recursionCount + 1)
                }
                catch {
                    $global:LastAction = "Process Skipped Resources"
                    $global:LastOutcome = "Error: $($_.Exception.Message)"
                    Write-Error "Error in Process Skipped Resources: $_"
                    Show-MainMenu -recursionCount ($recursionCount + 1)
                }
            }
            "Exit" { 
                Write-Host "Exiting..."
                exit 
            }
            default { 
                Write-Host "Invalid choice. Please try again."
                Start-Sleep -Seconds 2
                Show-MainMenu -recursionCount ($recursionCount + 1)
            }
        }
    }
    catch {
        Write-Error "An unexpected error occurred: $_"
        $global:LastAction = "Error"
        $global:LastOutcome = $_.Exception.Message
        exit 1
    }
}

# Start the menu
Show-MainMenu
