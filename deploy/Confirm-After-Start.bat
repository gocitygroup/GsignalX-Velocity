@echo off
setlocal EnableExtensions
title GSignalX - Confirm After Start
cd /d "%~dp0.."

echo ============================================================
echo  GSignalX - Confirm Bus + Grades ^(after Services are running^)
echo ============================================================
echo.
echo Make sure in MT5:
echo   - Algo Trading ON
echo   - ProfitScouter_Service started ^(bus ON^)
echo   - ProfitOpportunity_Grader started
echo   - Optional: GsignalX attached with bus ON
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
  echo RESULT: FAIL - paste the CONFIRM_*.md contents in chat for help.
) else (
  echo RESULT: PASS - paste GATE G4/G5 feedback in chat to continue the runbook.
)
echo.
pause
exit /b %EXITCODE%
