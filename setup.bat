@echo off
setlocal EnableExtensions
title VBGRAMG DSC Setup - Vision Technologies and Robotics

:: ---------------------------------------------------------------------------
:: Auto-elevate to administrator (robust against spaces in the path)
:: ---------------------------------------------------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo   Requesting administrator privileges...
    echo   Please click "Yes" on the Windows security prompt.
    echo.
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"

:: ---------------------------------------------------------------------------
:: If companion files are already next to this bat (repo clone / ZIP), use them.
:: Otherwise download everything from GitHub into a temp folder.
:: ---------------------------------------------------------------------------
if exist "%~dp0setup.ps1" (
    set "WORKDIR=%~dp0"
    goto run_setup
)

set "WORKDIR=%TEMP%\vbgramg-dsc-setup"
if not exist "%WORKDIR%" mkdir "%WORKDIR%"

echo.
echo   Downloading setup files from GitHub...
echo.

> "%WORKDIR%\_dl.ps1" (
    echo $ErrorActionPreference = 'Stop'
    echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    echo $b = 'https://raw.githubusercontent.com/visiontech-com-ai/vbgramg-dsc-setup/master'
    echo $d = Join-Path $env:TEMP 'vbgramg-dsc-setup'
    echo foreach ^($f in @^('setup.ps1','mozilla.cfg','local-settings.js','firefox-install.ini','exception.sites'^)^) {
    echo     Write-Host ^('    downloading ' + $f^)
    echo     Invoke-WebRequest ^("$b/$f"^) -OutFile ^(Join-Path $d $f^) -UseBasicParsing
    echo }
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%WORKDIR%\_dl.ps1"

if %errorlevel% neq 0 (
    echo.
    echo   ============================================================
    echo   ERROR: Could not download the setup files.
    echo   Please check your internet connection and try again.
    echo   ============================================================
    echo.
    pause
    exit /b 1
)

echo.

:run_setup
powershell -NoProfile -ExecutionPolicy Bypass -File "%WORKDIR%\setup.ps1"

echo.
echo   ============================================================
echo   Setup has finished. Review the results above.
echo   You can now close this window.
echo   ============================================================
echo.
pause >nul
