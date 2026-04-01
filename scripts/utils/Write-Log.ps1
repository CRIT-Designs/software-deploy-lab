# =============================================================================
# Write-Log.ps1
# Simple logger that writes to both console and a log file.
# =============================================================================

function Write-Log {
    param(
        [string] $Message,
        [string] $Level = "INFO",   # INFO | WARN | ERROR | SUCCESS
        [string] $LogFile
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line      = "[$timestamp] [$Level] $Message"

    # Console color by level
    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
        default   { "White" }
    }

    Write-Host $line -ForegroundColor $color

    # Write to file if path provided
    if ($LogFile) {
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
    }
}
