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
echo NEXT IN METATRADER 5 ^(scripts cannot do this for you^):
echo   1. Algo Trading ON ^(toolbar green^)
echo   2. Start Services: GsignalX_Service
echo   3. Start Services: ProfitScouter_Service  ^(InpBusEnable=true^)
echo   4. Start Services: ProfitOpportunity_Grader
echo   5. Attach Expert: GsignalX_Multisymbol_Dashboard ^(same magic^)
echo   6. Optional: attach GsignalX_GocityGroup on M5 for chart strip
echo   7. Double-click deploy\Confirm-After-Start.bat
echo.
echo Stuck? Open docs\WINDOWS_DEPLOY_SIMPLE.md  ^(Problems and fixes^)
echo Docs: DEPLOYMENT.md / DEPLOYMENT_RUNBOOK.md
echo.
pause
exit /b %CONFIRM_EXIT%

:fail
echo.
echo DEPLOY FAILED. See messages above.
echo.
echo Common fixes:
echo   - Open MetaTrader 5 once, then re-run this .bat
echo   - If MetaEditor not found: edit this .bat and set METAEDITOR=...
echo   - Full guide: docs\WINDOWS_DEPLOY_SIMPLE.md
echo.
pause
exit /b 1
