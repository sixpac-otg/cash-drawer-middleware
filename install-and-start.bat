@echo off
SETLOCAL ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

set TASK_NAME=PM2 Resurrection
set TASK_COMMAND=pm2 resurrect
set NODE_INSTALLER_NAME=node-lts.msi
set NODE_DOWNLOAD_URL=https://nodejs.org/dist/latest-v22.x/node-v22.15.0-x64.msi

echo.
echo ==============================
echo Starting Cash Drawer Setup...
echo ==============================
echo.

echo === Checking for Node.js and npm ===
where npm >nul 2>nul
IF ERRORLEVEL 1 (
    echo Node.js and npm are NOT installed.
    echo Attempting to install Node.js...

    REM Look for local installer
    set FOUND_INSTALLER=false
    for %%f in ("%~dp0node-v*.msi" "%~dp0node-v*.exe") do (
        if exist "%%~f" (
            set FOUND_INSTALLER=true
            set NODE_INSTALLER_PATH=%%~f
            goto :RunInstaller
        )
    )

    if "%FOUND_INSTALLER%"=="false" (
        echo No local Node.js installer found. Attempting to download...

        REM Try downloading Node.js installer
        if exist "%NODE_INSTALLER_NAME%" (
            echo Using previously downloaded installer: %NODE_INSTALLER_NAME%
            set NODE_INSTALLER_PATH=%~dp0%NODE_INSTALLER_NAME%
        ) else (
            REM Use bitsadmin or curl if available
            where bitsadmin >nul 2>nul
            if not errorlevel 1 (
                echo Downloading using bitsadmin...
                bitsadmin /transfer "NodeInstallJob" "%NODE_DOWNLOAD_URL%" "%~dp0%NODE_INSTALLER_NAME%"
            ) else (
                where curl >nul 2>nul
                if not errorlevel 1 (
                    echo Downloading using curl...
                    curl -L "%NODE_DOWNLOAD_URL%" -o "%~dp0%NODE_INSTALLER_NAME%"
                ) else (
                    echo ERROR: Neither bitsadmin nor curl is available to download Node.js.
                    echo Please manually download from: https://nodejs.org/
                    pause
                    exit /b 1
                )
            )

            if exist "%~dp0%NODE_INSTALLER_NAME%" (
                set NODE_INSTALLER_PATH=%~dp0%NODE_INSTALLER_NAME%
            ) else (
                echo ERROR: Failed to download Node.js installer.
                pause
                exit /b 1
            )
        )
    )

    :RunInstaller
    echo Running Node.js installer: %NODE_INSTALLER_PATH%
    start /wait msiexec /i "%NODE_INSTALLER_PATH%" /qb
    if %ERRORLEVEL% NEQ 0 (
        echo ERROR: Node.js installer failed with exit code %ERRORLEVEL%.
        pause
        exit /b 1
    )

    echo Node.js installer finished. Verifying installation...
    where npm >nul 2>nul
    if errorlevel 1 (
        echo ERROR: Node.js installation failed. 'npm' still not found.
        pause
        exit /b 1
    ) else (
        echo Node.js installed successfully!
    )
)

echo === Node.js environment is ready. Continuing...
echo.

cd /d "%~dp0"

echo === Installing Node.js project dependencies (npm install)...
call npm install > npm-install-log.txt 2>&1
echo npm install completed with code %ERRORLEVEL%.
type npm-install-log.txt

echo === Installing pm2 globally (npm install -g pm2)...
call npm install -g pm2 > pm2-install-log.txt 2>&1
echo pm2 global install completed with code %ERRORLEVEL%.
type pm2-install-log.txt

echo === Checking if 'cash-drawer' is already running in PM2...
for /f "tokens=*" %%i in ('pm2 jlist') do (
    echo %%i | findstr /i "\"name\":\"cash-drawer\"" >nul
    if not errorlevel 1 (
        echo 'cash-drawer' process found. Restarting...
        call pm2 restart cash-drawer
        goto :AfterStart
    )
)

echo No existing 'cash-drawer' process found. Starting new one...
call pm2 start server.js --name cash-drawer -f

:AfterStart
call pm2 save

echo === Checking if Scheduled Task for PM2 exists...
schtasks /Query /TN "%TASK_NAME%" >nul 2>&1
if %ERRORLEVEL%==0 (
    echo Scheduled Task '%TASK_NAME%' already exists.
) else (
    echo Creating Scheduled Task '%TASK_NAME%'...
    schtasks /Create /SC ONLOGON /RL HIGHEST /TN "%TASK_NAME%" /TR "cmd /c pm2 resurrect" /F
)

echo.
echo ==============================
echo Setup Complete!
echo PM2 process saved and resurrection task created.
echo You can view PM2 logs with: pm2 logs cash-drawer
echo ==============================
pause
exit /b 0
