@echo off
setlocal enabledelayedexpansion
title Bijalog Setup

echo ============================================
echo  Bijalog Setup
echo ============================================
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
echo   %BIJALOG_DIR%\projects
echo.
echo This is a permanent setting for your Windows user account,
echo so bijalog.bat will find the right folder automatically from
echo any new Command Prompt window from now on (existing open
echo windows won't see it until reopened).
echo.
echo ============================================
echo  Setup complete.
echo  Run bijalog.bat from this folder to get started.
echo ============================================
echo.
pause
