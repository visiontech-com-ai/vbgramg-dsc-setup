@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1
title VBGRAMG DSC Setup - Vision Technologies and Robotics

:: Auto-elevate to administrator
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c cd /d \"%~dp0\" ^& \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

:: If companion files exist locally (repo clone / ZIP extract), use them
if exist "%~dp0setup.ps1" (
    set "WORKDIR=%~dp0"
    goto :run_setup
)

:: Otherwise download all files from GitHub
set "WORKDIR=%TEMP%\vbgramg-dsc-setup"
if not exist "%WORKDIR%" mkdir "%WORKDIR%"

echo.
echo   Downloading setup files from GitHub...
echo.

> "%WORKDIR%\_dl.ps1" (
    echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    echo $b = 'https://raw.githubusercontent.com/visiontech-com-ai/vbgramg-dsc-setup/master'
    echo $d = Join-Path $env:TEMP 'vbgramg-dsc-setup'
    echo foreach ^($f in @^('setup.ps1','mozilla.cfg','local-settings.js','firefox-install.ini','exception.sites'^)^) {
    echo     Write-Host ^('    ' + $f^)
    echo     Invoke-WebRequest ^("$b/$f"^) -OutFile ^(Join-Path $d $f^) -UseBasicParsing
    echo }
)

powershell -ExecutionPolicy Bypass -NoProfile -File "%WORKDIR%\_dl.ps1"

if %errorlevel% neq 0 (
    echo.
    echo   ERROR: Download failed. Check your internet connection.
    pause
    exit /b 1
)

echo.

:run_setup
powershell -ExecutionPolicy Bypass -NoProfile -File "%WORKDIR%\setup.ps1"
echo.
echo Press any key to exit...
pause >nul
