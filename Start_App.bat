@echo off
REM ============================================================================
REM xsukax WIFI Password Recover - Launcher
REM Author: xsukax
REM Description: Batch launcher for WiFi Password Recovery PowerShell GUI
REM Version: 2.0.1
REM ============================================================================

title xsukax WIFI Password Recover - Launcher v2.0.1
color 0B

REM Set log file path
set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%SCRIPT_DIR%xsukax_WIFI_Recover_Log.txt"

REM Initialize log file
echo ================================================================================ > "%LOG_FILE%"
echo xsukax WIFI Password Recover - Launcher Log >> "%LOG_FILE%"
echo ================================================================================ >> "%LOG_FILE%"
echo Launcher Version: 2.0.1 >> "%LOG_FILE%"
echo Timestamp: %DATE% %TIME% >> "%LOG_FILE%"
echo Script Directory: %SCRIPT_DIR% >> "%LOG_FILE%"
echo Computer Name: %COMPUTERNAME% >> "%LOG_FILE%"
echo User: %USERNAME% >> "%LOG_FILE%"
echo OS: %OS% >> "%LOG_FILE%"
echo. >> "%LOG_FILE%"

echo.
echo ================================================================================
echo  xsukax WIFI Password Recover - Launcher v2.0.1
echo  Author: xsukax
echo ================================================================================
echo.
echo [INFO] Log file: %LOG_FILE%
echo.

REM Check if running as Administrator
echo [CHECK] Verifying Administrator privileges... >> "%LOG_FILE%"
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Not running as Administrator >> "%LOG_FILE%"
    echo.
    echo [ERROR] This application requires Administrator privileges!
    echo.
    echo Please follow these steps:
    echo   1. Right-click on this batch file
    echo   2. Select "Run as Administrator"
    echo   3. Click "Yes" on the UAC prompt
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

echo [SUCCESS] Administrator privileges confirmed >> "%LOG_FILE%"
echo [INFO] Running with Administrator privileges
echo.

REM Verify PowerShell is available
echo [CHECK] Verifying PowerShell installation... >> "%LOG_FILE%"
where powershell >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] PowerShell not found in PATH >> "%LOG_FILE%"
    echo [ERROR] PowerShell is not installed or not accessible
    echo.
    echo Please ensure PowerShell is installed on your system.
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

echo [SUCCESS] PowerShell detected >> "%LOG_FILE%"
echo [INFO] PowerShell detected
echo.

REM Get PowerShell version
for /f "tokens=*" %%i in ('powershell -Command "$PSVersionTable.PSVersion.Major" 2^>nul') do set PS_VERSION=%%i
if not defined PS_VERSION set PS_VERSION=Unknown

echo [INFO] PowerShell Version: %PS_VERSION% >> "%LOG_FILE%"
echo [INFO] PowerShell Version: %PS_VERSION%
echo.

REM Minimum version check
if %PS_VERSION% LSS 5 (
    echo [WARNING] PowerShell version %PS_VERSION% detected. Version 5 or higher recommended. >> "%LOG_FILE%"
    echo [WARNING] PowerShell version %PS_VERSION% detected
    echo [WARNING] Version 5 or higher is recommended
    echo.
)

REM Set the script path
set "PS_SCRIPT=%SCRIPT_DIR%xsukax_WIFI_Password_Recover.ps1"
echo [INFO] Expected PowerShell script: %PS_SCRIPT% >> "%LOG_FILE%"

REM Check if PowerShell script exists
if not exist "%PS_SCRIPT%" (
    echo [ERROR] PowerShell script not found: %PS_SCRIPT% >> "%LOG_FILE%"
    echo.
    echo [ERROR] PowerShell script not found!
    echo.
    echo Expected location: %PS_SCRIPT%
    echo.
    echo Please ensure the following file exists in the same directory:
    echo   - xsukax_WIFI_Password_Recover.ps1
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

echo [SUCCESS] PowerShell script found >> "%LOG_FILE%"
echo [INFO] PowerShell script located
echo.
echo [INFO] Launching xsukax WIFI Password Recover...
echo.
echo ================================================================================
echo.

REM Launch PowerShell script
echo [INFO] Executing PowerShell script... >> "%LOG_FILE%"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" 2>> "%LOG_FILE%"

set EXIT_CODE=%errorLevel%
echo. >> "%LOG_FILE%"
echo [INFO] PowerShell exit code: %EXIT_CODE% >> "%LOG_FILE%"

if %EXIT_CODE% neq 0 (
    echo [ERROR] Application exited with error code: %EXIT_CODE% >> "%LOG_FILE%"
    echo.
    echo ================================================================================
    echo [ERROR] Application exited with error code: %EXIT_CODE%
    echo ================================================================================
    echo.
    echo Please check the log file for details: %LOG_FILE%
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b %EXIT_CODE%
)

echo [SUCCESS] Application closed normally >> "%LOG_FILE%"
echo ================================================================================ >> "%LOG_FILE%"
echo.
echo ================================================================================
echo [SUCCESS] Application closed successfully
echo ================================================================================
echo.
timeout /t 2 /nobreak >nul
exit /b 0