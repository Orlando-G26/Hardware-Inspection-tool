@echo off
setlocal

set "PS1_URL=https://orlando-g26.github.io/Hardware-Inspection-tool/run-speedtest.ps1"
set "TMP_PS1=%TEMP%\transpro-speedtest-%RANDOM%.ps1"

powershell -ExecutionPolicy Bypass -NoProfile -Command "Invoke-WebRequest -Uri '%PS1_URL%' -OutFile '%TMP_PS1%'" 2>nul
if not exist "%TMP_PS1%" (
    echo ERROR: Could not download the script. Check your internet connection.
    pause
    exit /b 1
)

powershell -ExecutionPolicy Bypass -NoProfile -File "%TMP_PS1%"
del "%TMP_PS1%" 2>nul
