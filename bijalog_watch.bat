@echo off
cd /d "%~dp0"
if "%BIJALOG_ROOT%"=="" set "BIJALOG_ROOT=%~dp0projects"
for %%I in ("%BIJALOG_ROOT%\..") do set "BIJALOG_HOME=%%~fI"
call "%~dp0bijalog.bat" --root "%BIJALOG_ROOT%" watch --inbox "%BIJALOG_HOME%\inbox"
