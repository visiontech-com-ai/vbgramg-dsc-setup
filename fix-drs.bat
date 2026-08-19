@echo off
setlocal EnableExtensions
title VBGRAMG DSC - Fix Java Rule Set Trust (Vision Technologies)

:: Auto-elevate
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo.
echo   Fixing the Java Deployment Rule Set trust...
echo.

:: Get the rule set jar + its certificate (use local copies if present, else download)
set "SRC=%~dp0"
set "CERT=%TEMP%\VBGRAMG-DRS.cer"
set "JAR=%TEMP%\DeploymentRuleSet.jar"

if exist "%SRC%VBGRAMG-DRS.cer" (
    copy /y "%SRC%VBGRAMG-DRS.cer" "%CERT%" >nul
    copy /y "%SRC%DeploymentRuleSet.jar" "%JAR%" >nul
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $b='https://github.com/visiontech-com-ai/vbgramg-dsc-setup/releases/latest/download'; Invoke-WebRequest \"$b/VBGRAMG-DRS.cer\" -OutFile '%CERT%' -UseBasicParsing; Invoke-WebRequest \"$b/DeploymentRuleSet.jar\" -OutFile '%JAR%' -UseBasicParsing"
)

if not exist "%CERT%" (
    echo   ERROR: could not obtain the certificate. Check your internet connection.
    pause
    exit /b 1
)

:: Deploy the rule set jar to the system location
if not exist "C:\Windows\Sun\Java\Deployment" mkdir "C:\Windows\Sun\Java\Deployment"
copy /y "%JAR%" "C:\Windows\Sun\Java\Deployment\DeploymentRuleSet.jar" >nul

:: Import the certificate into EVERY installed JRE/JDK trust store (cacerts)
set "FOUND=0"
for /d %%J in ("C:\Program Files (x86)\Java\jre*" "C:\Program Files (x86)\Java\jdk*" "C:\Program Files\Java\jre*" "C:\Program Files\Java\jdk*") do (
    if exist "%%J\bin\keytool.exe" if exist "%%J\lib\security\cacerts" (
        set "FOUND=1"
        "%%J\bin\keytool.exe" -delete -alias vbgramgdrs -storepass changeit -keystore "%%J\lib\security\cacerts" >nul 2>&1
        "%%J\bin\keytool.exe" -importcert -trustcacerts -noprompt -alias vbgramgdrs -storepass changeit -keystore "%%J\lib\security\cacerts" -file "%CERT%" >nul 2>&1
        echo   Trusted rule set in:  %%J
    )
)

echo.
if "%FOUND%"=="0" (
    echo   No Java installation found under C:\Program Files\Java.
) else (
    echo   ============================================================
    echo   Done. Now CLOSE Firefox completely and reopen it, then load
    echo   the portal again - the block should be gone.
    echo   ============================================================
)
echo.
pause
