# Ever Dialer PC - Windows Release Packager (PowerShell)
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      Ever Dialer PC - Windows Release Packager     " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path (Join-Path $ScriptDir "pubspec.yaml")) {
    $ProjectDir = $ScriptDir
} elseif (Test-Path (Join-Path (Split-Path -Parent $ScriptDir) "pubspec.yaml")) {
    $ProjectDir = Split-Path -Parent $ScriptDir
} else {
    $ProjectDir = Get-Location
}

Set-Location $ProjectDir
Write-Host "[INFO] Project Directory : $ProjectDir" -ForegroundColor Gray

# Extract version
$Version = "1.0.0"
if (Select-String -Path "pubspec.yaml" -Pattern "^version:\s*([^\s+]+)") {
    $matches = [regex]::Match((Get-Content "pubspec.yaml" -Raw), "version:\s*([0-9\.]+)")
    if ($matches.Success) {
        $Version = $matches.Groups[1].Value
    }
}

$DownloadsFolder = [Environment]::GetFolderPath("UserProfile") + "\Downloads\Windows Release"
if (-not (Test-Path $DownloadsFolder)) {
    New-Item -ItemType Directory -Path $DownloadsFolder -Force | Out-Null
}

Write-Host "[INFO] App Version       : $Version" -ForegroundColor Gray
Write-Host "[INFO] Output Directory   : $DownloadsFolder" -ForegroundColor Gray
Write-Host ""

# Ensure Windows platform
if (-not (Test-Path "windows\CMakeLists.txt")) {
    Write-Host "[INFO] Initializing Windows desktop runner..." -ForegroundColor Yellow
    flutter create --platforms=windows .
}

Write-Host "[STEP 1/3] Fetching dependencies..." -ForegroundColor Green
flutter pub get

Write-Host "[STEP 2/3] Compiling Flutter Windows x64 Release..." -ForegroundColor Green
flutter build windows --release

$ReleaseDir = "build\windows\x64\runner\Release"
if (-not (Test-Path "$ReleaseDir\ever_dialer_pc.exe")) {
    $ReleaseDir = "build\windows\runner\Release"
}

if (-not (Test-Path "$ReleaseDir\ever_dialer_pc.exe")) {
    Write-Error "Could not find compiled ever_dialer_pc.exe in $ReleaseDir"
    exit 1
}

Write-Host "[STEP 3/3] Packaging Release into Windows Downloads..." -ForegroundColor Green
$PkgName = "Ever-Dialer-PC-v$Version-windows-x64"
$PkgDir = Join-Path $DownloadsFolder $PkgName
$ZipOut = Join-Path $DownloadsFolder "$PkgName.zip"

if (Test-Path $PkgDir) {
    Remove-Item -Recurse -Force $PkgDir
}
New-Item -ItemType Directory -Path $PkgDir -Force | Out-Null

Copy-Item -Path "$ReleaseDir\*" -Destination $PkgDir -Recurse -Force
if (Test-Path "assets\icons\app_icon_512.png") {
    Copy-Item "assets\icons\app_icon_512.png" (Join-Path $PkgDir "app_icon.png") -Force
}

if (Test-Path $ZipOut) {
    Remove-Item -Force $ZipOut
}
Compress-Archive -Path "$PkgDir\*" -DestinationPath $ZipOut -Force

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "       SUCCESS: WINDOWS RELEASE PACKAGED" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Folder : $PkgDir" -ForegroundColor Cyan
Write-Host "ZIP    : $ZipOut" -ForegroundColor Cyan
Write-Host "EXE    : $PkgDir\ever_dialer_pc.exe" -ForegroundColor Yellow
Write-Host ""
