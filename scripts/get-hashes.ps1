# =============================================================================
# get-hashes.ps1
#
# Run this ONCE after cloning the repo to:
#   1. Download each installer to a temp folder
#   2. Compute real SHA-256 hashes
#   3. Print the exact values to paste into catalog.json
#
# Usage:
#   .\scripts\get-hashes.ps1
# =============================================================================

. "$PSScriptRoot\utils\Write-Log.ps1"

$RepoRoot    = Split-Path $PSScriptRoot -Parent
$CatalogPath = Join-Path $RepoRoot "catalog.json"
$TempDir     = Join-Path $env:TEMP "SoftwareDeploy\HashCheck"

New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

$catalog = Get-Content $CatalogPath | ConvertFrom-Json

Write-Host ""
Write-Host "  SHA-256 Hash Generator for catalog.json" -ForegroundColor Cyan
Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  This will download each installer and compute its hash."
Write-Host "  Paste the results into catalog.json sha256 fields."
Write-Host ""

foreach ($pkg in $catalog.software) {
    Write-Host "Processing: $($pkg.name)" -ForegroundColor Yellow

    $fileName = $pkg.download_url.Split("/")[-1]
    $outPath  = Join-Path $TempDir $fileName

    Write-Host "  Downloading from: $($pkg.download_url)" -ForegroundColor DarkGray

    try {
        Start-BitsTransfer -Source $pkg.download_url -Destination $outPath `
                           -DisplayName "Downloading $($pkg.name)" -Priority Foreground
    } catch {
        Invoke-WebRequest -Uri $pkg.download_url -OutFile $outPath -UseBasicParsing
    }

    $hash = (Get-FileHash $outPath -Algorithm SHA256).Hash.ToLower()

    Write-Host ""
    Write-Host "  Package ID : $($pkg.id)" -ForegroundColor White
    Write-Host "  SHA-256    : $hash" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Paste this into catalog.json:" -ForegroundColor DarkGray
    Write-Host "  `"sha256`": `"$hash`"" -ForegroundColor Cyan
    Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    # Clean up
    Remove-Item $outPath -Force -ErrorAction SilentlyContinue
}

Write-Host "Done. Update catalog.json with the hashes above." -ForegroundColor Green
