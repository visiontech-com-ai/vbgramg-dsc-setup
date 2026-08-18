# ============================================================================
# VBGRAMG DSC Setup - Vision Technologies and Robotics
# Installs Firefox 43.0.1 (32-bit) + Oracle JRE 8 (32-bit)
# Configures Java security and permanently disables Firefox auto-update
# ============================================================================

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- Enable ANSI escape codes in Windows PowerShell 5.1 / cmd.exe ---
$regKey = 'HKCU:\Console'
$vtp = (Get-ItemProperty -Path $regKey -Name 'VirtualTerminalLevel' -ErrorAction SilentlyContinue).VirtualTerminalLevel
if ($vtp -ne 1) {
    try { Set-ItemProperty -Path $regKey -Name 'VirtualTerminalLevel' -Value 1 -Type DWord -Force } catch {}
}
try {
    $k = Add-Type -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hHandle, uint dwMode);
'@ -Name 'WinAPI' -Namespace 'Console' -PassThru
    $h = $k::GetStdHandle(-11)
    $m = 0; $null = $k::GetConsoleMode($h, [ref]$m)
    $null = $k::SetConsoleMode($h, $m -bor 4)
} catch {}

# --- Force TLS 1.2 for HTTPS downloads ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Set console to UTF-8 for Unicode characters (spinners, checkmarks) ---
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "VBGRAMG DSC Setup - Vision Technologies and Robotics"

# --- ANSI Color Codes ---
$ESC        = [char]27
$RESET      = "$ESC[0m"
$BOLD       = "$ESC[1m"
$DIM        = "$ESC[2m"
$CYAN       = "$ESC[36m"
$GREEN      = "$ESC[32m"
$YELLOW     = "$ESC[33m"
$RED        = "$ESC[31m"
$MAGENTA    = "$ESC[35m"
$WHITE      = "$ESC[97m"
$BG_BLUE    = "$ESC[44m"
$BG_BLACK   = "$ESC[40m"

# --- Unicode symbols (as [char] so the source file stays pure ASCII) ---
$SYM_CHECK  = [char]0x2713  # checkmark
$SYM_CROSS  = [char]0x2717  # ballot X
$SYM_RAQUO  = [char]0x00BB  # right-pointing double angle
$SYM_SPIN   = @([char]0x280B,[char]0x2819,[char]0x2839,[char]0x2838,[char]0x283C,[char]0x2834,[char]0x2826,[char]0x2827,[char]0x2807,[char]0x280F)

# --- URLs ---
$firefoxUrl = "https://ftp.mozilla.org/pub/firefox/releases/43.0.1/win32/en-US/Firefox%20Setup%2043.0.1.exe"
# Oracle Java 8 (32-bit) is required because ONLY Oracle's JRE ships the
# browser applet plugin (npjp2.dll) that NREGA/VBGRAMG digital-signature
# applets need. Open-source builds (Zulu, Temurin, etc.) omit it.
# The 32-bit offline installer is resolved live from Oracle's public
# java.com download endpoint (no login required) in Get-OracleJreUrl.
$javaManualPage = "https://www.java.com/en/download/manual.jsp"
# Pinned Oracle Java 8 installer (the exact version the DSC applet needs, e.g.
# 8u231). Hosted on the deployer's own storage. Used when no installer is
# bundled next to setup.bat. Any 'dl=0' is forced to 'dl=1' for direct download.
$javaPinnedUrl = "https://www.dropbox.com/scl/fi/zdjmkskazpfm25sptmeoo/jre-8u231-windows-i586.exe?rlkey=socjfy3dsxw9n8zki7qyp0u85&dl=0"

# --- Paths ---
$firefoxInstaller = Join-Path $env:TEMP "FirefoxSetup-43.0.1.exe"
$javaInstaller    = Join-Path $env:TEMP "oracle-jre8-win-i586.exe"
$firefoxDir       = "C:\Program Files (x86)\Mozilla Firefox"
# Oracle installs to C:\Program Files (x86)\Java\jre1.8.0_XXX (version varies)
$javaRoot         = "C:\Program Files (x86)\Java"

# --- Results tracking ---
$results = @{}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Show-Banner {
    Clear-Host
    $banner = @"

$BOLD$CYAN
  +==================================================================+
  |                                                                    |
  |   __   __ ___  ____  ___  ___   _  _                               |
  |   \ \ / /|_ _|/ ___||_ _|/ _ \ | \| |                              |
  |    \ V /  | | \___ \ | || | | ||  \| |                              |
  |     \_/  |___||____/|___||_| |_||_|\_|                              |
  |                                                                    |
  |$WHITE   T E C H N O L O G I E S   &   R O B O T I C S$CYAN                |
  |                                                                    |
  +==================================================================+
  |$YELLOW  VBGRAMG / NREGA Digital Signature Setup Tool$CYAN                   |
  |$DIM  Firefox 43.0.1 + Oracle Java 8 (32-bit)$CYAN                        |
  +==================================================================+
$RESET
"@
    Write-Host $banner
}

function Show-Step {
    param(
        [int]$Number,
        [string]$Text,
        [string]$Status = "running"
    )
    switch ($Status) {
        "running" { Write-Host "  ${CYAN}[$Number]${RESET} ${WHITE}$Text${RESET}" -NoNewline; Write-Host "" }
        "done"    { Write-Host "  ${GREEN}[$SYM_CHECK]${RESET} ${WHITE}$Text${RESET} ${GREEN}Done${RESET}" }
        "skip"    { Write-Host "  ${YELLOW}[$SYM_RAQUO]${RESET} ${DIM}$Text${RESET} ${YELLOW}Skipped${RESET}" }
        "fail"    { Write-Host "  ${RED}[$SYM_CROSS]${RESET} ${WHITE}$Text${RESET} ${RED}Failed${RESET}" }
    }
}

function Show-Busy {
    param(
        [string]$Text,
        [System.Diagnostics.Process]$Process
    )
    $frames = $SYM_SPIN
    $i = 0
    while (-not $Process.HasExited) {
        $frame = $frames[$i % $frames.Count]
        Write-Host "`r      ${CYAN}$frame${RESET} ${DIM}$Text${RESET}   " -NoNewline
        Start-Sleep -Milliseconds 120
        $i++
    }
    Write-Host "`r      ${GREEN}$SYM_CHECK${RESET} ${DIM}$Text${RESET}   "
}

function Download-WithProgress {
    param(
        [string]$Url,
        [string]$OutFile,
        [string]$DisplayName
    )
    Write-Host "      ${DIM}Downloading $DisplayName...${RESET}"
    $progressBarWidth = 40
    try {
        $webRequest = [System.Net.HttpWebRequest]::Create($Url)
        $webRequest.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win32; x32) VisionTech-Setup/1.0"
        $response = $webRequest.GetResponse()
        $totalBytes = $response.ContentLength
        $responseStream = $response.GetResponseStream()
        $fileStream = [System.IO.File]::Create($OutFile)
        $buffer = New-Object byte[] 65536
        $bytesRead = 0
        $totalRead = 0
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        while (($bytesRead = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $bytesRead)
            $totalRead += $bytesRead
            if ($totalBytes -gt 0) {
                $pct = [math]::Round(($totalRead / $totalBytes) * 100)
                $filled = [math]::Round(($totalRead / $totalBytes) * $progressBarWidth)
                $empty = $progressBarWidth - $filled
                $barFull = [string][char]0x2588
                $barEmpty = [string][char]0x2591
                $bar = "$GREEN" + ($barFull * $filled) + "$DIM" + ($barEmpty * $empty) + "$RESET"
                $sizeMB = [math]::Round($totalRead / 1MB, 1)
                $totalMB = [math]::Round($totalBytes / 1MB, 1)
                $elapsed = $sw.Elapsed.TotalSeconds
                if ($elapsed -gt 0) {
                    $speed = [math]::Round(($totalRead / 1MB) / $elapsed, 1)
                } else {
                    $speed = 0
                }
                Write-Host "`r      $bar ${WHITE}${pct}%${RESET} ${DIM}(${sizeMB}/${totalMB} MB @ ${speed} MB/s)${RESET}   " -NoNewline
            }
        }
        Write-Host ""
        $fileStream.Close()
        $responseStream.Close()
        $response.Close()
        return $true
    }
    catch {
        Write-Host ""
        Write-Host "      ${RED}Download failed: $($_.Exception.Message)${RESET}"
        return $false
    }
}

function Get-OracleJreUrl {
    # Resolves the current Oracle Java 8 "Windows Offline (32-bit)" installer
    # URL from java.com. No Oracle login required. Returns $null on failure.
    try {
        $page = Invoke-WebRequest $javaManualPage -UseBasicParsing -TimeoutSec 30
        $ids = @()
        foreach ($m in [regex]::Matches($page.Content, 'AutoDL\?BundleId=\d+_[a-f0-9]+')) {
            $u = "https://javadl.oracle.com/webapps/download/" + $m.Value
            if ($ids -notcontains $u) { $ids += $u }
        }
        foreach ($u in $ids) {
            $req = [System.Net.HttpWebRequest]::Create($u)
            $req.UserAgent = "Mozilla/5.0"
            $req.AllowAutoRedirect = $false
            $req.Timeout = 30000
            $resp = $req.GetResponse()
            $loc = $resp.Headers["Location"]
            $resp.Close()
            # The 32-bit offline installer file name is jre-8uNNN-windows-i586.exe
            # (exclude the online "-iftw" stub and the x64 build).
            if ($loc -and $loc -match 'jre-8u\d+-windows-i586\.exe' -and $loc -notmatch 'iftw') {
                return $u
            }
        }
    } catch {}
    return $null
}

function Install-OracleJre {
    # Oracle's .exe wrapper is unreliable in silent/automated sessions (it can
    # extract the MSI, delete it, and exit 3 without installing). The robust
    # method is to grab the MSI it stages and run it via msiexec directly.
    param([string]$Installer)

    $lowRoot = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'AppData\LocalLow\Oracle\Java'
    $msiDest = Join-Path $env:TEMP 'oracle-jre-msi'
    if (Test-Path $msiDest) { Remove-Item $msiDest -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Path $msiDest -Force | Out-Null

    # Launch the wrapper; race to copy the staged MSI out before it is deleted.
    $proc = Start-Process -FilePath $Installer -ArgumentList @('/s') -PassThru
    $msiPath = $null
    for ($i = 0; $i -lt 900; $i++) {
        if (Test-Path $lowRoot) {
            $msi = Get-ChildItem $lowRoot -Recurse -Filter '*.msi' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($msi) {
                try {
                    $dst = Join-Path $msiDest $msi.Name
                    Copy-Item $msi.FullName $dst -Force -ErrorAction Stop
                    $msiPath = $dst
                    break
                } catch { }
            }
        }
        if ($proc.HasExited -and -not (Test-Path $lowRoot)) { break }
        Start-Sleep -Milliseconds 100
    }
    try { if (-not $proc.HasExited) { $proc.WaitForExit(60000) | Out-Null } } catch {}

    if (-not $msiPath) { return $false }

    # Install the MSI: enable the browser plugin, disable auto-update.
    $msiLog = Join-Path $env:TEMP 'oracle-jre-msiexec.log'
    $mArgs = @(
        '/i', "`"$msiPath`"", '/qn', '/norestart', '/l*v', "`"$msiLog`"",
        'WEB_JAVA=1', 'WEB_JAVA_SECURITY_LEVEL=H',
        'JAVAUPDATE=0', 'JU=0', 'AUTOUPDATECHECK=0', 'SPONSORS=0', 'NOSTARTMENU=1'
    )
    $mi = Start-Process -FilePath 'msiexec.exe' -ArgumentList $mArgs -Wait -PassThru
    return ($mi.ExitCode -eq 0)
}

function Show-Summary {
    Write-Host ""
    Write-Host "  ${BOLD}${CYAN}+============================================================+${RESET}"
    Write-Host "  ${BOLD}${CYAN}|${RESET}  ${BOLD}${WHITE}SETUP COMPLETE${RESET}                                           ${BOLD}${CYAN}|${RESET}"
    Write-Host "  ${BOLD}${CYAN}+============================================================+${RESET}"

    foreach ($key in $results.Keys | Sort-Object) {
        $val = $results[$key]
        if ($val -eq "OK") {
            $icon = "${GREEN}$SYM_CHECK${RESET}"
        } elseif ($val -eq "SKIP") {
            $icon = "${YELLOW}$SYM_RAQUO${RESET}"
        } else {
            $icon = "${RED}$SYM_CROSS${RESET}"
        }
        $line = "  $icon $key"
        $padded = $line.PadRight(68)
        Write-Host "  ${BOLD}${CYAN}|${RESET}$padded${BOLD}${CYAN}|${RESET}"
    }

    Write-Host "  ${BOLD}${CYAN}+============================================================+${RESET}"
    Write-Host "  ${BOLD}${CYAN}|${RESET}  ${DIM}Setup by Vision Technologies and Robotics${RESET}                 ${BOLD}${CYAN}|${RESET}"
    Write-Host "  ${BOLD}${CYAN}|${RESET}  ${DIM}Contact: subho@visiontech.com.in${RESET}                          ${BOLD}${CYAN}|${RESET}"
    Write-Host "  ${BOLD}${CYAN}+============================================================+${RESET}"
    Write-Host ""
}

function Show-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "  ${BOLD}${MAGENTA}-- $Title --${RESET}"
    Write-Host ""
}

function Get-UninstallEntries {
    # Read installed-program entries from both 32-bit and 64-bit uninstall hives.
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    $items = @()
    foreach ($r in $roots) {
        if (Test-Path $r) {
            Get-ChildItem $r -ErrorAction SilentlyContinue | ForEach-Object {
                $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                if ($p -and $p.DisplayName) {
                    $items += [PSCustomObject]@{
                        Name           = $p.DisplayName
                        Version        = $p.DisplayVersion
                        Uninstall      = $p.UninstallString
                        QuietUninstall = $p.QuietUninstallString
                        Key            = $_.PSChildName
                        Location       = $p.InstallLocation
                    }
                }
            }
        }
    }
    return $items
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

Show-Banner

# --- Pre-checks ---
Show-SectionHeader "PRE-FLIGHT CHECKS"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  ${RED}[$SYM_CROSS] This script must be run as Administrator.${RESET}"
    Write-Host "  ${DIM}    Please right-click setup.bat and select 'Run as administrator'.${RESET}"
    exit 1
}
Show-Step -Number 0 -Text "Administrator privileges" -Status "done"

# Use an HTTP HEAD request instead of ICMP ping (many govt/corporate
# networks block ping). Non-fatal: the actual downloads report their
# own errors, so a false negative here should not stop the script.
$internet = $false
try {
    $req = [System.Net.HttpWebRequest]::Create("https://ftp.mozilla.org/")
    $req.Method = "HEAD"
    $req.Timeout = 10000
    $req.UserAgent = "VisionTech-Setup/1.0"
    $resp = $req.GetResponse()
    $resp.Close()
    $internet = $true
} catch {
    # Some proxies reject HEAD but allow GET; treat any HTTP response as online
    if ($_.Exception.Response) { $internet = $true }
}
if ($internet) {
    Show-Step -Number 0 -Text "Internet connectivity" -Status "done"
} else {
    Show-Step -Number 0 -Text "Internet check inconclusive (will try anyway)" -Status "skip"
}

# ============================================================================
# STEP 0.5: Detect & remove CONFLICTING Firefox / Java versions
# ============================================================================
# Our required versions are Firefox 43.0.1 and a specific Oracle Java 8 (the
# bundled jre-8u*-windows-i586.exe, e.g. 8u231). Any OTHER Firefox or Java
# breaks the digital-signature applet, so we offer to remove them (and wipe
# Firefox profiles) after an explicit confirmation.
Show-SectionHeader "CHECKING FOR CONFLICTING VERSIONS"

# Our target versions
$targetFFVer = "43.0.1"
$bundledInstaller = Get-ChildItem $scriptDir -Filter "jre-8u*-windows-i586.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
$targetJavaUpdate = $null
if ($bundledInstaller -and $bundledInstaller.Name -match 'jre-8u(\d+)-') {
    $targetJavaUpdate = $Matches[1]
} elseif ($javaPinnedUrl -and $javaPinnedUrl -match 'jre-8u(\d+)-') {
    $targetJavaUpdate = $Matches[1]
}

$allInstalls = Get-UninstallEntries
$ffInstalls  = $allInstalls | Where-Object { $_.Name -match 'Mozilla Firefox' }
$javaInstalls = $allInstalls | Where-Object { $_.Name -match 'Java (\d+ Update \d+|SE Development Kit|\d)' -or $_.Name -match 'Java\(TM\)' }

# Decide what conflicts (i.e. is NOT our version)
$ffToRemove = @($ffInstalls | Where-Object { $_.Version -ne $targetFFVer })
$javaToRemove = @($javaInstalls | Where-Object {
    if ($targetJavaUpdate) { -not ($_.Name -match "Update\s+$targetJavaUpdate(\b|\s|\()") } else { $true }
})

if ($ffToRemove.Count -eq 0 -and $javaToRemove.Count -eq 0) {
    Show-Step -Number 0 -Text "No conflicting Firefox or Java versions found" -Status "done"
} else {
    Write-Host "  ${YELLOW}The following will be REMOVED so the correct versions can be installed:${RESET}"
    Write-Host ""
    foreach ($x in $ffToRemove)  { Write-Host "    ${RED}[Firefox]${RESET} $($x.Name)  ($($x.Version))" }
    foreach ($x in $javaToRemove) { Write-Host "    ${RED}[Java]   ${RESET} $($x.Name)  ($($x.Version))" }
    Write-Host ""
    if ($ffToRemove.Count -gt 0) {
        Write-Host "  ${YELLOW}All Firefox profiles will also be deleted${RESET} (bookmarks, saved"
        Write-Host "  passwords, and history in those Firefox profiles will be LOST)."
        Write-Host ""
    }
    $answer = Read-Host "  Type YES to remove these and continue (anything else = keep them)"
    if ($answer -eq 'YES') {
        # --- Uninstall conflicting Java ---
        foreach ($j in $javaToRemove) {
            Write-Host "      ${DIM}Uninstalling $($j.Name)...${RESET}"
            try {
                if ($j.Key -match '^\{[0-9A-Fa-f\-]+\}$') {
                    Start-Process "msiexec.exe" -ArgumentList "/x $($j.Key) /qn /norestart" -Wait -ErrorAction Stop
                } elseif ($j.QuietUninstall) {
                    Start-Process "cmd.exe" -ArgumentList "/c $($j.QuietUninstall)" -Wait -ErrorAction Stop
                }
            } catch {}
        }
        # --- Uninstall conflicting Firefox (NSIS silent) ---
        foreach ($f in $ffToRemove) {
            Write-Host "      ${DIM}Uninstalling $($f.Name)...${RESET}"
            try {
                $helper = $null
                if ($f.Location -and (Test-Path (Join-Path $f.Location "uninstall\helper.exe"))) {
                    $helper = Join-Path $f.Location "uninstall\helper.exe"
                } elseif ($f.Uninstall -and $f.Uninstall -match 'helper\.exe') {
                    $helper = ($f.Uninstall -replace '"','').Trim()
                }
                if ($helper -and (Test-Path $helper)) {
                    Start-Process $helper -ArgumentList "/S" -Wait -ErrorAction Stop
                    Start-Sleep -Seconds 2
                }
            } catch {}
        }
        # --- Remove Firefox profiles (our dedicated DSC profile lives elsewhere) ---
        if ($ffToRemove.Count -gt 0) {
            Get-Process firefox -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            foreach ($pdir in @("$env:APPDATA\Mozilla\Firefox", "$env:LOCALAPPDATA\Mozilla\Firefox")) {
                if (Test-Path $pdir) {
                    try { Remove-Item $pdir -Recurse -Force -ErrorAction Stop } catch {}
                }
            }
        }
        Show-Step -Number 0 -Text "Conflicting versions removed" -Status "done"
        $results["Removed Conflicting Versions"] = "OK"
    } else {
        Show-Step -Number 0 -Text "Kept existing versions (user declined removal)" -Status "skip"
        Write-Host "  ${YELLOW}WARNING:${RESET} the digital signature may not work while other"
        Write-Host "  Firefox/Java versions remain installed."
    }
}

# ============================================================================
# STEP 1: Download Firefox
# ============================================================================
Show-SectionHeader "STEP 1: FIREFOX 43.0.1 (32-BIT)"

if (Test-Path $firefoxDir) {
    $existingVersion = $null
    $appIni = Join-Path $firefoxDir "application.ini"
    if (Test-Path $appIni) {
        $existingVersion = (Get-Content $appIni | Where-Object { $_ -match "^Version=" }) -replace "Version=", ""
    }
    if ($existingVersion -eq "43.0.1") {
        Show-Step -Number 1 -Text "Firefox 43.0.1 already installed" -Status "skip"
        $results["Firefox 43.0.1 Install"] = "SKIP"
    } else {
        Show-Step -Number 1 -Text "Different Firefox version found ($existingVersion), will reinstall" -Status "running"
    }
}

if ($results["Firefox 43.0.1 Install"] -ne "SKIP") {
    Show-Step -Number 1 -Text "Downloading Firefox 43.0.1..." -Status "running"
    $dlResult = Download-WithProgress -Url $firefoxUrl -OutFile $firefoxInstaller -DisplayName "Firefox 43.0.1"

    if ($dlResult) {
        $iniPath = Join-Path $scriptDir "firefox-install.ini"
        $proc = Start-Process -FilePath $firefoxInstaller -ArgumentList "/INI=`"$iniPath`"" -PassThru
        Show-Busy -Text "Installing Firefox silently..." -Process $proc
        $proc.WaitForExit()
        if ($proc.ExitCode -eq 0) {
            Show-Step -Number 1 -Text "Firefox 43.0.1 installed" -Status "done"
            $results["Firefox 43.0.1 Install"] = "OK"
        } else {
            Show-Step -Number 1 -Text "Firefox installation (exit code: $($proc.ExitCode))" -Status "fail"
            $results["Firefox 43.0.1 Install"] = "FAIL"
        }
    } else {
        Show-Step -Number 1 -Text "Firefox download" -Status "fail"
        $results["Firefox 43.0.1 Install"] = "FAIL"
    }
}

# ============================================================================
# STEP 2: Disable Firefox Auto-Update (5 layers)
# ============================================================================
Show-SectionHeader "STEP 2: DISABLE FIREFOX AUTO-UPDATE"

if (Test-Path $firefoxDir) {
    # Layer 1: mozilla.cfg
    Write-Host "      ${DIM}Layer 1/5: Deploying mozilla.cfg (autoconfig)...${RESET}"
    Copy-Item (Join-Path $scriptDir "mozilla.cfg") (Join-Path $firefoxDir "mozilla.cfg") -Force
    Show-Step -Number 2 -Text "mozilla.cfg deployed" -Status "done"

    # Layer 2: local-settings.js
    Write-Host "      ${DIM}Layer 2/5: Deploying local-settings.js...${RESET}"
    $prefDir = Join-Path $firefoxDir "defaults\pref"
    if (-not (Test-Path $prefDir)) { New-Item -ItemType Directory -Path $prefDir -Force | Out-Null }
    Copy-Item (Join-Path $scriptDir "local-settings.js") (Join-Path $prefDir "local-settings.js") -Force
    Show-Step -Number 2 -Text "local-settings.js deployed" -Status "done"

    # Deploy toolbar bookmarks via distribution.ini (adds "1st Sign" / "2nd Sign"
    # to the Bookmarks Toolbar of any fresh Firefox profile).
    $distSrc = Join-Path $scriptDir "distribution.ini"
    if (Test-Path $distSrc) {
        Write-Host "      ${DIM}Deploying toolbar bookmarks (distribution.ini)...${RESET}"
        $distDir = Join-Path $firefoxDir "distribution"
        if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir -Force | Out-Null }
        Copy-Item $distSrc (Join-Path $distDir "distribution.ini") -Force
        Show-Step -Number 2 -Text "Toolbar bookmarks (1st Sign / 2nd Sign) deployed" -Status "done"
    }

    # Layer 3: Disable Mozilla Maintenance Service
    Write-Host "      ${DIM}Layer 3/5: Disabling Mozilla Maintenance Service...${RESET}"
    try {
        Stop-Service -Name "MozillaMaintenance" -Force -ErrorAction Stop
    } catch {}
    try {
        Set-Service -Name "MozillaMaintenance" -StartupType Disabled -ErrorAction Stop
    } catch {}
    Show-Step -Number 2 -Text "Maintenance Service disabled" -Status "done"

    # Layer 4: Rename updater.exe (idempotent - handles re-runs where
    # updater.exe.disabled already exists from a previous run)
    Write-Host "      ${DIM}Layer 4/5: Disabling updater executable...${RESET}"
    try {
        $updaterPath  = Join-Path $firefoxDir "updater.exe"
        $disabledPath = Join-Path $firefoxDir "updater.exe.disabled"
        if (Test-Path $updaterPath) {
            if (Test-Path $disabledPath) {
                # Already disabled once before; a fresh updater.exe reappeared
                # (e.g. reinstall). Just remove the new one.
                Remove-Item $updaterPath -Force -ErrorAction SilentlyContinue
            } else {
                Rename-Item $updaterPath $disabledPath -Force -ErrorAction Stop
            }
            Show-Step -Number 2 -Text "updater.exe disabled" -Status "done"
        } else {
            Show-Step -Number 2 -Text "updater.exe already disabled" -Status "skip"
        }
    } catch {
        Show-Step -Number 2 -Text "updater.exe (could not disable, skipped)" -Status "skip"
    }

    # Layer 5: Block update servers in hosts file
    Write-Host "      ${DIM}Layer 5/5: Blocking Firefox update servers in hosts file...${RESET}"
    try {
        $hostsFile = "C:\Windows\System32\drivers\etc\hosts"
        $hostsContent = Get-Content $hostsFile -Raw -ErrorAction Stop
        $updateHosts = @(
            "aus4.mozilla.org",
            "aus5.mozilla.org",
            "aus2.mozilla.org",
            "aus3.mozilla.org",
            # Blocklist servers - stop Firefox from fetching a blocklist that
            # hard-blocks (hides) the Java plugin.
            "blocklist.addons.mozilla.org",
            "blocklists.settings.services.mozilla.com",
            "firefox.settings.services.mozilla.com"
        )
        $hostsModified = $false
        foreach ($h in $updateHosts) {
            if ($hostsContent -notmatch [regex]::Escape($h)) {
                Add-Content -Path $hostsFile -Value "127.0.0.1 $h" -ErrorAction Stop
                $hostsModified = $true
            }
        }
        if ($hostsModified) {
            Show-Step -Number 2 -Text "Update servers blocked in hosts file" -Status "done"
        } else {
            Show-Step -Number 2 -Text "Update servers already blocked" -Status "skip"
        }
    } catch {
        Show-Step -Number 2 -Text "Hosts file (locked by another process, skipped)" -Status "skip"
    }

    # Remove Mozilla scheduled tasks
    Write-Host "      ${DIM}Cleaning up Mozilla scheduled tasks...${RESET}"
    try {
        $mozTasks = schtasks /query /fo CSV 2>$null | ConvertFrom-Csv | Where-Object { $_.'TaskName' -match 'Mozilla' }
        foreach ($t in $mozTasks) {
            schtasks /delete /tn $t.'TaskName' /f 2>$null | Out-Null
        }
    } catch {}

    # Create a launcher + desktop shortcut. Firefox 43's registry-based plugin
    # detection can fail to surface the Java plugin, so the launcher sets
    # MOZ_PLUGIN_PATH to point Firefox directly at the Oracle Java plugin folder
    # (the reliable discovery mechanism), then opens Firefox 43 in its own
    # isolated profile with -no-remote (so it can't get hijacked into a newer
    # Firefox that lacks Java support).
    Write-Host "      ${DIM}Creating launcher + 'VBGRAMG DSC Signing' desktop shortcut...${RESET}"
    try {
        $dscProfile = Join-Path $env:LOCALAPPDATA "VBGRAMG-DSC-FF43"
        if (-not (Test-Path $dscProfile)) { New-Item -ItemType Directory -Path $dscProfile -Force | Out-Null }

        # Force the Bookmarks Toolbar visible in the DSC profile (Firefox 43
        # hides it by default) so the "1st Sign" / "2nd Sign" bookmarks show.
        # Only seed it if the profile is brand new (no places.sqlite yet), so we
        # don't clobber a profile the user has already customised.
        if (-not (Test-Path (Join-Path $dscProfile "places.sqlite"))) {
            $xulStore = '{"chrome://browser/content/browser.xul":{"PersonalToolbar":{"collapsed":"false"}}}'
            Set-Content -Path (Join-Path $dscProfile "xulstore.json") -Value $xulStore -Encoding ASCII
        }

        $launchDir = Join-Path $env:LOCALAPPDATA "VBGRAMG-DSC"
        if (-not (Test-Path $launchDir)) { New-Item -ItemType Directory -Path $launchDir -Force | Out-Null }
        $launcher = Join-Path $launchDir "open-portal.cmd"

        $ffExe = Join-Path $firefoxDir "firefox.exe"
        $launcherBody = @"
@echo off
setlocal EnableExtensions
set "FF=$ffExe"
set "PLUGDIR="
for /d %%D in ("C:\Program Files (x86)\Java\jre*") do (
    if exist "%%D\bin\plugin2\npjp2.dll" set "PLUGDIR=%%D\bin\plugin2"
)
if defined PLUGDIR set "MOZ_PLUGIN_PATH=%PLUGDIR%"
start "" "%FF%" -no-remote -profile "$dscProfile"
"@
        Set-Content -Path $launcher -Value $launcherBody -Encoding ASCII

        # Also set MOZ_PLUGIN_PATH machine-wide as a belt-and-suspenders. Harmless
        # for modern Firefox (it ignores NPAPI); helps any Firefox 43 launch.
        $pluginDir = $null
        if (Test-Path $javaRoot) {
            $np = Get-ChildItem $javaRoot -Recurse -Filter "npjp2.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($np) { $pluginDir = Split-Path $np.FullName -Parent }
        }
        if ($pluginDir) {
            try { [Environment]::SetEnvironmentVariable("MOZ_PLUGIN_PATH", $pluginDir, "Machine") } catch {}
        }

        $desktop = [Environment]::GetFolderPath('Desktop')
        $lnkPath = Join-Path $desktop "VBGRAMG DSC Signing (Firefox 43).lnk"
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($lnkPath)
        $sc.TargetPath = $launcher
        $sc.WorkingDirectory = $launchDir
        $sc.IconLocation = "$ffExe,0"
        $sc.WindowStyle = 7   # minimized, so the brief cmd window barely shows
        $sc.Description = "Opens NREGA/VBGRAMG portals in Firefox 43 with Java digital signature support"
        $sc.Save()
        Show-Step -Number 2 -Text "Launcher + desktop shortcut 'VBGRAMG DSC Signing (Firefox 43)' created" -Status "done"
    } catch {
        Show-Step -Number 2 -Text "Desktop shortcut (could not create, skipped)" -Status "skip"
    }

    $results["Firefox Auto-Update Disabled"] = "OK"
} else {
    Show-Step -Number 2 -Text "Firefox not found, skipping update disable" -Status "fail"
    $results["Firefox Auto-Update Disabled"] = "FAIL"
}

# ============================================================================
# STEP 3: Download & Install Java (Oracle JRE 8, 32-bit - ships applet plugin)
# ============================================================================
Show-SectionHeader "STEP 3: JAVA 8 (ORACLE JRE, 32-BIT)"

# Prefer a bundled Oracle JRE installer (e.g. jre-8u231-windows-i586.exe) placed
# next to this script. Government DSC applets often require a SPECIFIC older Java
# 8 version (e.g. 8u231); the very latest Java 8 can break them. Bundling the
# known-good installer pins that exact version. If none is bundled, fall back to
# downloading the current Oracle Java 8 from java.com.
$localJre = Get-ChildItem $scriptDir -Filter "jre-8u*-windows-i586.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
$bundledVer = $null
if ($localJre -and $localJre.Name -match 'jre-8u(\d+)-') { $bundledVer = $Matches[1] }

# Is our target version (from bundled file OR pinned URL, = $targetJavaUpdate)
# already installed with its browser plugin? Then skip re-installing.
$targetInstalled = $false
if ($targetJavaUpdate) {
    $targetInstalled = Test-Path "C:\Program Files (x86)\Java\jre1.8.0_$targetJavaUpdate\bin\plugin2\npjp2.dll"
}

$existingPlugin = $null
if (Test-Path $javaRoot) {
    $existingPlugin = Get-ChildItem $javaRoot -Recurse -Filter "npjp2.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
}

if ($targetJavaUpdate -and $targetInstalled) {
    Show-Step -Number 3 -Text "Oracle Java 8u$targetJavaUpdate already installed" -Status "skip"
    $results["Java 8 (Oracle 8u$targetJavaUpdate) Install"] = "SKIP"
} elseif ($localJre) {
    Show-Step -Number 3 -Text "Installing bundled $($localJre.Name)..." -Status "running"
    Write-Host "      ${DIM}Installing Oracle Java 8u$bundledVer from bundled installer...${RESET}"
    $ok = Install-OracleJre -Installer $localJre.FullName
    if ($ok) {
        Show-Step -Number 3 -Text "Oracle Java 8u$bundledVer installed (with browser plugin)" -Status "done"
        $results["Java 8 (Oracle 8u$bundledVer) Install"] = "OK"
    } else {
        Show-Step -Number 3 -Text "Oracle Java 8u$bundledVer installation failed" -Status "fail"
        $results["Java 8 (Oracle 8u$bundledVer) Install"] = "FAIL"
    }
} elseif ($javaPinnedUrl) {
    # Download the pinned Java version from the deployer's storage (e.g. Dropbox).
    $verLabel = if ($targetJavaUpdate) { "8u$targetJavaUpdate" } else { "8" }
    Show-Step -Number 3 -Text "Downloading pinned Oracle Java $verLabel..." -Status "running"
    $pinUrl = $javaPinnedUrl
    if ($pinUrl -match 'dl=0') { $pinUrl = $pinUrl -replace 'dl=0','dl=1' }
    elseif ($pinUrl -notmatch 'dl=1') { $pinUrl += $(if ($pinUrl -match '\?') { '&dl=1' } else { '?dl=1' }) }
    $dlResult = Download-WithProgress -Url $pinUrl -OutFile $javaInstaller -DisplayName "Oracle Java $verLabel (32-bit)"
    if ($dlResult) {
        Write-Host "      ${DIM}Installing Oracle Java $verLabel silently (this may take a minute)...${RESET}"
        $ok = Install-OracleJre -Installer $javaInstaller
        if ($ok) {
            Show-Step -Number 3 -Text "Oracle Java $verLabel installed (with browser plugin)" -Status "done"
            $results["Java 8 (Oracle $verLabel) Install"] = "OK"
        } else {
            Show-Step -Number 3 -Text "Oracle Java $verLabel installation failed" -Status "fail"
            $results["Java 8 (Oracle $verLabel) Install"] = "FAIL"
        }
    } else {
        Show-Step -Number 3 -Text "Java download from pinned URL failed" -Status "fail"
        $results["Java 8 (Oracle $verLabel) Install"] = "FAIL"
    }
} elseif ($existingPlugin) {
    Show-Step -Number 3 -Text "Oracle Java 8 (with browser plugin) already installed" -Status "skip"
    $results["Java 8 (Oracle) Install"] = "SKIP"
} else {
    Write-Host "      ${YELLOW}No bundled/pinned installer; downloading latest Oracle Java 8.${RESET}"
    Show-Step -Number 3 -Text "Locating Oracle Java 8 (32-bit) download..." -Status "running"
    $javaUrl = Get-OracleJreUrl
    if (-not $javaUrl) {
        Show-Step -Number 3 -Text "Could not resolve Oracle Java download URL" -Status "fail"
        $results["Java 8 (Oracle) Install"] = "FAIL"
    } else {
        $dlResult = Download-WithProgress -Url $javaUrl -OutFile $javaInstaller -DisplayName "Oracle Java 8 (32-bit)"
        if ($dlResult) {
            Write-Host "      ${DIM}Installing Oracle Java 8 silently (this may take a minute)...${RESET}"
            $ok = Install-OracleJre -Installer $javaInstaller
            if ($ok) {
                Show-Step -Number 3 -Text "Oracle Java 8 installed (with browser plugin)" -Status "done"
                $results["Java 8 (Oracle) Install"] = "OK"
            } else {
                Show-Step -Number 3 -Text "Oracle Java installation failed" -Status "fail"
                $results["Java 8 (Oracle) Install"] = "FAIL"
            }
        } else {
            Show-Step -Number 3 -Text "Java download" -Status "fail"
            $results["Java 8 (Oracle) Install"] = "FAIL"
        }
    }
}

# ============================================================================
# STEP 4: Configure Java Security
# ============================================================================
Show-SectionHeader "STEP 4: JAVA SECURITY CONFIGURATION"

# System-level deployment.config
Write-Host "      ${DIM}Creating Java deployment configuration...${RESET}"
$deployConfigDir = "C:\Windows\Sun\Java\Deployment"
if (-not (Test-Path $deployConfigDir)) {
    New-Item -ItemType Directory -Path $deployConfigDir -Force | Out-Null
}

$deployConfig = @"
deployment.system.config=file:///C:/Windows/Sun/Java/Deployment/deployment.properties
deployment.system.config.mandatory=false
"@
Set-Content -Path (Join-Path $deployConfigDir "deployment.config") -Value $deployConfig -Encoding UTF8
Show-Step -Number 4 -Text "deployment.config created" -Status "done"

# System-level deployment.properties
$deployProps = @"
deployment.security.level=HIGH
deployment.expiration.check.enabled=false
deployment.javaws.autodownload=NEVER
deployment.webjava.enabled=true
deployment.security.mixcode=HIDE_RUN
deployment.security.validation.ocsp=false
deployment.security.revocation.check=NO_CHECK
"@
Set-Content -Path (Join-Path $deployConfigDir "deployment.properties") -Value $deployProps -Encoding UTF8
Show-Step -Number 4 -Text "deployment.properties configured" -Status "done"

# Exception site list
Write-Host "      ${DIM}Setting up exception site list...${RESET}"
$userDeployDir = Join-Path $env:USERPROFILE "AppData\LocalLow\Sun\Java\Deployment\security"
if (-not (Test-Path $userDeployDir)) {
    New-Item -ItemType Directory -Path $userDeployDir -Force | Out-Null
}
$exceptionSrc = Join-Path $scriptDir "exception.sites"
if (Test-Path $exceptionSrc) {
    Copy-Item $exceptionSrc (Join-Path $userDeployDir "exception.sites") -Force
}
Show-Step -Number 4 -Text "Exception site list deployed" -Status "done"

# Disable Java auto-update via registry
Write-Host "      ${DIM}Disabling Java auto-update...${RESET}"
$javaUpdatePath = "HKLM:\SOFTWARE\WOW6432Node\JavaSoft\Java Update\Policy"
if (-not (Test-Path $javaUpdatePath)) {
    New-Item -Path $javaUpdatePath -Force | Out-Null
}
Set-ItemProperty -Path $javaUpdatePath -Name "EnableJavaUpdate" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $javaUpdatePath -Name "EnableAutoUpdateCheck" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $javaUpdatePath -Name "NotifyDownload" -Value 0 -Type DWord -Force

# Also set under the non-WOW path for 32-bit systems
$javaUpdatePath32 = "HKLM:\SOFTWARE\JavaSoft\Java Update\Policy"
if (-not (Test-Path $javaUpdatePath32)) {
    New-Item -Path $javaUpdatePath32 -Force | Out-Null
}
Set-ItemProperty -Path $javaUpdatePath32 -Name "EnableJavaUpdate" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $javaUpdatePath32 -Name "EnableAutoUpdateCheck" -Value 0 -Type DWord -Force

# Remove Java update scheduled tasks
try {
    $javaTasks = schtasks /query /fo CSV 2>$null | ConvertFrom-Csv | Where-Object { $_.'TaskName' -match 'Java' -and $_.'TaskName' -match 'Update' }
    foreach ($t in $javaTasks) {
        schtasks /delete /tn $t.'TaskName' /f 2>$null | Out-Null
    }
} catch {}

Show-Step -Number 4 -Text "Java auto-update disabled" -Status "done"
$results["Java Security Config"] = "OK"

# ============================================================================
# STEP 5: Refresh Firefox plugin cache
# ============================================================================
# Firefox caches its plugin scan in pluginreg.dat. If Firefox was ever opened
# before Java was installed, that cache says "no Java" and Firefox keeps
# trusting it -> "A plugin is needed to display this content". Deleting the
# cache forces Firefox to re-scan and discover the Java plugin on next launch.
Show-SectionHeader "STEP 5: REFRESH FIREFOX PLUGIN CACHE"

$ffProfileRoot = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
$cleared = 0
if (Test-Path $ffProfileRoot) {
    Get-ChildItem $ffProfileRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $preg = Join-Path $_.FullName 'pluginreg.dat'
        if (Test-Path $preg) {
            try { Remove-Item $preg -Force -ErrorAction Stop; $cleared++ } catch {}
        }
    }
    Show-Step -Number 5 -Text "Firefox plugin cache cleared ($cleared profile(s)) - Java will be detected on next launch" -Status "done"
} else {
    Show-Step -Number 5 -Text "No Firefox profile yet (plugin will be scanned on first launch)" -Status "skip"
}
$results["Firefox Plugin Cache Refreshed"] = "OK"

# ============================================================================
# STEP 6: Cleanup
# ============================================================================
Show-SectionHeader "STEP 6: CLEANUP"

if (Test-Path $firefoxInstaller) { Remove-Item $firefoxInstaller -Force }
if (Test-Path $javaInstaller) { Remove-Item $javaInstaller -Force }
Show-Step -Number 6 -Text "Temporary files cleaned up" -Status "done"

# ============================================================================
# SUMMARY
# ============================================================================
Show-Summary

Write-Host "  ${GREEN}IMPORTANT:${RESET} To sign documents, open the portal using the"
Write-Host "  ${WHITE}'VBGRAMG DSC Signing (Firefox 43)'${RESET} icon on your Desktop."
Write-Host "  ${DIM}That icon always opens the correct Firefox 43 with Java enabled.${RESET}"
Write-Host "  ${DIM}Do NOT use your normal Firefox/Chrome/Edge for the portal.${RESET}"
Write-Host ""
Write-Host "  ${YELLOW}NOTE:${RESET} Edit ${CYAN}exception.sites${RESET} to add more portal URLs, then re-run."
Write-Host ""
Write-Host "  ${DIM}Press any key to exit...${RESET}"
