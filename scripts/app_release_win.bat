@echo off
setlocal

title Ever Dialer PC - Windows Release Packager

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0app_release_win.ps1"
if errorlevel 1 (
    echo.
    echo [ERROR] Windows release packaging failed.
    pause
    exit /b 1
)

exit /b 0
