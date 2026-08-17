@echo off
setlocal EnableExtensions
title VBGRAMG DSC - Open Portal in Firefox 43

:: ---------------------------------------------------------------------------
:: Launches Firefox 43 in a dedicated profile, with MOZ_PLUGIN_PATH pointed at
:: the Oracle Java plugin folder. This forces Firefox to load the Java applet
:: plugin directly, bypassing registry-based detection.
:: ---------------------------------------------------------------------------

set "FF=C:\Program Files (x86)\Mozilla Firefox\firefox.exe"
if not exist "%FF%" (
    echo Firefox 43 not found at "%FF%".
    echo Please run setup.bat first.
    pause
    exit /b 1
)

:: Auto-detect the Oracle Java 32-bit plugin folder (version varies)
set "PLUGDIR="
for /d %%D in ("C:\Program Files (x86)\Java\jre*") do (
    if exist "%%D\bin\plugin2\npjp2.dll" set "PLUGDIR=%%D\bin\plugin2"
)

if not defined PLUGDIR (
    echo Could not find the Oracle Java plugin ^(npjp2.dll^).
    echo Please run setup.bat to install Oracle Java 8 first.
    pause
    exit /b 1
)

echo Java plugin folder: %PLUGDIR%
set "MOZ_PLUGIN_PATH=%PLUGDIR%"

echo Launching Firefox 43 for the digital signature portal...
start "" "%FF%" -no-remote -profile "%LOCALAPPDATA%\VBGRAMG-DSC-FF43"

echo.
echo Firefox 43 is opening. In it:
echo   1. Type  about:addons  then click Plugins - Java should now appear.
echo   2. Set "Java(TM) Platform SE 8" to "Always Activate".
echo   3. Open your NREGA/VBGRAMG portal.
echo.
echo (You can close this window.)
timeout /t 8 >nul
