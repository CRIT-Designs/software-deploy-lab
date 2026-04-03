# =============================================================================
# Write-Log.ps1
# Writes timestamped messages to console and log file.
# =============================================================================

function Write-Log {
    param(
        [string] $Message,
        [string] $Level = "INFO",
        [string] $LogFile
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line      = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        default   { "White" }
    }

    Write-Host $line -ForegroundColor $color

    if ($LogFile) {
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
    }
}
