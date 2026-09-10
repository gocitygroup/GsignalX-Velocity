@echo off
setlocal EnableExtensions
title GSignalX - Clean and Deploy ^(Upgrade^)
cd /d "%~dp0.."

echo ============================================================
echo  GSignalX - Clean and Deploy ^(new version upgrade^)
echo  Repo: %CD%
echo ============================================================
echo.
echo Step A: remove old toolkit installs + stale bus
echo Step B: deploy + compile + confirm ^(same as Click-and-Run-Deploy^)
echo.
echo Recommended: stop ProfitScouter / Grader services and detach
echo GsignalX from charts before continuing.
echo.
pause

if not exist "deploy\Clean-GSignalX.ps1" (
  echo ERROR: deploy\Clean-GSignalX.ps1 not found.
  goto :fail
)
if not exist "deploy\Deploy-GSignalX.ps1" (
  echo ERROR: deploy\Deploy-GSignalX.ps1 not found.
  goto :fail
)

REM Optional: set a fixed MetaEditor path if auto-detect fails
REM set METAEDITOR=C:\Program Files\MetaTrader 5 IC Markets Global\MetaEditor64.exe

echo.
echo ========== A^) CLEAN ==========
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Clean-GSignalX.ps1" -ListTerminals
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Clean-GSignalX.ps1" -AllTerminals -CleanBus
if errorlevel 1 goto :fail
echo.

echo ========== B^) DEPLOY ==========
echo [1/3] Deploying sources to ALL terminals...
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Deploy-GSignalX.ps1" -AllTerminals
if errorlevel 1 goto :fail
echo.

echo [2/3] Compiling with MetaEditor ^(all terminals^)...
if defined METAEDITOR (
  powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Deploy-GSignalX.ps1" -AllTerminals -Compile -MetaEditorPath "%METAEDITOR%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Deploy-GSignalX.ps1" -AllTerminals -Compile
)
if errorlevel 1 goto :fail
echo.

echo [3/3] Confirming Files + Compile + Bus + Grades...
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Confirm-GSignalX.ps1" -Gate All -WriteFeedback
set CONFIRM_EXIT=%ERRORLEVEL%
echo.

if %CONFIRM_EXIT% NEQ 0 (
  echo ------------------------------------------------------------
  echo  CONFIRM reported FAIL ^(often Bus/Grades until Services start^)
  echo  Files/Compile should be OK - see SUMMARY above.
  echo ------------------------------------------------------------
) else (
  echo ------------------------------------------------------------
  echo  CONFIRM SUMMARY: PASS
  echo ------------------------------------------------------------
)

echo.
echo NEXT IN MT5:
echo   1. Enable Algo Trading ^(toolbar green^)
echo   2. Start Service: ProfitScouter_Service  ^(InpBusEnable=true^)
echo   3. Start Service: ProfitOpportunity_Grader
echo   4. Attach Expert: GsignalX_GocityGroup  ^(InpBusEnable=true^)
echo   5. Double-click Confirm-After-Start.bat
echo.
echo Docs: DEPLOYMENT.md / DEPLOYMENT_RUNBOOK.md
echo.
pause
exit /b %CONFIRM_EXIT%

:fail
echo.
echo UPGRADE FAILED. See messages above.
pause
exit /b 1
