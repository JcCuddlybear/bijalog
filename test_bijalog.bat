@echo off
setlocal enabledelayedexpansion
title Bijalog self-test
rem ============================================================
rem  test_bijalog.bat - clean-install self-test.
rem  Follows README.md's documented commands ONLY, in a scratch
rem  folder. Touches nothing outside it: no setx, no BIJALOG_ROOT
rem  change, your real decks are never opened.
rem  Result: PASS/FAIL per step and a one-line verdict.
rem ============================================================

set PASS=0
set FAIL=0
set "SCRATCH=%TEMP%\bijalog_selftest_%RANDOM%"
set "ROOT=%SCRATCH%\projects"
set "BIJALOG_APPROVER=selftest"

echo Scratch folder: %SCRATCH%
mkdir "%ROOT%" 2>nul
mkdir "%SCRATCH%\inbox" 2>nul

echo.
echo [1] launcher finds Python (bijalog.bat with no args should print usage, not "No Python")
call "%~dp0bijalog.bat" --root "%ROOT%" 2>&1 | findstr /C:"No Python found" >nul
if errorlevel 1 (echo   PASS & set /a PASS+=1) else (echo   FAIL - Python not found via launcher & set /a FAIL+=1 & goto :report)

echo [2] add PROPOSED
call "%~dp0bijalog.bat" --root "%ROOT%" add my-story "The main character is called Alex." --topic characters >"%SCRATCH%\o2.txt" 2>&1
findstr /C:"[PROPOSED]" "%SCRATCH%\o2.txt" >nul && (echo   PASS & set /a PASS+=1) || (echo   FAIL & set /a FAIL+=1 & type "%SCRATCH%\o2.txt")

echo [3] add ACTIVE via --approved, approver stamped from environment
call "%~dp0bijalog.bat" --root "%ROOT%" add my-story "Alex lives in Hastings." --topic setting --approved >"%SCRATCH%\o3.txt" 2>&1
findstr /C:"approved-by:selftest" "%SCRATCH%\o3.txt" >nul && (echo   PASS & set /a PASS+=1) || (echo   FAIL & set /a FAIL+=1 & type "%SCRATCH%\o3.txt")

echo [4] versioned keep-all: v001 and v002 both on disk, neither overwritten
if exist "%ROOT%\my-story\log\my-story_v001.txt" if exist "%ROOT%\my-story\log\my-story_v002.txt" (echo   PASS & set /a PASS+=1) else (echo   FAIL & set /a FAIL+=1)

echo [5] approve the PROPOSED line by id
for /f "tokens=2 delims=|" %%A in ('findstr /C:"PROPOSED" "%ROOT%\my-story\log\my-story_v002.txt"') do set "PID=%%A"
set "PID=%PID: =%"
call "%~dp0bijalog.bat" --root "%ROOT%" approve my-story %PID% >"%SCRATCH%\o5.txt" 2>&1
findstr /C:"approved" "%SCRATCH%\o5.txt" >nul && (echo   PASS & set /a PASS+=1) || (echo   FAIL & set /a FAIL+=1 & type "%SCRATCH%\o5.txt")

echo [6] verify reports OK
call "%~dp0bijalog.bat" --root "%ROOT%" verify >"%SCRATCH%\o6.txt" 2>&1
findstr /B /C:"OK:" "%SCRATCH%\o6.txt" >nul && (echo   PASS & set /a PASS+=1) || (echo   FAIL & set /a FAIL+=1 & type "%SCRATCH%\o6.txt")

echo [7] state shows both topics as current truth
call "%~dp0bijalog.bat" --root "%ROOT%" state my-story >"%SCRATCH%\o7.txt" 2>&1
findstr /C:"[characters]" "%SCRATCH%\o7.txt" >nul && findstr /C:"[setting]" "%SCRATCH%\o7.txt" >nul && (echo   PASS & set /a PASS+=1) || (echo   FAIL & set /a FAIL+=1 & type "%SCRATCH%\o7.txt")

echo [8] the approved line superseded its PROPOSED original (supersedes: present in v003)
findstr /C:"supersedes:%PID%" "%ROOT%\my-story\log\my-story_v003.txt" >nul && (echo   PASS & set /a PASS+=1) || (echo   FAIL & set /a FAIL+=1)

:report
echo.
echo ============================================================
if %FAIL%==0 (echo  VERDICT: ALL %PASS% CHECKS PASS) else (echo  VERDICT: %FAIL% FAILED, %PASS% passed)
echo  Evidence kept in %SCRATCH%  (delete it when done)
echo ============================================================
echo.
pause
