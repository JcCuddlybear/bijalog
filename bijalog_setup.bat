@echo off
setlocal enabledelayedexpansion
title Bijalog Setup

rem Try the setup window first. If PowerShell is blocked by policy, or the
rem window cannot open for any reason, fall through to the text-mode setup
rem below so nobody is left stuck. The window writes a flag file the moment
rem it appears; that flag is how we know it actually ran.

del "%TEMP%\bijalog_gui.flag" >nul 2>&1
where powershell >nul 2>&1
if not errorlevel 1 (
    echo Opening the setup window...
    powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0bijalog_setup.ps1" >nul 2>&1
    if exist "%TEMP%\bijalog_gui.flag" (
        del "%TEMP%\bijalog_gui.flag" >nul 2>&1
        exit /b 0
    )
    echo The setup window could not open. Carrying on in this window instead.
    echo.
)

echo ==============================================
echo  Bijalog Setup
echo ==============================================
echo.

rem --- Check Python is installed and reachable ---
where python >nul 2>nul
if errorlevel 1 (
    echo Python was not found on this computer.
    echo.
    echo Bijalog needs Python 3 to run. This will open the
    echo official download page - download and run the installer,
    echo then IMPORTANT: tick "Add python.exe to PATH" during
    echo setup, or this script will not find it afterward.
    echo.
    pause
    start https://www.python.org/downloads/
    echo.
    echo Once Python is installed, close this window and run
    echo bijalog_setup.bat again.
    echo.
    pause
    exit /b 1
)

echo Python found:
python --version
echo.

echo A folder picker will open next. Choose an existing
echo folder, or use the "Make New Folder" button in the
echo dialog to create one, for where Bijalog should keep
echo its projects and inbox.
echo.
pause

for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description = 'Choose or create a folder for Bijalog'; $f.ShowNewFolderButton = $true; if ($f.ShowDialog() -eq 'OK') { Write-Output $f.SelectedPath }"`) do set "BIJALOG_DIR=%%I"

if "%BIJALOG_DIR%"=="" (
    echo.
    echo No folder was selected. Setup cancelled.
    echo.
    pause
    exit /b 1
)

echo.
echo Selected folder: %BIJALOG_DIR%
echo.

if not exist "%BIJALOG_DIR%\projects" (
    mkdir "%BIJALOG_DIR%\projects"
    echo Created: %BIJALOG_DIR%\projects
) else (
    echo Already exists: %BIJALOG_DIR%\projects
)

if not exist "%BIJALOG_DIR%\inbox" (
    mkdir "%BIJALOG_DIR%\inbox"
    echo Created: %BIJALOG_DIR%\inbox
) else (
    echo Already exists: %BIJALOG_DIR%\inbox
)

setx BIJALOG_ROOT "%BIJALOG_DIR%\projects" >nul

echo.
echo BIJALOG_ROOT has been set to:
echo    %BIJALOG_DIR%\projects
echo.

rem --- Approver name: goes on every decision you approve ---
echo Last thing: what name should go on the decisions you
echo approve? Press Enter to use %USERNAME%.
echo.
set "BIJALOG_NAME="
set /p "BIJALOG_NAME=Your name: "
if "%BIJALOG_NAME%"=="" set "BIJALOG_NAME=%USERNAME%"
setx BIJALOG_APPROVER "%BIJALOG_NAME%" >nul
echo.
echo Your approvals will be stamped: %BIJALOG_NAME%
echo.
echo Both settings are permanent for your Windows user account,
echo so Bijalog will find the right folder automatically from any
echo new Command Prompt window from now on (windows that are
echo already open won't see them until reopened).
echo.
echo ==============================================
echo  Setup complete.
echo  Run test_bijalog.bat to check it all works.
echo ==============================================
echo.
pause
