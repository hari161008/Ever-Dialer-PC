# Ever Dialer PC - Windows Release Packager (PowerShell)
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArguments
)

$ErrorActionPreference = "Stop"

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "      Ever Dialer PC - Windows Release Packager     " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# Dynamic project resolution: prioritize current working directory, then upward search
$CurrentLocation = (Get-Location).Path
$ProjectDir = $null

$searchStarts = @($CurrentLocation)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($ScriptDir) {
    $searchStarts += $ScriptDir
    $searchStarts += (Split-Path -Parent $ScriptDir)
}

foreach ($start in $searchStarts) {
    $curr = $start
    while ($curr) {
        $pubspec = Join-Path $curr "pubspec.yaml"
        if (Test-Path $pubspec) {
            $content = Get-Content $pubspec -Raw -ErrorAction SilentlyContinue
            if ($content -match "name:\s*ever_dialer_pc") {
                $ProjectDir = $curr
                break
            }
        }
        $parent = Split-Path $curr -Parent
        if ($parent -eq $curr) { break }
        $curr = $parent
    }
    if ($ProjectDir) { break }
}

if (-not $ProjectDir) {
    Write-Host "[ERROR] Could not find an Ever Dialer PC project in:" -ForegroundColor Red
    Write-Host "        $CurrentLocation" -ForegroundColor Yellow
    Write-Host "Please navigate into your Ever Dialer PC project folder and run app_release_win." -ForegroundColor Gray
    exit 1
}

Set-Location $ProjectDir
Write-Host "[INFO] Project Directory : $ProjectDir" -ForegroundColor Gray

# Self-healing: ensure CLI commands are available globally in PATH and PowerShell profile
if (Test-Path "$ProjectDir\scripts\setup_cli.ps1") {
    & "$ProjectDir\scripts\setup_cli.ps1" | Out-Null
}

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

# Auto-detect flutter if not in PATH
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    $candidateFlutterPaths = @(
        "C:\Android\flutter\bin",
        "C:\flutter\bin",
        "$env:LOCALAPPDATA\flutter\bin",
        "$env:USERPROFILE\flutter\bin"
    )
    foreach ($cand in $candidateFlutterPaths) {
        if (Test-Path "$cand\flutter.bat") {
            $env:PATH = "$cand;$env:PATH"
            Write-Host "[INFO] Detected Flutter at: $cand" -ForegroundColor Green
            break
        }
    }
}

# Auto-detect Inno Setup compiler (ISCC.exe)
$IsccPath = $null
$candidateIsccPaths = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)
foreach ($cand in $candidateIsccPaths) {
    if (Test-Path $cand) {
        $IsccPath = $cand
        break
    }
}
if (-not $IsccPath) {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        $IsccPath = $cmd.Source
    }
}
if (-not $IsccPath) {
    Write-Host "[INFO] Inno Setup compiler not found. Auto-installing via winget..." -ForegroundColor Yellow
    try {
        winget install --id JRSoftware.InnoSetup -e --source winget --accept-source-agreements --accept-package-agreements --silent | Out-Null
        foreach ($cand in $candidateIsccPaths) {
            if (Test-Path $cand) {
                $IsccPath = $cand
                break
            }
        }
    } catch {
        Write-Warning "Winget install failed or unavailable."
    }
}
if (-not $IsccPath) {
    Write-Host "[INFO] Attempting direct download of Inno Setup 6..." -ForegroundColor Yellow
    try {
        $tempInstaller = "$env:TEMP\innosetup-setup.exe"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri "https://files.jrsoftware.org/is/6/innosetup-6.7.3.exe" -OutFile $tempInstaller -UseBasicParsing
        Start-Process -FilePath $tempInstaller -ArgumentList "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART" -Wait
        Remove-Item -Force $tempInstaller -ErrorAction SilentlyContinue
        foreach ($cand in $candidateIsccPaths) {
            if (Test-Path $cand) {
                $IsccPath = $cand
                break
            }
        }
    } catch {
        Write-Warning "Direct Inno Setup download failed: $_"
    }
}
if (-not $IsccPath) {
    Write-Error "Could not locate Inno Setup compiler (ISCC.exe). Please install Inno Setup 6."
    exit 1
}
Write-Host "[INFO] Detected Inno Setup at: $IsccPath" -ForegroundColor Green

# Ensure Windows platform
if (-not (Test-Path "windows\CMakeLists.txt")) {
    Write-Host "[INFO] Initializing Windows desktop runner..." -ForegroundColor Yellow
    flutter create --platforms=windows .
}

# Ensure app icon is up to date
if (Test-Path "$ProjectDir\scripts\generate_ico.ps1") {
    & "$ProjectDir\scripts\generate_ico.ps1" | Out-Null
}

# Terminate any running instances so files are not locked
try {
    Stop-Process -Name "ever_dialer_pc", "bt_sync_daemon" -Force -ErrorAction SilentlyContinue
} catch {}

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

# Ensure bt_sync_daemon.exe is in the release directory
if (-not (Test-Path "$ReleaseDir\bt_sync_daemon.exe")) {
    if (Test-Path "windows\bin\bt_sync_daemon.exe") {
        Copy-Item "windows\bin\bt_sync_daemon.exe" (Join-Path $ReleaseDir "bt_sync_daemon.exe") -Force
    }
}

Write-Host "[STEP 3/3] Compiling standalone Windows installer executable..." -ForegroundColor Green
$SetupExeName = "Ever Dialer $Version Setup Recommended"
$FinalExePath = Join-Path $DownloadsFolder "$SetupExeName.exe"

# Clean any existing zip, folders, or old build outputs in Downloads so only one exe is present
Get-ChildItem -Path $DownloadsFolder -Directory | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $DownloadsFolder -Filter "*.zip" | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $DownloadsFolder -Filter "Ever-Dialer-PC-*.exe" | Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path $DownloadsFolder -Filter "Ever Dialer * Setup Recommended.exe" | Remove-Item -Force -ErrorAction SilentlyContinue

& $IsccPath /Qp /O"$DownloadsFolder" /F"$SetupExeName" /DMyAppVersion="$Version" "$ProjectDir\windows\installer\EverDialerSetup.iss"

if (-not (Test-Path $FinalExePath)) {
    Write-Error "Installer generation failed. Could not find $FinalExePath"
    exit 1
}

# Refresh Windows Explorer shell icon cache so preview updates immediately
if (Test-Path "$ProjectDir\scripts\refresh_icon_cache.ps1") {
    try {
        & "$ProjectDir\scripts\refresh_icon_cache.ps1" | Out-Null
    } catch {}
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "       SUCCESS: STANDALONE WINDOWS INSTALLER CREATED" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host "Setup EXE : $FinalExePath" -ForegroundColor Yellow
Write-Host ""
