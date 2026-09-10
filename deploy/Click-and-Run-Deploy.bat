@echo off
setlocal EnableExtensions
title GSignalX - Click and Run Deploy
cd /d "%~dp0.."

echo ============================================================
echo  GSignalX MQL5 Toolkit - Click and Run Deploy
echo  Repo: %CD%
echo ============================================================
echo.

REM Optional: set a fixed MetaEditor path if auto-detect fails
REM set METAEDITOR=C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe

if not exist "deploy\Deploy-GSignalX.ps1" (
  echo ERROR: deploy\Deploy-GSignalX.ps1 not found.
  echo Run this .bat from the toolkit deploy folder ^(or keep it next to Deploy-GSignalX.ps1^).
  goto :fail
)

echo [1/4] Listing MT5 terminal data folders...
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Deploy-GSignalX.ps1" -ListTerminals
if errorlevel 1 goto :fail
echo.

echo [2/4] Deploying sources to ALL terminals on this PC...
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Deploy-GSignalX.ps1" -AllTerminals
if errorlevel 1 goto :fail
echo.

echo [3/4] Compiling with MetaEditor ^(all terminals^)...
if defined METAEDITOR (
  powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Deploy-GSignalX.ps1" -AllTerminals -Compile -MetaEditorPath "%METAEDITOR%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Deploy-GSignalX.ps1" -AllTerminals -Compile
)
if errorlevel 1 goto :fail
echo.

echo [4/4] Confirming Files + Compile + Bus + Grades ^(writes feedback^)...
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Confirm-GSignalX.ps1" -Gate All -WriteFeedback
set CONFIRM_EXIT=%ERRORLEVEL%
echo.

if %CONFIRM_EXIT% NEQ 0 (
  echo ------------------------------------------------------------
  echo  CONFIRM reported FAIL. Open deploy\feedback\CONFIRM_*.md
  echo  Bus/Grades may fail until Services are started in MT5.
  echo  Files/Compile should still be OK - check SUMMARY above.
  echo ------------------------------------------------------------
) else (
  echo ------------------------------------------------------------
  echo  CONFIRM SUMMARY: PASS
  echo ------------------------------------------------------------
)

echo.
echo NEXT IN MT5 ^(manual - Algo Trading cannot be started from .bat^):
echo   1. Enable Algo Trading ^(toolbar green^)
echo   2. Start Service: ProfitScouter_Service  ^(InpBusEnable=true^)
echo   3. Start Service: ProfitOpportunity_Grader
echo   4. Attach Expert: GsignalX_GocityGroup  ^(InpBusEnable=true^)
echo   5. Double-click deploy\Confirm-After-Start.bat to re-check Bus/Grades
echo.
echo Docs: DEPLOYMENT_RUNBOOK.md
echo.
pause
exit /b %CONFIRM_EXIT%

:fail
echo.
echo DEPLOY FAILED. See messages above.
pause
exit /b 1
