@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\app_release_win.ps1" %*
