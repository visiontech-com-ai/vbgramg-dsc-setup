# ============================================================================
# VBGRAMG DSC Setup - Vision Technologies and Robotics
# Installs Firefox 43.0.1 (32-bit) + Azul Zulu JRE 8u232 (32-bit)
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

# --- URLs ---
$firefoxUrl = "https://ftp.mozilla.org/pub/firefox/releases/43.0.1/win32/en-US/Firefox%20Setup%2043.0.1.exe"
$javaUrl    = "https://cdn.azul.com/zulu/bin/zulu8.42.0.23-ca-jre8.0.232-win_i686.msi"

# --- Paths ---
$firefoxInstaller = Join-Path $env:TEMP "FirefoxSetup-43.0.1.exe"
$javaInstaller    = Join-Path $env:TEMP "zulu-jre-8u232-win32.msi"
$firefoxDir       = "C:\Program Files (x86)\Mozilla Firefox"
$javaDir          = "C:\Program Files (x86)\Zulu\zulu-8-jre"

# --- Results tracking ---
$results = @{}

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Show-Banner {
    Clear-Host
    $banner = @"

$BOLD$CYAN
  ╔══════════════════════════════════════════════════════════════════╗
  ║                                                                  ║
  ║     ██╗   ██╗██╗███████╗██╗ ██████╗ ███╗   ██╗                  ║
  ║     ██║   ██║██║██╔════╝██║██╔═══██╗████╗  ██║                  ║
  ║     ██║   ██║██║███████╗██║██║   ██║██╔██╗ ██║                  ║
  ║     ╚██╗ ██╔╝██║╚════██║██║██║   ██║██║╚██╗██║                  ║
  ║      ╚████╔╝ ██║███████║██║╚██████╔╝██║ ╚████║                  ║
  ║       ╚═══╝  ╚═╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝                  ║
  ║                                                                  ║
  ║$WHITE   T E C H N O L O G I E S   &   R O B O T I C S$CYAN              ║
  ║                                                                  ║
  ╠══════════════════════════════════════════════════════════════════╣
  ║$YELLOW  VBGRAMG / NREGA Digital Signature Setup Tool$CYAN                 ║
  ║$DIM  Firefox 43.0.1 + Java 8 (Zulu JRE 8u232)$CYAN                     ║
  ╚══════════════════════════════════════════════════════════════════╝
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
        "done"    { Write-Host "  ${GREEN}[✓]${RESET} ${WHITE}$Text${RESET} ${GREEN}Done${RESET}" }
        "skip"    { Write-Host "  ${YELLOW}[»]${RESET} ${DIM}$Text${RESET} ${YELLOW}Skipped${RESET}" }
        "fail"    { Write-Host "  ${RED}[✗]${RESET} ${WHITE}$Text${RESET} ${RED}Failed${RESET}" }
    }
}

function Show-Busy {
    param(
        [string]$Text,
        [System.Diagnostics.Process]$Process
    )
    $frames = @('⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏')
    $i = 0
    while (-not $Process.HasExited) {
        $frame = $frames[$i % $frames.Count]
        Write-Host "`r      ${CYAN}$frame${RESET} ${DIM}$Text${RESET}   " -NoNewline
        Start-Sleep -Milliseconds 120
        $i++
    }
    Write-Host "`r      ${GREEN}✓${RESET} ${DIM}$Text${RESET}   "
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
                $bar = "$GREEN" + ("█" * $filled) + "$DIM" + ("░" * $empty) + "$RESET"
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

function Show-Summary {
    Write-Host ""
    Write-Host "  ${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    Write-Host "  ${BOLD}${CYAN}║${RESET}  ${BOLD}${WHITE}SETUP COMPLETE${RESET}                                             ${BOLD}${CYAN}║${RESET}"
    Write-Host "  ${BOLD}${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"

    foreach ($key in $results.Keys | Sort-Object) {
        $val = $results[$key]
        if ($val -eq "OK") {
            $icon = "${GREEN}✓${RESET}"
        } elseif ($val -eq "SKIP") {
            $icon = "${YELLOW}»${RESET}"
        } else {
            $icon = "${RED}✗${RESET}"
        }
        $line = "  $icon $key"
        $padded = $line.PadRight(70)
        Write-Host "  ${BOLD}${CYAN}║${RESET}$padded${BOLD}${CYAN}║${RESET}"
    }

    Write-Host "  ${BOLD}${CYAN}╠══════════════════════════════════════════════════════════════╣${RESET}"
    Write-Host "  ${BOLD}${CYAN}║${RESET}  ${DIM}Setup by Vision Technologies and Robotics${RESET}                   ${BOLD}${CYAN}║${RESET}"
    Write-Host "  ${BOLD}${CYAN}║${RESET}  ${DIM}Contact: subho@visiontech.com.in${RESET}                            ${BOLD}${CYAN}║${RESET}"
    Write-Host "  ${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    Write-Host ""
}

function Show-SectionHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "  ${BOLD}${MAGENTA}── $Title ──${RESET}"
    Write-Host ""
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

Show-Banner

# --- Pre-checks ---
Show-SectionHeader "PRE-FLIGHT CHECKS"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  ${RED}[✗] This script must be run as Administrator.${RESET}"
    Write-Host "  ${DIM}    Please right-click setup.bat and select 'Run as administrator'.${RESET}"
    exit 1
}
Show-Step -Number 0 -Text "Administrator privileges" -Status "done"

$internet = Test-Connection -ComputerName "ftp.mozilla.org" -Count 1 -Quiet
if (-not $internet) {
    Write-Host "  ${RED}[✗] No internet connection. Cannot download installers.${RESET}"
    exit 1
}
Show-Step -Number 0 -Text "Internet connectivity" -Status "done"

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

    # Layer 3: Disable Mozilla Maintenance Service
    Write-Host "      ${DIM}Layer 3/5: Disabling Mozilla Maintenance Service...${RESET}"
    try {
        Stop-Service -Name "MozillaMaintenance" -Force -ErrorAction Stop
    } catch {}
    try {
        Set-Service -Name "MozillaMaintenance" -StartupType Disabled -ErrorAction Stop
    } catch {}
    Show-Step -Number 2 -Text "Maintenance Service disabled" -Status "done"

    # Layer 4: Rename updater.exe
    Write-Host "      ${DIM}Layer 4/5: Disabling updater executable...${RESET}"
    $updaterPath = Join-Path $firefoxDir "updater.exe"
    if (Test-Path $updaterPath) {
        Rename-Item $updaterPath "updater.exe.disabled" -Force
    }
    Show-Step -Number 2 -Text "updater.exe disabled" -Status "done"

    # Layer 5: Block update servers in hosts file
    Write-Host "      ${DIM}Layer 5/5: Blocking Firefox update servers in hosts file...${RESET}"
    $hostsFile = "C:\Windows\System32\drivers\etc\hosts"
    $hostsContent = Get-Content $hostsFile -Raw
    $updateHosts = @(
        "aus4.mozilla.org",
        "aus5.mozilla.org",
        "aus2.mozilla.org",
        "aus3.mozilla.org"
    )
    $hostsModified = $false
    foreach ($h in $updateHosts) {
        if ($hostsContent -notmatch [regex]::Escape($h)) {
            Add-Content -Path $hostsFile -Value "127.0.0.1 $h"
            $hostsModified = $true
        }
    }
    if ($hostsModified) {
        Show-Step -Number 2 -Text "Update servers blocked in hosts file" -Status "done"
    } else {
        Show-Step -Number 2 -Text "Update servers already blocked" -Status "skip"
    }

    # Remove Mozilla scheduled tasks
    Write-Host "      ${DIM}Cleaning up Mozilla scheduled tasks...${RESET}"
    try {
        $mozTasks = schtasks /query /fo CSV 2>$null | ConvertFrom-Csv | Where-Object { $_.'TaskName' -match 'Mozilla' }
        foreach ($t in $mozTasks) {
            schtasks /delete /tn $t.'TaskName' /f 2>$null | Out-Null
        }
    } catch {}

    $results["Firefox Auto-Update Disabled"] = "OK"
} else {
    Show-Step -Number 2 -Text "Firefox not found, skipping update disable" -Status "fail"
    $results["Firefox Auto-Update Disabled"] = "FAIL"
}

# ============================================================================
# STEP 3: Download & Install Java
# ============================================================================
Show-SectionHeader "STEP 3: JAVA 8 (AZUL ZULU JRE 8u232, 32-BIT)"

$javaExists = Test-Path (Join-Path $javaDir "bin\java.exe")
if ($javaExists) {
    Show-Step -Number 3 -Text "Azul Zulu JRE 8u232 already installed" -Status "skip"
    $results["Java 8 (Zulu 8u232) Install"] = "SKIP"
} else {
    Show-Step -Number 3 -Text "Downloading Azul Zulu JRE 8u232..." -Status "running"
    $dlResult = Download-WithProgress -Url $javaUrl -OutFile $javaInstaller -DisplayName "Azul Zulu JRE 8u232"

    if ($dlResult) {
        $proc = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$javaInstaller`" /quiet /norestart INSTALLDIR=`"$javaDir`"" -PassThru
        Show-Busy -Text "Installing Java silently (this may take a minute)..." -Process $proc
        $proc.WaitForExit()
        if ($proc.ExitCode -eq 0) {
            Show-Step -Number 3 -Text "Azul Zulu JRE 8u232 installed" -Status "done"
            $results["Java 8 (Zulu 8u232) Install"] = "OK"
        } else {
            Show-Step -Number 3 -Text "Java installation (exit code: $($proc.ExitCode))" -Status "fail"
            $results["Java 8 (Zulu 8u232) Install"] = "FAIL"
        }
    } else {
        Show-Step -Number 3 -Text "Java download" -Status "fail"
        $results["Java 8 (Zulu 8u232) Install"] = "FAIL"
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
# STEP 5: Cleanup
# ============================================================================
Show-SectionHeader "STEP 5: CLEANUP"

if (Test-Path $firefoxInstaller) { Remove-Item $firefoxInstaller -Force }
if (Test-Path $javaInstaller) { Remove-Item $javaInstaller -Force }
Show-Step -Number 5 -Text "Temporary files cleaned up" -Status "done"

# ============================================================================
# SUMMARY
# ============================================================================
Show-Summary

Write-Host "  ${YELLOW}NOTE:${RESET} Edit ${CYAN}exception.sites${RESET} in the script folder to add your"
Write-Host "  NREGA/VBGRAMG portal URLs, then re-run this script to update."
Write-Host ""
Write-Host "  ${DIM}Press any key to exit...${RESET}"
