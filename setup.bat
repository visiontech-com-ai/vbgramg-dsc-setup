@echo off
chcp 65001 >nul 2>&1
title VBGRAMG DSC Setup - Vision Technologies and Robotics
cd /d "%~dp0"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd.exe -ArgumentList '/c cd /d \"%~dp0\" ^& \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup.ps1"
echo.
echo Press any key to exit...
pause >nul
