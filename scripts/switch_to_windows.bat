@echo off
setlocal
cd /d "%~dp0\.."
echo [INFO] Preparing Ever Dialer PC for Windows...
dart run scripts\sync_platform.dart
if errorlevel 1 (
    echo [ERROR] Synchronization encountered issues.
    pause
    exit /b 1
)
echo.
echo [SUCCESS] Windows environment ready! You can now run the app or click Run in Android Studio / VS Code.
