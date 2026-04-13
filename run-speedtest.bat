@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0run-speedtest.ps1"
echo.
echo Exit code: %ERRORLEVEL%
pause
