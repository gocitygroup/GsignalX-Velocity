@echo off
setlocal EnableExtensions
title GSignalX - Confirm After Start
cd /d "%~dp0.."

echo ============================================================
echo  GSignalX - Confirm Bus + Grades ^(after Services are running^)
echo ============================================================
echo.
echo Make sure in MetaTrader 5 first:
echo   - Algo Trading ON ^(toolbar green^)
echo   - GsignalX_Service started
echo   - ProfitScouter_Service started ^(bus ON^)
echo   - ProfitOpportunity_Grader started
echo   - Optional: Multisymbol Dashboard + chart GsignalX attached
echo.
echo If something failed earlier, open:
echo   docs\WINDOWS_DEPLOY_SIMPLE.md  ^(Problems and fixes^)
echo.
pause

powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Confirm-GSignalX.ps1" -Gate Bus -WriteFeedback
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Confirm-GSignalX.ps1" -Gate Grades -WriteFeedback
set EXITCODE=%ERRORLEVEL%
echo.
echo Feedback saved under deploy\feedback\
echo.
if %EXITCODE% NEQ 0 (
  echo RESULT: FAIL - open deploy\feedback\CONFIRM_*.md
  echo Stale bus often means Services are not running yet - wait 60s and retry.
) else (
  echo RESULT: PASS - desk bus/grades look healthy.
)
echo.
pause
exit /b %EXITCODE%
