# software-deploy-lab

A lightweight CI/CD silent installation pipeline for Windows 11 — built as a local testbed for enterprise software deployment workflows.

---

## What This Does

- Reads a **software catalog** (`catalog.json`) listing packages, download URLs, and SHA-256 hashes
- Collects **user & machine context** (username, OS, machine name, RAM, disk)
- Downloads the installer directly from the vendor
- Verifies **SHA-256 integrity** before running anything
- Executes a **silent install** with no UI
- Validates the install succeeded by checking for the expected binary
- **GitHub Actions CI** validates the catalog and lints scripts on every push

---

## Repo Structure

```
software-deploy-lab/
├── catalog.json                      ← Software manifest
├── scripts/
│   ├── deploy.ps1                    ← Main deployment agent
│   ├── get-user-context.ps1          ← User & machine identity
│   ├── get-hashes.ps1                ← Helper: compute real SHA-256 hashes
│   └── utils/
│       └── Write-Log.ps1             ← Logger utility
└── .github/
    └── workflows/
        └── ci.yml                    ← GitHub Actions pipeline
```

---

## Quick Start

### 1. Clone the repo

```powershell
git clone https://github.com/YOUR_USERNAME/software-deploy-lab.git
cd software-deploy-lab
```

### 2. Get real SHA-256 hashes and update catalog.json

The catalog ships with placeholder hashes. Run this once to get real values:

```powershell
# Open PowerShell as Administrator
.\scripts\get-hashes.ps1
```

Copy each printed hash into `catalog.json` under the matching package's `"sha256"` field.

### 3. List available packages

```powershell
.\scripts\deploy.ps1 -List
```

Output:
```
  Available Packages in Catalog
  ─────────────────────────────────────────────
  ► 7zip-2409  —  7-Zip 24.09
     Free and open-source file archiver
  ► vlc-390  —  VLC Media Player 3.9.0
     Free and open-source multimedia player
```

### 4. Dry run (no install — just validates everything)

```powershell
# Open PowerShell as Administrator
.\scripts\deploy.ps1 -SoftwareID "7zip-2409" -DryRun
```

### 5. Deploy silently

```powershell
# Open PowerShell as Administrator
.\scripts\deploy.ps1 -SoftwareID "7zip-2409"
.\scripts\deploy.ps1 -SoftwareID "vlc-390"
```

### 6. Force reinstall

```powershell
.\scripts\deploy.ps1 -SoftwareID "7zip-2409" -Force
```

---

## What the Agent Does (Step by Step)

| Step | Action |
|------|--------|
| 1 | Load and parse `catalog.json` |
| 2 | Collect user identity + machine info (username, OS, RAM, disk) |
| 3 | Verify script is running as Administrator |
| 4 | Check at least 2 GB free disk space |
| 5 | Check if software is already installed (skip if so) |
| 6 | Download installer via BITS or Invoke-WebRequest |
| 7 | Verify SHA-256 hash matches catalog entry |
| 8 | Execute silent install with no UI |
| — | Validate expected binary exists at install path |
| — | Clean up staging files |
| — | Write full summary to log file |

---

## Logs

All deployment logs are saved to:

```
%LOCALAPPDATA%\SoftwareDeploy\Logs\
```

Example log file: `7zip-2409-20241101-143022.log`

---

## CI Pipeline (GitHub Actions)

On every push or pull request to `main`, the pipeline runs 3 jobs:

| Job | What it checks |
|-----|----------------|
| `validate-catalog` | All required fields present, HTTPS URLs, non-empty hashes |
| `lint-scripts` | PSScriptAnalyzer — no errors in PowerShell files |
| `verify-urls` | HTTP HEAD request confirms each download URL is reachable |

---

## Silent Install Arguments Reference

| Software | Silent Flag | Notes |
|----------|-------------|-------|
| 7-Zip | `/S` | Standard NSIS silent flag |
| VLC | `/L=1033 /S` | Language code + NSIS silent |
| ANSYS | `-silent -install_dir` | Custom ANSYS flag |
| SolidWorks | `/install /passive /norestart` | MSI-based |
| CATIA V5 | `/passive /CmdFile` | Dassault answer file |
| Teamcenter | `-i silent -f` | InstallAnywhere XML |

---

## Adding a New Package

1. Add an entry to `catalog.json` following the existing schema
2. Run `.\scripts\get-hashes.ps1` to get the real SHA-256 hash
3. Update the `sha256` field in `catalog.json`
4. Push — CI will validate the new entry automatically

---

## Requirements

- Windows 11
- PowerShell 5.1 or later
- Run as **Administrator** for silent installs
- Internet access to download installers

---

## Next Steps Toward Enterprise

When ready to scale this to an enterprise pipeline:

- Replace `download_url` with **Azure Artifacts feed** URLs
- Add **AD group entitlement checks** (see `get-user-context.ps1` enterprise version)
- Add **Azure Key Vault** for license server strings
- Add **MECM / Intune** as the CD delivery mechanism
- Add **ServiceNow CMDB** integration in `Send-DeploymentEvent.ps1`
- Add **code signing** for all `.ps1` files with org certificate
