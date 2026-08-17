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

:: Robust downloader (base64-encoded PowerShell): retries each file and falls
:: back to the jsDelivr mirror if raw.githubusercontent.com is busy (503).
powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQA9ACcAUwB0AG8AcAAnAAoAWwBOAGUAdAAuAFMAZQByAHYAaQBjAGUAUABvAGkAbgB0AE0AYQBuAGEAZwBlAHIAXQA6ADoAUwBlAGMAdQByAGkAdAB5AFAAcgBvAHQAbwBjAG8AbAA9AFsATgBlAHQALgBTAGUAYwB1AHIAaQB0AHkAUAByAG8AdABvAGMAbwBsAFQAeQBwAGUAXQA6ADoAVABsAHMAMQAyAAoAJABkAD0ASgBvAGkAbgAtAFAAYQB0AGgAIAAkAGUAbgB2ADoAVABFAE0AUAAgACcAdgBiAGcAcgBhAG0AZwAtAGQAcwBjAC0AcwBlAHQAdQBwACcACgBpAGYAKAAtAG4AbwB0ACgAVABlAHMAdAAtAFAAYQB0AGgAIAAkAGQAKQApAHsATgBlAHcALQBJAHQAZQBtACAALQBJAHQAZQBtAFQAeQBwAGUAIABEAGkAcgBlAGMAdABvAHIAeQAgAC0AUABhAHQAaAAgACQAZAAgAC0ARgBvAHIAYwBlAHwATwB1AHQALQBOAHUAbABsAH0ACgAkAG0AaQByAHIAbwByAHMAPQBAACgAJwBoAHQAdABwAHMAOgAvAC8AZwBpAHQAaAB1AGIALgBjAG8AbQAvAHYAaQBzAGkAbwBuAHQAZQBjAGgALQBjAG8AbQAtAGEAaQAvAHYAYgBnAHIAYQBtAGcALQBkAHMAYwAtAHMAZQB0AHUAcAAvAHIAZQBsAGUAYQBzAGUAcwAvAGwAYQB0AGUAcwB0AC8AZABvAHcAbgBsAG8AYQBkACcALAAnAGgAdAB0AHAAcwA6AC8ALwByAGEAdwAuAGcAaQB0AGgAdQBiAHUAcwBlAHIAYwBvAG4AdABlAG4AdAAuAGMAbwBtAC8AdgBpAHMAaQBvAG4AdABlAGMAaAAtAGMAbwBtAC0AYQBpAC8AdgBiAGcAcgBhAG0AZwAtAGQAcwBjAC0AcwBlAHQAdQBwAC8AbQBhAHMAdABlAHIAJwAsACcAaAB0AHQAcABzADoALwAvAGMAZABuAC4AagBzAGQAZQBsAGkAdgByAC4AbgBlAHQALwBnAGgALwB2AGkAcwBpAG8AbgB0AGUAYwBoAC0AYwBvAG0ALQBhAGkALwB2AGIAZwByAGEAbQBnAC0AZABzAGMALQBzAGUAdAB1AHAAQABtAGEAcwB0AGUAcgAnACkACgAkAGYAaQBsAGUAcwA9AEAAKAAnAHMAZQB0AHUAcAAuAHAAcwAxACcALAAnAG0AbwB6AGkAbABsAGEALgBjAGYAZwAnACwAJwBsAG8AYwBhAGwALQBzAGUAdAB0AGkAbgBnAHMALgBqAHMAJwAsACcAZgBpAHIAZQBmAG8AeAAtAGkAbgBzAHQAYQBsAGwALgBpAG4AaQAnACwAJwBlAHgAYwBlAHAAdABpAG8AbgAuAHMAaQB0AGUAcwAnACkACgBmAG8AcgBlAGEAYwBoACgAJABmACAAaQBuACAAJABmAGkAbABlAHMAKQB7AAoAIAAgACQAbwBrAD0AJABmAGEAbABzAGUACgAgACAAZgBvAHIAZQBhAGMAaAAoACQAbQAgAGkAbgAgACQAbQBpAHIAcgBvAHIAcwApAHsACgAgACAAIAAgAGYAbwByACgAJABpAD0AMQA7ACQAaQAgAC0AbABlACAAMgAgAC0AYQBuAGQAIAAtAG4AbwB0ACAAJABvAGsAOwAkAGkAKwArACkAewAKACAAIAAgACAAIAAgAHQAcgB5AHsACgAgACAAIAAgACAAIAAgACAAVwByAGkAdABlAC0ASABvAHMAdAAgACgAJwAgACAAIAAgAGQAbwB3AG4AbABvAGEAZABpAG4AZwAgACcAKwAkAGYAKQAKACAAIAAgACAAIAAgACAAIABJAG4AdgBvAGsAZQAtAFcAZQBiAFIAZQBxAHUAZQBzAHQAIAAoACIAJABtAC8AJABmACIAKQAgAC0ATwB1AHQARgBpAGwAZQAgACgASgBvAGkAbgAtAFAAYQB0AGgAIAAkAGQAIAAkAGYAKQAgAC0AVQBzAGUAQgBhAHMAaQBjAFAAYQByAHMAaQBuAGcAIAAtAFQAaQBtAGUAbwB1AHQAUwBlAGMAIAAzADAACgAgACAAIAAgACAAIAAgACAAJABvAGsAPQAkAHQAcgB1AGUACgAgACAAIAAgACAAIAB9AGMAYQB0AGMAaAB7AAoAIAAgACAAIAAgACAAIAAgAFcAcgBpAHQAZQAtAEgAbwBzAHQAIAAoACcAIAAgACAAIABzAGUAcgB2AGUAcgAgAGIAdQBzAHkALAAgAHQAcgB5AGkAbgBnACAAYQBuAG8AdABoAGUAcgAgAHMAbwB1AHIAYwBlACAAZgBvAHIAIAAnACsAJABmACsAJwAgAC4ALgAuACcAKQAKACAAIAAgACAAIAAgACAAIABTAHQAYQByAHQALQBTAGwAZQBlAHAAIAAtAFMAZQBjAG8AbgBkAHMAIAAyAAoAIAAgACAAIAAgACAAfQAKACAAIAAgACAAfQAKACAAIAAgACAAaQBmACgAJABvAGsAKQB7AGIAcgBlAGEAawB9AAoAIAAgAH0ACgAgACAAaQBmACgALQBuAG8AdAAgACQAbwBrACkAewBXAHIAaQB0AGUALQBIAG8AcwB0ACAAKAAnACAAIAAgACAARgBBAEkATABFAEQAOgAgACcAKwAkAGYAKQA7AGUAeABpAHQAIAAxAH0ACgB9AAoAZQB4AGkAdAAgADAA

if %errorlevel% neq 0 (
    echo.
    echo   ============================================================
    echo   ERROR: Could not download the setup files.
    echo   GitHub may be busy - please wait a minute and run again.
    echo   ============================================================
    echo.
    pause
    exit /b 1
)

echo.

:: If a bundled Oracle JRE installer sits next to this bat (to pin a specific
:: Java version, e.g. jre-8u231-windows-i586.exe), copy it into the work folder
:: so setup.ps1 installs that exact version instead of downloading the latest.
for %%J in ("%~dp0jre-8u*-windows-i586.exe") do (
    if exist "%%J" if /I not "%~dp0"=="%WORKDIR%\" copy /y "%%J" "%WORKDIR%\" >nul
)

:run_setup
powershell -NoProfile -ExecutionPolicy Bypass -File "%WORKDIR%\setup.ps1"

echo.
echo   ============================================================
echo   Setup has finished. Review the results above.
echo   You can now close this window.
echo   ============================================================
echo.
pause >nul
