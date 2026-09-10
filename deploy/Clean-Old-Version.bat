@echo off
setlocal EnableExtensions
title GSignalX - Clean Old Version
cd /d "%~dp0.."

echo ============================================================
echo  GSignalX - Clean Old Version ^(toolkit only^)
echo  Repo: %CD%
echo ============================================================
echo.
echo This removes previous GSignalX / ProfitScouter / Grader files
echo from ALL MT5 terminals on this PC, plus the Common Files bus.
echo Other EAs and account settings are NOT touched.
echo.
echo Tip: stop Services and remove GsignalX from charts first if
echo files are locked.
echo.
pause

if not exist "deploy\Clean-GSignalX.ps1" (
  echo ERROR: deploy\Clean-GSignalX.ps1 not found.
  goto :fail
)

echo [1/2] Listing terminals...
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Clean-GSignalX.ps1" -ListTerminals
echo.

echo [2/2] Cleaning all terminals + Common Files bus...
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Clean-GSignalX.ps1" -AllTerminals -CleanBus
if errorlevel 1 goto :fail

echo.
echo ------------------------------------------------------------
echo  CLEAN DONE
echo  Next: double-click Click-and-Run-Deploy.bat
echo  ^(or Clean-and-Deploy.bat for clean + deploy in one step^)
echo ------------------------------------------------------------
echo.
pause
exit /b 0

:fail
echo.
echo CLEAN FAILED. Stop MT5 Services/EA if files are locked, then retry.
pause
exit /b 1
