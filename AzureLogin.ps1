param (
    [switch]$CheckLoginOnly
)

# This script handles the authentication process with Azure. It ensures that the user is logged in and has the necessary permissions to access Azure resources.

# Ensure PSGallery repository is registered
if (-not (Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Default
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

function Test-AzureLogin {
    $loginSuccess = $true
    Write-Host "Checking Azure CLI login status..."
    try {
        $account = az account show 2>&1 | ConvertFrom-Json -ErrorAction Stop
        if ($account) {
            Write-Host "Already logged in as: $($account.user.name)" -ForegroundColor Green
        } else {
            $loginSuccess = $false
            throw "Not logged in to Azure CLI."
        }
    } catch {
        Write-Host "Not currently logged in to Azure CLI." -ForegroundColor Yellow
        try {
            Write-Host "Attempting to log in to Azure CLI..."
            $loginResult = az login 2>&1
            if ($LASTEXITCODE -ne 0) {
                $loginSuccess = $false
                throw "Azure CLI login failed with exit code: $LASTEXITCODE. Error: $loginResult"
            }

            # Verify login was successful
            $account = az account show 2>&1 | ConvertFrom-Json -ErrorAction Stop
            if (-not $account) {
                $loginSuccess = $false
                throw "Failed to verify Azure CLI login status after login attempt."
            }

            Write-Host "Successfully logged in to Azure CLI as: $($account.user.name)" -ForegroundColor Green
        } catch {
            $loginSuccess = $false
            throw "Failed to log in to Azure CLI: $_"
        }
    }

    Write-Host "Checking Azure PowerShell login status..."
    try {
        $account = Get-AzContext
        if (-not $account) {
            Write-Host "Not logged in to Azure PowerShell. Attempting to connect..." -ForegroundColor Yellow
            $account = Connect-AzAccount
            if (-not $account) {
                $loginSuccess = $false
                throw "Failed to connect to Azure PowerShell"
            }
            Write-Host "Successfully connected to Azure PowerShell as: $($account.Account)" -ForegroundColor Green
        } else {
            Write-Host "Azure PowerShell login status: Logged in as $($account.Account)" -ForegroundColor Green
        }
    } catch {
        $loginSuccess = $false
        throw "Azure PowerShell login required: $_"
    }
    
    return $loginSuccess
}

function Test-AllAzureAccounts {
    Write-Host "`nChecking all Azure login statuses..." -ForegroundColor Cyan
    Write-Host "----------------------------------------"
    
    # Check Azure PowerShell
    Write-Host "`nAzure PowerShell Status:" -ForegroundColor Yellow
    try {
        $azAccount = Get-AzContext
        if ($azAccount) {
            Write-Host "✓ Logged in as: $($azAccount.Account)" -ForegroundColor Green
        } else {
            Write-Host "✗ Not logged in" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Error checking Azure PowerShell status: $_" -ForegroundColor Red
    }
    
    # Check Azure CLI
    Write-Host "`nAzure CLI Status:" -ForegroundColor Yellow
    try {
        $cliOutput = az account show 2>&1
        if ($LASTEXITCODE -eq 0) {
            $cliAccount = $cliOutput | ConvertFrom-Json -ErrorAction Stop
            Write-Host "✓ Logged in as: $($cliAccount.user.name)" -ForegroundColor Green
        } else {
            Write-Host "✗ Not logged in" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Error checking Azure CLI status" -ForegroundColor Red
    }
    
    Write-Host "`nPress any key to continue..."
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Show-AzureLoginMenu {
    param (
        [int]$recursionCount = 0
    )

    # Prevent stack overflow with recursion limit
    if ($recursionCount -gt 100) {
        Write-Error "Maximum menu recursion depth reached. Exiting..."
        exit
    }

    try {
        Write-Host "Azure Login Menu"
        Write-Host ""

        $menuItems = @(
            "Check All Azure Accounts",
            "Azure PowerShell - Login",
            "Azure PowerShell - Logout",
            "Azure PowerShell - Check Logged User",
            "Azure CLI - Login",
            "Azure CLI - Logout",
            "Azure CLI - Check Logged User",
            "Exit"
        )

        $choice = Show-Menu -MenuItems $menuItems

        switch ($choice) {
            "Check All Azure Accounts" {
                Test-AllAzureAccounts
                Show-AzureLoginMenu -recursionCount ($recursionCount + 1)
            }
            "Azure PowerShell - Login" {
                try {
                    $success = Connect-AzAccount
                    if (-not $success) {
                        throw "Failed to connect to Azure PowerShell"
                    }
                    Write-Host "Successfully connected to Azure PowerShell as: $($success.Account)" -ForegroundColor Green
                    Show-AzureLoginMenu -recursionCount ($recursionCount + 1)
                }
                catch {
                    Write-Error "Error in Azure PowerShell login: $_"
                    Show-AzureLoginMenu -recursionCount ($recursionCount + 1)
                }
            }
            "Azure PowerShell - Logout" {
                try {
                    Disconnect-AzAccount -Confirm:$false
                    Write-Host "Successfully logged out of Azure PowerShell"
                    Show-AzureLoginMenu -recursionCount ($recursionCount + 1)
                }
                catch {
                    Write-Error "Error in Azure PowerShell logout: $_"
                    exit 1
                }
            }
            "Azure PowerShell - Check Logged User" {
                try {
                    $account = Get-AzContext
                    if ($account) {
                        Write-Host "Logged in as: $($account.Account)"
                    } else {
                        Write-Host "Not logged in to Azure PowerShell"
                    }
                    Show-AzureLoginMenu -recursionCount ($recursionCount + 1)
                }
                catch {
                    Write-Error "Error in checking Azure PowerShell logged user: $_"
                    exit 1
                }
            }
            "Azure CLI - Login" {
                try {
                    $loginResult = az login 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        throw "Azure CLI login failed with exit code: $LASTEXITCODE. Error: $loginResult"
                    }
                    Write-Host "Successfully logged in to Azure CLI"
                    Show-AzureLoginMenu -recursionCount ($recursionCount + 1)
                }
                catch {
                    Write-Error "Error in Azure CLI login: $_"
                    exit 1
                }
            }
            "Azure CLI - Logout" {
                try {
                    az logout
                    Write-Host "Successfully logged out of Azure CLI"
                    Show-AzureLoginMenu -recursionCount ($recursionCount + 1)
                }
                catch {
                    Write-Error "Error in Azure CLI logout: $_"
                    exit 1
                }
            }
            "Azure CLI - Check Logged User" {
                try {
                    $cliOutput = az account show 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "Not logged in to Azure CLI"
                    } else {
                        try {
                            $account = $cliOutput | ConvertFrom-Json -ErrorAction Stop
                            Write-Host "Logged in as: $($account.user.name)"
                        } catch {
                            Write-Host "Unable to parse Azure CLI account info"
                        }
                    }
                    Show-AzureLoginMenu -recursionCount ($recursionCount + 1)
                }
                catch {
                    Write-Host "Not logged in to Azure CLI"
                    Show-AzureLoginMenu -recursionCount ($recursionCount + 1)
                }
            }
            "Exit" {
                Write-Host "Exiting..."
                exit
            }
            default {
                Write-Host "Invalid choice. Please try again."
                Start-Sleep -Seconds 2
                Show-AzureLoginMenu -recursionCount ($recursionCount + 1)
            }
        }
    }
    catch {
        Write-Error "An unexpected error occurred: $_"
        exit 1
    }
}

# Modified script ending - only run menu if not CheckLoginOnly
if ($CheckLoginOnly) {
    try {
        $loginSuccess = Test-AzureLogin
        if (-not $loginSuccess) {
            throw "Failed to authenticate with Azure"
        }
    } catch {
        Write-Error $_
        exit 1
    }
} else {
    # Start the Azure login menu directly
    Show-AzureLoginMenu
}