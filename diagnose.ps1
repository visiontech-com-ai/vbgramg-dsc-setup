# ============================================================================
# VBGRAMG DSC Setup - Diagnostic
# Reports whether Firefox 43 + Oracle Java 8 + the browser plugin are correctly
# installed and wired together. Read-only: it changes nothing.
# ============================================================================

$report = @()
function Line($s) { $script:report += $s; Write-Host $s }

Line "============================================================"
Line " VBGRAMG DSC - Diagnostic Report"
Line " Vision Technologies and Robotics"
Line "============================================================"
Line ""

# --- Firefox ---
Line "[1] FIREFOX"
$ffDir = "C:\Program Files (x86)\Mozilla Firefox"
$ffExe = Join-Path $ffDir "firefox.exe"
if (Test-Path $ffExe) {
    $ver = (Get-Item $ffExe).VersionInfo.ProductVersion
    Line "    Installed: YES"
    Line "    Path:      $ffExe"
    Line "    Version:   $ver"
    Line "    Bitness:   32-bit (Program Files x86)"
    $appIni = Join-Path $ffDir "application.ini"
    if (Test-Path $appIni) {
        $v = (Get-Content $appIni | Where-Object { $_ -match '^Version=' }) -replace 'Version=',''
        Line "    app.ini:   $v"
    }
    Line "    mozilla.cfg present: $(Test-Path (Join-Path $ffDir 'mozilla.cfg'))"
} else {
    Line "    Installed: NO  <-- Firefox 43 is not installed"
}
Line ""

# --- Oracle Java + browser plugin ---
Line "[2] JAVA + BROWSER PLUGIN"
$javaRoot = "C:\Program Files (x86)\Java"
$npjp2 = $null
if (Test-Path $javaRoot) {
    $npjp2 = Get-ChildItem $javaRoot -Recurse -Filter 'npjp2.dll' -ErrorAction SilentlyContinue | Select-Object -First 1
    $jre = Get-ChildItem $javaRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'jre' } | Select-Object -First 1
    if ($jre) {
        Line "    Oracle JRE folder: $($jre.FullName)"
        $je = Join-Path $jre.FullName 'bin\java.exe'
        if (Test-Path $je) {
            $vout = & $je -version 2>&1 | Select-Object -First 1
            Line "    java -version:     $vout"
        }
    } else {
        Line "    Oracle JRE folder: NONE under $javaRoot"
    }
} else {
    Line "    C:\Program Files (x86)\Java : does NOT exist  <-- Oracle Java not installed (32-bit)"
}
if ($npjp2) {
    Line "    npjp2.dll (plugin): FOUND -> $($npjp2.FullName)"
} else {
    Line "    npjp2.dll (plugin): NOT FOUND  <-- browser plugin missing"
}
# Also flag a 64-bit Java install (won't work with 32-bit Firefox)
if (Test-Path "C:\Program Files\Java") {
    $j64 = Get-ChildItem "C:\Program Files\Java" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($j64) { Line "    NOTE: 64-bit Java also present ($($j64.Name)) - Firefox 32-bit cannot use it" }
}
Line ""

# --- MozillaPlugins registry keys (how Firefox discovers the plugin) ---
Line "[3] MOZILLA PLUGINS REGISTRY (Firefox reads these)"
$keys = @('HKLM:\SOFTWARE\WOW6432Node\MozillaPlugins','HKLM:\SOFTWARE\MozillaPlugins',
          'HKCU:\SOFTWARE\MozillaPlugins')
$anyKey = $false
foreach ($k in $keys) {
    if (Test-Path $k) {
        Get-ChildItem $k -ErrorAction SilentlyContinue | ForEach-Object {
            $p = (Get-ItemProperty $_.PSPath -Name Path -ErrorAction SilentlyContinue).Path
            Line "    $($_.PSChildName)"
            Line "        -> $p"
            if ($_.PSChildName -match 'JavaPlugin') { $anyKey = $true }
        }
    }
}
if (-not $anyKey) { Line "    NO @java.com/JavaPlugin key found  <-- Firefox will not see Java" }
Line ""

# --- Firefox plugin registration (pluginreg.dat in the profile) ---
Line "[4] FIREFOX PROFILE PLUGIN STATE"
$profRoot = Join-Path $env:APPDATA 'Mozilla\Firefox\Profiles'
if (Test-Path $profRoot) {
    Get-ChildItem $profRoot -Directory | ForEach-Object {
        $reg = Join-Path $_.FullName 'pluginreg.dat'
        Line "    Profile: $($_.Name)"
        if (Test-Path $reg) {
            $c = Get-Content $reg -Raw
            if ($c -match 'npjp2\.dll') { Line "        pluginreg.dat lists npjp2.dll: YES" }
            else { Line "        pluginreg.dat lists npjp2.dll: NO (Firefox has not registered Java yet)" }
        } else {
            Line "        pluginreg.dat: not created yet (open Firefox once)"
        }
    }
} else {
    Line "    No Firefox profile found (open Firefox at least once)"
}
Line ""

# --- Java Deployment / exception sites ---
Line "[5] JAVA DEPLOYMENT CONFIG"
Line "    deployment.config: $(Test-Path 'C:\Windows\Sun\Java\Deployment\deployment.config')"
Line "    deployment.properties: $(Test-Path 'C:\Windows\Sun\Java\Deployment\deployment.properties')"
$exc = Join-Path $env:USERPROFILE 'AppData\LocalLow\Sun\Java\Deployment\security\exception.sites'
Line "    exception.sites: $(Test-Path $exc)"
if (Test-Path $exc) { Get-Content $exc | ForEach-Object { Line "        $_" } }
Line ""

Line "============================================================"
Line " SUMMARY"
$okFF = Test-Path $ffExe
$okPlugin = [bool]$npjp2
$okKey = $anyKey
Line "    Firefox 43 installed .......... $(if($okFF){'OK'}else{'MISSING'})"
Line "    Oracle Java plugin (npjp2.dll)  $(if($okPlugin){'OK'}else{'MISSING'})"
Line "    MozillaPlugins registry key ... $(if($okKey){'OK'}else{'MISSING'})"
Line "============================================================"

# Save report to Desktop for easy sharing
$desktop = [Environment]::GetFolderPath('Desktop')
$outFile = Join-Path $desktop 'vbgramg-diagnostic.txt'
try {
    $report | Out-File $outFile -Encoding utf8
    Line ""
    Line "Report saved to: $outFile"
    Line "Please send that file (or a screenshot of this window)."
} catch {}
