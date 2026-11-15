@echo off
setlocal enabledelayedexpansion

title Ever Dialer PC - Windows Release Packager

echo.
echo ====================================================
echo       Ever Dialer PC - Windows Release Packager
echo ====================================================
echo.

:: 1. DYNAMICALLY LOCATE PROJECT ROOT
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR="

if exist "%SCRIPT_DIR%pubspec.yaml" (
    set "PROJECT_DIR=%SCRIPT_DIR%"
) else if exist "%SCRIPT_DIR%..\pubspec.yaml" (
    pushd "%SCRIPT_DIR%.."
    set "PROJECT_DIR=!CD!\"
    popd
) else if exist ".\pubspec.yaml" (
    set "PROJECT_DIR=!CD!\"
)

if "%PROJECT_DIR%"=="" (
    echo [ERROR] Could not locate Ever Dialer PC project root directory (pubspec.yaml not found).
    echo Please navigate into the project folder and run app_release_win.
    pause
    exit /b 1
)

cd /d "%PROJECT_DIR%"

:: 2. EXTRACT APP VERSION FROM pubspec.yaml
set "VERSION=1.0.0"
for /f "tokens=2 delims=: " %%a in ('findstr /b "version:" pubspec.yaml 2^>nul') do (
    set "RAW_VER=%%a"
    for /f "tokens=1 delims=+" %%v in ("!RAW_VER!") do set "VERSION=%%v"
)

:: 3. PREPARE OUTPUT DIRECTORIES IN WINDOWS DOWNLOADS
set "OUTPUT_DIR=%USERPROFILE%\Downloads\Windows Release"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

echo [INFO] Project Directory : %PROJECT_DIR%
echo [INFO] App Version       : %VERSION%
echo [INFO] Architecture      : x64 (64-bit)
echo [INFO] Output Folder     : %OUTPUT_DIR%
echo.

:: 4. CHECK FLUTTER INSTALLATION
where flutter >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter SDK was not found in your Windows PATH.
    echo Please install Flutter for Windows and add flutter\bin to your System Environment PATH.
    pause
    exit /b 1
)

:: 5. ENSURE WINDOWS RUNNER EXISTS
if not exist "windows\CMakeLists.txt" (
    echo [INFO] Windows runner not found. Initializing Windows desktop platform...
    call flutter create --platforms=windows .
    if errorlevel 1 (
        echo [ERROR] Failed to initialize Windows platform support with Flutter.
        pause
        exit /b 1
    )
)

:: 6. FLUTTER PUB GET
echo [STEP 1/3] Fetching project dependencies (flutter pub get)...
call flutter pub get
if errorlevel 1 (
    echo [WARNING] flutter pub get returned an error. Attempting build anyway...
)

:: 7. COMPILE FLUTTER WINDOWS RELEASE BINARY
echo.
echo [STEP 2/3] Compiling Flutter Windows x64 Release Binary...
echo (This may take a few minutes on first run as Visual Studio C++ builds the runner)
call flutter build windows --release
if errorlevel 1 (
    echo.
    echo [ERROR] Flutter build windows failed!
    echo Ensure "Visual Studio 2022" with "Desktop development with C++" workload is installed.
    pause
    exit /b 1
)

:: 8. DETECT RELEASE BUNDLE LOCATION
set "RELEASE_DIR=build\windows\x64\runner\Release"
if not exist "%RELEASE_DIR%\ever_dialer_pc.exe" (
    set "RELEASE_DIR=build\windows\runner\Release"
)

if not exist "%RELEASE_DIR%\ever_dialer_pc.exe" (
    echo [ERROR] Could not find compiled ever_dialer_pc.exe in build output!
    pause
    exit /b 1
)

:: 9. PACKAGE PORTABLE FOLDER & ZIP TO WINDOWS DOWNLOADS
echo.
echo [STEP 3/3] Packaging Release into Windows Downloads...
set "PKG_NAME=Ever-Dialer-PC-v%VERSION%-windows-x64"
set "PKG_DIR=%OUTPUT_DIR%\%PKG_NAME%"
set "ZIP_OUT=%OUTPUT_DIR%\%PKG_NAME%.zip"

if exist "%PKG_DIR%" rmdir /s /q "%PKG_DIR%"
mkdir "%PKG_DIR%"

xcopy /e /i /y "%RELEASE_DIR%\*" "%PKG_DIR%\" >nul

:: Copy app icon and readme if available
if exist "assets\icons\app_icon_512.png" copy /y "assets\icons\app_icon_512.png" "%PKG_DIR%\app_icon.png" >nul
if exist "README_WINDOWS_AI.md" copy /y "README_WINDOWS_AI.md" "%PKG_DIR%\README.txt" >nul

:: Create Zip archive via PowerShell
if exist "%ZIP_OUT%" del /f /q "%ZIP_OUT%"
powershell -NoProfile -Command "Compress-Archive -Path '%PKG_DIR%\*' -DestinationPath '%ZIP_OUT%' -Force"

echo.
echo ====================================================
echo       SUCCESS: WINDOWS RELEASE PACKAGED
echo ====================================================
echo Folder  : %PKG_DIR%
echo ZIP     : %ZIP_OUT%
echo.
echo Executable is ready: %PKG_DIR%\ever_dialer_pc.exe
echo.

exit /b 0
