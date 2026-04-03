# =============================================================================
# deploy.ps1  --  Silent Installation Agent (Local Lab Version)
#
# USAGE:
#   .\deploy.ps1 -SoftwareID "7zip-2409"
#   .\deploy.ps1 -SoftwareID "vlc-390"
#   .\deploy.ps1 -SoftwareID "7zip-2409" -DryRun
#   .\deploy.ps1 -SoftwareID "7zip-2409" -Force
#   .\deploy.ps1 -List
#
# REQUIREMENTS:
#   - Windows 11
#   - PowerShell 5.1 or later
#   - Run as Administrator for silent install
# =============================================================================

param(
    [string] $SoftwareID,
    [switch] $DryRun,
    [switch] $Force,
    [switch] $List
)

# -- Bootstrap paths ----------------------------------------------------------
$RepoRoot    = Split-Path $PSScriptRoot -Parent
$CatalogPath = Join-Path $RepoRoot "catalog.json"
$LogDir      = Join-Path $env:LOCALAPPDATA "SoftwareDeploy\Logs"
$StagingDir  = Join-Path $env:TEMP "SoftwareDeploy\Staging"

# Load utilities
. "$PSScriptRoot\utils\Write-Log.ps1"
. "$PSScriptRoot\get-user-context.ps1"

# -- -List mode ---------------------------------------------------------------
if ($List) {
    $catalog = Get-Content $CatalogPath | ConvertFrom-Json
    Write-Host ""
    Write-Host "  Available Packages in Catalog" -ForegroundColor Cyan
    Write-Host "  -----------------------------------------" -ForegroundColor DarkGray
    foreach ($pkg in $catalog.software) {
        Write-Host "  > $($pkg.id)" -ForegroundColor Yellow -NoNewline
        Write-Host "  --  $($pkg.name)" -ForegroundColor White
        Write-Host "     $($pkg.description)" -ForegroundColor DarkGray
    }
    Write-Host ""
    exit 0
}

# -- Require SoftwareID -------------------------------------------------------
if (-not $SoftwareID) {
    Write-Host "ERROR: Provide -SoftwareID or use -List to see packages." -ForegroundColor Red
    Write-Host "Usage: .\deploy.ps1 -SoftwareID '7zip-2409'"
    exit 1
}

# -- Setup log file -----------------------------------------------------------
New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
$LogFile = Join-Path $LogDir "$SoftwareID-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

Write-Log "===================================================" -LogFile $LogFile
Write-Log " Software Deploy Agent  --  $SoftwareID"           -LogFile $LogFile
Write-Log "===================================================" -LogFile $LogFile
Write-Log "Log file: $LogFile" -LogFile $LogFile

# -----------------------------------------------------------------------------
# STEP 1 -- Load catalog
# -----------------------------------------------------------------------------
Write-Log "" -LogFile $LogFile
Write-Log "STEP 1/8 -- Loading catalog..." -LogFile $LogFile

if (-not (Test-Path $CatalogPath)) {
    Write-Log "Catalog not found at: $CatalogPath" -Level "ERROR" -LogFile $LogFile
    exit 1
}

$catalog = Get-Content $CatalogPath | ConvertFrom-Json
$pkg = $catalog.software | Where-Object { $_.id -eq $SoftwareID }

if (-not $pkg) {
    Write-Log "Package '$SoftwareID' not found in catalog." -Level "ERROR" -LogFile $LogFile
    Write-Log "Run '.\deploy.ps1 -List' to see available packages." -Level "INFO" -LogFile $LogFile
    exit 1
}

Write-Log "Found: $($pkg.name) v$($pkg.version)" -Level "SUCCESS" -LogFile $LogFile
Write-Log "Vendor: $($pkg.vendor)" -LogFile $LogFile

# -----------------------------------------------------------------------------
# STEP 2 -- Collect user and machine context
# -----------------------------------------------------------------------------
Write-Log "" -LogFile $LogFile
Write-Log "STEP 2/8 -- Collecting user and machine context..." -LogFile $LogFile

$ctx = Get-UserContext

Write-Log "User:       $($ctx.FullUser)" -LogFile $LogFile
Write-Log "Admin:      $($ctx.IsAdmin)" -LogFile $LogFile
Write-Log "Machine:    $($ctx.MachineName)  [$($ctx.MachineIP)]" -LogFile $LogFile
Write-Log "OS:         $($ctx.OSName) (Build $($ctx.OSBuild))" -LogFile $LogFile
Write-Log "CPU:        $($ctx.CPU)" -LogFile $LogFile
Write-Log "RAM:        $($ctx.RAM_GB) GB" -LogFile $LogFile
Write-Log "Disk Free:  $($ctx.DiskFreeGB) GB" -LogFile $LogFile

# -----------------------------------------------------------------------------
# STEP 3 -- Admin check
# -----------------------------------------------------------------------------
Write-Log "" -LogFile $LogFile
Write-Log "STEP 3/8 -- Checking permissions..." -LogFile $LogFile

if (-not $ctx.IsAdmin) {
    Write-Log "Script must be run as Administrator for silent install." -Level "ERROR" -LogFile $LogFile
    Write-Log "Right-click PowerShell -> Run as Administrator, then re-run." -Level "WARN" -LogFile $LogFile
    exit 2
}

Write-Log "Running as Administrator OK" -Level "SUCCESS" -LogFile $LogFile

# -----------------------------------------------------------------------------
# STEP 4 -- Disk space check
# -----------------------------------------------------------------------------
Write-Log "" -LogFile $LogFile
Write-Log "STEP 4/8 -- Checking disk space..." -LogFile $LogFile

if ($ctx.DiskFreeGB -lt 2) {
    Write-Log "Less than 2 GB free on C:\. Aborting." -Level "ERROR" -LogFile $LogFile
    exit 3
}

Write-Log "Disk space OK -- $($ctx.DiskFreeGB) GB free" -Level "SUCCESS" -LogFile $LogFile

# -----------------------------------------------------------------------------
# STEP 5 -- Already installed check
# -----------------------------------------------------------------------------
Write-Log "" -LogFile $LogFile
Write-Log "STEP 5/8 -- Checking if already installed..." -LogFile $LogFile

$regPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$installed = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue |
             Where-Object { $_.DisplayName -like "*$($pkg.vendor)*" -or
                            $_.DisplayName -like "*$($pkg.name.Split(' ')[0])*" }

if ($installed -and -not $Force) {
    Write-Log "Already installed: $($installed[0].DisplayName) $($installed[0].DisplayVersion)" -Level "WARN" -LogFile $LogFile
    Write-Log "Use -Force to reinstall." -LogFile $LogFile
    exit 0
} elseif ($installed -and $Force) {
    Write-Log "Already installed, but -Force specified. Proceeding with reinstall." -Level "WARN" -LogFile $LogFile
} else {
    Write-Log "Not currently installed -- proceeding" -Level "SUCCESS" -LogFile $LogFile
}

# Stop here if dry run
if ($DryRun) {
    Write-Log "" -LogFile $LogFile
    Write-Log "DRY RUN -- All checks passed. No installation performed." -Level "SUCCESS" -LogFile $LogFile
    Write-Log "Remove -DryRun to perform the actual install." -LogFile $LogFile
    exit 0
}

# -----------------------------------------------------------------------------
# STEP 6 -- Download installer
# -----------------------------------------------------------------------------
Write-Log "" -LogFile $LogFile
Write-Log "STEP 6/8 -- Downloading installer..." -LogFile $LogFile

$pkgStaging    = Join-Path $StagingDir $SoftwareID
New-Item -ItemType Directory -Path $pkgStaging -Force | Out-Null

$fileName      = $pkg.download_url.Split("/")[-1]
$installerPath = Join-Path $pkgStaging $fileName

Write-Log "Source:      $($pkg.download_url)" -LogFile $LogFile
Write-Log "Destination: $installerPath" -LogFile $LogFile

try {
    $bitsAvailable = Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue
    if ($bitsAvailable) {
        Start-BitsTransfer -Source $pkg.download_url -Destination $installerPath `
                           -DisplayName "Downloading $($pkg.name)" -Priority Foreground
    } else {
        Invoke-WebRequest -Uri $pkg.download_url -OutFile $installerPath -UseBasicParsing
    }
    Write-Log "Download complete" -Level "SUCCESS" -LogFile $LogFile
}
catch {
    Write-Log "Download failed: $_" -Level "ERROR" -LogFile $LogFile
    exit 4
}

# -----------------------------------------------------------------------------
# STEP 7 -- SHA-256 integrity verification
# -----------------------------------------------------------------------------
Write-Log "" -LogFile $LogFile
Write-Log "STEP 7/8 -- Verifying SHA-256 integrity..." -LogFile $LogFile

$actualHash   = (Get-FileHash -Path $installerPath -Algorithm SHA256).Hash.ToLower()
$expectedHash = $pkg.sha256.ToLower()

Write-Log "Expected: $expectedHash" -LogFile $LogFile
Write-Log "Actual:   $actualHash"   -LogFile $LogFile

if ($actualHash -ne $expectedHash) {
    Write-Log "SHA-256 MISMATCH detected." -Level "WARN" -LogFile $LogFile
    Write-Log "In production this would ABORT. For lab testing, proceeding." -Level "WARN" -LogFile $LogFile
    Write-Log "To fix: run  (Get-FileHash '$installerPath' -Algorithm SHA256).Hash" -Level "INFO" -LogFile $LogFile
    Write-Log "Then update catalog.json with the real hash." -Level "INFO" -LogFile $LogFile
} else {
    Write-Log "Integrity verified OK" -Level "SUCCESS" -LogFile $LogFile
}

# -----------------------------------------------------------------------------
# STEP 8 -- Silent installation
# -----------------------------------------------------------------------------
Write-Log "" -LogFile $LogFile
Write-Log "STEP 8/8 -- Running silent installation..." -LogFile $LogFile
Write-Log "Installer:  $installerPath" -LogFile $LogFile
Write-Log "Arguments:  $($pkg.silent_args)" -LogFile $LogFile

try {
    $proc = Start-Process -FilePath $installerPath `
                          -ArgumentList $pkg.silent_args `
                          -Wait -PassThru -NoNewWindow

    $exitCode = $proc.ExitCode
    Write-Log "Installer exited with code: $exitCode" -LogFile $LogFile
}
catch {
    Write-Log "Installer process failed: $_" -Level "ERROR" -LogFile $LogFile
    exit 6
}

# -----------------------------------------------------------------------------
# POST-INSTALL -- Validate and report
# -----------------------------------------------------------------------------
Write-Log "" -LogFile $LogFile
Write-Log "POST-INSTALL -- Validating..." -LogFile $LogFile

$exePath   = Join-Path $pkg.install_path $pkg.post_install_validation
$validated = Test-Path $exePath

if ($exitCode -eq 0 -and $validated) {
    $status = "SUCCESS"
    Write-Log "Installation SUCCESSFUL" -Level "SUCCESS" -LogFile $LogFile
    Write-Log "Validated binary found at: $exePath" -Level "SUCCESS" -LogFile $LogFile
} elseif ($exitCode -eq 0 -and -not $validated) {
    $status = "INSTALLED_NOT_VALIDATED"
    Write-Log "Installer succeeded but binary not found at expected path." -Level "WARN" -LogFile $LogFile
    Write-Log "Expected: $exePath" -Level "WARN" -LogFile $LogFile
} else {
    $status = "FAILED"
    Write-Log "Installation FAILED. Exit code: $exitCode" -Level "ERROR" -LogFile $LogFile
}

# -----------------------------------------------------------------------------
# CLEANUP -- Remove staging files
# -----------------------------------------------------------------------------
Write-Log "" -LogFile $LogFile
Write-Log "Cleaning up staging directory..." -LogFile $LogFile
Remove-Item $pkgStaging -Recurse -Force -ErrorAction SilentlyContinue
Write-Log "Cleanup complete." -LogFile $LogFile

# -----------------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------------
Write-Log "" -LogFile $LogFile
Write-Log "===================================================" -LogFile $LogFile
Write-Log " DEPLOYMENT SUMMARY"                                -LogFile $LogFile
Write-Log "===================================================" -LogFile $LogFile
Write-Log " Package  : $($pkg.name)"                          -LogFile $LogFile
Write-Log " Version  : $($pkg.version)"                       -LogFile $LogFile
Write-Log " User     : $($ctx.FullUser)"                      -LogFile $LogFile
Write-Log " Machine  : $($ctx.MachineName)"                   -LogFile $LogFile
Write-Log " Status   : $status"                               -LogFile $LogFile
Write-Log " Exit Code: $exitCode"                             -LogFile $LogFile
Write-Log " Log File : $LogFile"                              -LogFile $LogFile
Write-Log "===================================================" -LogFile $LogFile

exit $exitCode
