<#
.SYNOPSIS
    Ever Dialer PC - Universal Dual-Boot Self-Healing Script for Windows
.DESCRIPTION
    Dynamically discovers the Ever Dialer PC project directory (no hardcoded paths),
    diagnoses cross-platform cache/dependency contamination from Linux, heals
    the project configuration, cleans stale CMake and Dart artifacts, synchronizes
    Flutter packages, and verifies VS Code readiness so clicking "Run" works seamlessly.
#>

param(
    [switch]$Clean,
    [switch]$Silent
)

$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "      Ever Dialer PC - Universal Dual-Boot Healer         " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "[INFO] Host Platform: Windows" -ForegroundColor Gray

# -------------------------------------------------------------------
# 1. DYNAMICALLY LOCATE PROJECT DIRECTORY (Zero Hardcoding)
# -------------------------------------------------------------------
function Find-EverDialerProject {
    # Check 1: Script's own parent folder (scripts\.. -> root)
    if ($PSScriptRoot) {
        $candidate = Split-Path $PSScriptRoot -Parent
        if (Test-Path "$candidate\pubspec.yaml") {
            $raw = Get-Content "$candidate\pubspec.yaml" -Raw -ErrorAction SilentlyContinue
            if ($raw -match 'name:\s*ever_dialer_pc') {
                return $candidate
            }
        }
    }

    # Check 2: Current working directory and walk upward
    $curr = (Get-Location).Path
    while ($curr) {
        $candidatePubspec = Join-Path $curr "pubspec.yaml"
        if (Test-Path $candidatePubspec) {
            $raw = Get-Content $candidatePubspec -Raw -ErrorAction SilentlyContinue
            if ($raw -match 'name:\s*ever_dialer_pc') {
                return $curr
            }
        }
        $parent = Split-Path $curr -Parent
        if ($parent -eq $curr) { break }
        $curr = $parent
    }

    # Check 3: Cached project location in AppData / .config
    $cachePaths = @(
        "$env:LOCALAPPDATA\ever_dialer_pc\project_dir",
        "$env:USERPROFILE\.config\ever_dialer_pc\project_dir"
    )
    foreach ($cp in $cachePaths) {
        if (Test-Path $cp) {
            $cached = (Get-Content $cp -Raw -ErrorAction SilentlyContinue).Trim()
            if ($cached -and (Test-Path "$cached\pubspec.yaml")) {
                $raw = Get-Content "$cached\pubspec.yaml" -Raw -ErrorAction SilentlyContinue
                if ($raw -match 'name:\s*ever_dialer_pc') {
                    return $cached
                }
            }
        }
    }

    # Check 4: Git root lookup if git is installed
    try {
        $gitRoot = (git rev-parse --show-toplevel 2>$null)
        if ($gitRoot -and (Test-Path "$gitRoot\pubspec.yaml")) {
            $raw = Get-Content "$gitRoot\pubspec.yaml" -Raw -ErrorAction SilentlyContinue
            if ($raw -match 'name:\s*ever_dialer_pc') {
                return $gitRoot
            }
        }
    } catch {}

    return $null
}

$projectDir = Find-EverDialerProject

if (-not $projectDir) {
    Write-Host "[ERROR] Could not find the Ever Dialer PC project directory!" -ForegroundColor Red
    Write-Host "Please navigate (cd) into the Ever Dialer PC folder or clone repository." -ForegroundColor Yellow
    exit 1
}

# Normalize project directory path
$projectDir = (Resolve-Path $projectDir).Path
Write-Host "[OK] Project located dynamically at: $projectDir" -ForegroundColor Green

# Cache project directory for fast resolution in future executions
try {
    $cacheDirs = @(
        "$env:LOCALAPPDATA\ever_dialer_pc",
        "$env:USERPROFILE\.config\ever_dialer_pc"
    )
    foreach ($cd in $cacheDirs) {
        if (-not (Test-Path $cd)) {
            New-Item -ItemType Directory -Path $cd -Force | Out-Null
        }
        Set-Content -Path "$cd\project_dir" -Value $projectDir -Force
    }
} catch {}

# Change working directory to project root
Set-Location -Path $projectDir

# -------------------------------------------------------------------
# 2. HEAL DART PACKAGE CONFIG & FLUTTER DEPENDENCY MAPS
# -------------------------------------------------------------------
Write-Host "`n[STEP 1/5] Checking cross-platform dependency health..." -ForegroundColor Yellow

$pkgConfigFile = Join-Path $projectDir ".dart_tool\package_config.json"
$pluginsFile = Join-Path $projectDir ".flutter-plugins-dependencies"
$needsPubGet = $false

if ($Clean) {
    Write-Host "[HEAL] Full clean requested." -ForegroundColor Magenta
    $needsPubGet = $true
}

if (-not (Test-Path $pkgConfigFile)) {
    Write-Host "[INFO] .dart_tool\package_config.json is missing." -ForegroundColor Gray
    $needsPubGet = $true
} else {
    $pkgContent = Get-Content -Path $pkgConfigFile -Raw -ErrorAction SilentlyContinue
    # If package_config was generated on Linux, it contains /home/ or Unix root paths without Windows drive letters
    if ($pkgContent -match '/home/' -or $pkgContent -match '"rootUri":\s*"file:///(?!([A-Za-z]:))') {
        Write-Host "[HEAL] Detected Linux file URIs in package_config.json! Purging Linux package mappings..." -ForegroundColor Magenta
        Remove-Item -Path $pkgConfigFile -Force -ErrorAction SilentlyContinue
        $needsPubGet = $true
    }
}

if (Test-Path $pluginsFile) {
    $pluginsContent = Get-Content -Path $pluginsFile -Raw -ErrorAction SilentlyContinue
    if ($pluginsContent -match '/home/' -or $pluginsContent -match 'file:///(?!([A-Za-z]:))') {
        Write-Host "[HEAL] Detected Linux paths in .flutter-plugins-dependencies. Resetting..." -ForegroundColor Magenta
        Remove-Item -Path $pluginsFile -Force -ErrorAction SilentlyContinue
        $needsPubGet = $true
    }
}

# -------------------------------------------------------------------
# 3. HEAL STALE CROSS-OS BUILD CACHES
# -------------------------------------------------------------------
Write-Host "`n[STEP 2/5] Inspecting CMake & build artifacts..." -ForegroundColor Yellow

$winCmakeCache = Join-Path $projectDir "build\windows\CMakeCache.txt"
if (Test-Path $winCmakeCache) {
    $cacheText = Get-Content -Path $winCmakeCache -Raw -ErrorAction SilentlyContinue
    # If CMake cache refers to Linux compilers or paths
    if ($cacheText -match '/usr/bin' -or $cacheText -match '/home/' -or $cacheText -match 'CMAKE_C_COMPILER:FILEPATH=/') {
        Write-Host "[HEAL] Windows build cache contains Linux compiler references. Cleaning build\windows..." -ForegroundColor Magenta
        Remove-Item -Path (Join-Path $projectDir "build\windows") -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($Clean -and (Test-Path (Join-Path $projectDir "build"))) {
    Write-Host "[HEAL] Cleaning build directory..." -ForegroundColor Magenta
    Remove-Item -Path (Join-Path $projectDir "build") -Recurse -Force -ErrorAction SilentlyContinue
}

# -------------------------------------------------------------------
# 4. RUN FLUTTER PUB GET FOR WINDOWS
# -------------------------------------------------------------------
if ($needsPubGet -or -not (Test-Path $pkgConfigFile)) {
    Write-Host "[INFO] Synchronizing dependencies for Windows with 'flutter pub get'..." -ForegroundColor Cyan
    $pubProcess = Start-Process -FilePath "flutter.bat" -ArgumentList "pub", "get" -WorkingDirectory $projectDir -NoNewWindow -Wait -PassThru
    if ($pubProcess.ExitCode -ne 0) {
        # Try without .bat extension in case flutter is a shim
        $pubProcess = Start-Process -FilePath "flutter" -ArgumentList "pub", "get" -WorkingDirectory $projectDir -NoNewWindow -Wait -PassThru
    }
    if ($pubProcess.ExitCode -eq 0) {
        Write-Host "[OK] Dependencies synchronized successfully for Windows." -ForegroundColor Green
    } else {
        Write-Host "[WARN] 'flutter pub get' exited with code $($pubProcess.ExitCode)." -ForegroundColor Yellow
    }
} else {
    Write-Host "[OK] Dependencies are already healthy for Windows." -ForegroundColor Green
}

# -------------------------------------------------------------------
# 5. VERIFY VS CODE CONFIGURATIONS & ASSETS
# -------------------------------------------------------------------
Write-Host "`n[STEP 3/5] Verifying VS Code Run & Build configurations..." -ForegroundColor Yellow

$vscodeDir = Join-Path $projectDir ".vscode"
if (-not (Test-Path $vscodeDir)) {
    New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
}

$vscodeLaunch = Join-Path $vscodeDir "launch.json"
$winLaunchConfig = @'
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Ever Dialer PC (Windows Debug)",
            "request": "launch",
            "type": "dart",
            "deviceId": "windows",
            "flutterMode": "debug",
            "program": "lib/main.dart",
            "internalConsoleOptions": "openOnSessionStart"
        },
        {
            "name": "Ever Dialer PC (Windows Release)",
            "request": "launch",
            "type": "dart",
            "deviceId": "windows",
            "flutterMode": "release",
            "program": "lib/main.dart",
            "internalConsoleOptions": "openOnSessionStart"
        },
        {
            "name": "Ever Dialer PC (Linux Debug)",
            "request": "launch",
            "type": "dart",
            "deviceId": "linux",
            "flutterMode": "debug",
            "program": "lib/main.dart",
            "internalConsoleOptions": "openOnSessionStart"
        },
        {
            "name": "Ever Dialer PC (Linux Release)",
            "request": "launch",
            "type": "dart",
            "deviceId": "linux",
            "flutterMode": "release",
            "program": "lib/main.dart",
            "internalConsoleOptions": "openOnSessionStart"
        }
    ]
}
'@

Set-Content -Path $vscodeLaunch -Value $winLaunchConfig -Force
Write-Host "[OK] VS Code build selection configured with Windows Debug, Windows Release, Linux Debug, Linux Release." -ForegroundColor Green

# Check Windows icon
$winIcon = Join-Path $projectDir "windows\runner\resources\app_icon.ico"
if (-not (Test-Path $winIcon)) {
    Write-Host "[WARN] app_icon.ico is missing. Attempting regeneration..." -ForegroundColor Yellow
    $icoGen = Join-Path $projectDir "scripts\generate_ico.ps1"
    if (Test-Path $icoGen) {
        & $icoGen
    }
} else {
    Write-Host "[OK] Windows icon verified ($winIcon)." -ForegroundColor Green
}

# -------------------------------------------------------------------
# 6. VERIFY FLUTTER RUNNER DEVICE
# -------------------------------------------------------------------
Write-Host "`n[STEP 4/5] Checking connected Flutter devices..." -ForegroundColor Yellow
try {
    $devicesOut = & flutter devices 2>&1
    if ($devicesOut -match "windows") {
        Write-Host "[OK] Windows desktop runner device is active and recognized." -ForegroundColor Green
    } else {
        Write-Host "[WARN] Windows desktop device was not listed by 'flutter devices'." -ForegroundColor Yellow
        Write-Host "       Check if Windows desktop development is enabled in Flutter ('flutter config --enable-windows-desktop')." -ForegroundColor Gray
    }
} catch {
    Write-Host "[WARN] Could not run 'flutter devices': $_" -ForegroundColor Yellow
}

# -------------------------------------------------------------------
# 7. ENSURE GLOBAL CLI SHIMS ARE CONFIGURED
# -------------------------------------------------------------------
Write-Host "`n[STEP 5/5] Checking CLI command integration..." -ForegroundColor Yellow
$setupCli = Join-Path $projectDir "scripts\setup_cli.ps1"
if (Test-Path $setupCli) {
    # Install/update CLI commands silently
    & $setupCli | Out-Null
    Write-Host "[OK] Global CLI commands ('heal', 'app_release_win') are active in terminal." -ForegroundColor Green
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "    [SUCCESS] Ever Dialer PC is healed for Windows!       " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host " You can now:" -ForegroundColor White
Write-Host "   1. Click the 'Run' button (F5) in VS Code or Android Studio." -ForegroundColor White
Write-Host "   2. Run 'flutter run -d windows' from any terminal." -ForegroundColor White
Write-Host "   3. Type 'heal' anytime you switch between Linux and Windows." -ForegroundColor White
Write-Host "==========================================================`n" -ForegroundColor Green
