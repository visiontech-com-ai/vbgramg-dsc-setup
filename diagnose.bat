@echo off
setlocal EnableExtensions
title VBGRAMG DSC - Diagnostic (Vision Technologies and Robotics)

cd /d "%~dp0"

:: Use local diagnose.ps1 if present, else download it
if exist "%~dp0diagnose.ps1" (
    set "DIAG=%~dp0diagnose.ps1"
    goto run
)

set "WORKDIR=%TEMP%\vbgramg-dsc-setup"
if not exist "%WORKDIR%" mkdir "%WORKDIR%"
set "DIAG=%WORKDIR%\diagnose.ps1"

echo.
echo   Downloading diagnostic...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest 'https://raw.githubusercontent.com/visiontech-com-ai/vbgramg-dsc-setup/master/diagnose.ps1' -OutFile '%WORKDIR%\diagnose.ps1' -UseBasicParsing"

if %errorlevel% neq 0 (
    echo.
    echo   ERROR: Could not download the diagnostic. Check your internet connection.
    echo.
    pause
    exit /b 1
)

:run
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIAG%"
echo.
echo   ============================================================
echo   Diagnostic finished. A report was saved to your Desktop
echo   as vbgramg-diagnostic.txt - please send it back.
echo   ============================================================
echo.
pause >nul
