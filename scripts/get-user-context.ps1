# =============================================================================
# get-user-context.ps1
# Resolves the current Windows user's identity and machine information.
# Works on a standard local Windows 11 machine (no Active Directory needed).
# =============================================================================

function Get-UserContext {

    # ── 1. Current logged-in user ─────────────────────────────────────────
    $currentUser   = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $fullUserName  = $currentUser.Name                    # e.g. LAPTOP\John
    $samAcct       = $fullUserName.Split("\")[-1]         # e.g. John
    $isAdmin       = ([Security.Principal.WindowsPrincipal]$currentUser).IsInRole(
                         [Security.Principal.WindowsBuiltInRole]::Administrator)

    # ── 2. Machine information ────────────────────────────────────────────
    $os        = Get-CimInstance Win32_OperatingSystem
    $cpu       = Get-CimInstance Win32_Processor | Select-Object -First 1
    $disk      = Get-PSDrive C
    $ram       = [math]::Round(($os.TotalVisibleMemorySize / 1MB), 1)
    $freeGB    = [math]::Round($disk.Free / 1GB, 2)
    $usedGB    = [math]::Round($disk.Used / 1GB, 2)

    # ── 3. Network info ───────────────────────────────────────────────────
    $ip = (Get-NetIPAddress -AddressFamily IPv4 |
           Where-Object { $_.IPAddress -notlike "169.*" -and
                          $_.IPAddress -ne "127.0.0.1" } |
           Select-Object -First 1).IPAddress

    # ── 4. Return context object ──────────────────────────────────────────
    return [PSCustomObject]@{
        # User info
        UserID        = $samAcct
        FullUser      = $fullUserName
        IsAdmin       = $isAdmin

        # Machine info
        MachineName   = $env:COMPUTERNAME
        MachineIP     = $ip
        OSName        = $os.Caption
        OSBuild       = $os.BuildNumber
        CPU           = $cpu.Name
        RAM_GB        = $ram
        DiskFreeGB    = $freeGB
        DiskUsedGB    = $usedGB

        # Audit
        Timestamp     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
    }
}
