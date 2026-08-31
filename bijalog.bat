@echo off
setlocal
cd /d "%~dp0"
set "SCRIPT=%~dp0bijalog.py"
where python >nul 2>&1 && (python "%SCRIPT%" %* & exit /b %errorlevel%)
where py >nul 2>&1 && (py "%SCRIPT%" %* & exit /b %errorlevel%)
set "BLPY=C:\Program Files\Blender Foundation\Blender 5.0\5.0\python\bin\python.exe"
if exist "%BLPY%" ("%BLPY%" "%SCRIPT%" %* & exit /b %errorlevel%)
echo No Python found. Install from python.org and tick "Add to PATH".
exit /b 1
