@echo off
setlocal EnableExtensions
title GSignalX - List Terminals
cd /d "%~dp0.."
powershell -NoProfile -ExecutionPolicy Bypass -File "deploy\Deploy-GSignalX.ps1" -ListTerminals
echo.
pause
