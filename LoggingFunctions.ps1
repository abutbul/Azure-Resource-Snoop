# Define log file path

# Create logs directory if it doesn't exist
$logsDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir | Out-Null
}

# Function to log messages
function Write-Message {
    param (
        [Parameter(Mandatory=$true)]
        [string]$message,
        [string]$type = "INFO",
        [string]$logFileName
    )
    # Automatically generate log filename if not provided
    if (-not $logFileName) {
        # Get the calling script's path instead of the current function's path
        $callingScriptPath = if ($MyInvocation.ScriptName) { 
            $MyInvocation.ScriptName 
        } else { 
            "default"
        }
        $logFileName = [System.IO.Path]::GetFileNameWithoutExtension($callingScriptPath) + ".log"
    }
    # Ensure filename has .log extension
    if (-not $logFileName.EndsWith('.log')) {
        $logFileName = "$logFileName.log"
    }
    $logFile = Join-Path $PSScriptRoot "logs" $logFileName
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp [$type] $message"
    Add-Content -Path $logFile -Value $logEntry
    if ($type -eq "ERROR" -or $type -eq "WARNING") {
        Write-Host $logEntry -ForegroundColor Red
    } else {
        Write-Host $logEntry
    }
}
