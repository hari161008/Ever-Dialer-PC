# Setup dynamic Ever Dialer PC CLI commands in PATH and PowerShell profiles
$ErrorActionPreference = "Continue"

# 1. Determine CLI directory (WinGet\Links or %USERPROFILE%\bin)
$cliDir = "$env:LOCALAPPDATA\Microsoft\WinGet\Links"
if (-not (Test-Path $cliDir)) {
    $cliDir = "$env:USERPROFILE\bin"
}
if (-not (Test-Path $cliDir)) {
    New-Item -ItemType Directory -Path $cliDir -Force | Out-Null
}

# Ensure cliDir is in User PATH
try {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notmatch [regex]::Escape($cliDir)) {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$cliDir", "User")
        $env:PATH = "$env:PATH;$cliDir"
        Write-Host "[OK] Added $cliDir to permanent User PATH"
    }
} catch {
    Write-Warning "Could not update user PATH registry: $_"
}

# 2. Install dynamic shims in cliDir
$dynamicPs1 = @'
# Ever Dialer PC - Dynamic Release Packager CLI
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArguments
)

# Search strictly from current directory and upward
$curr = (Get-Location).Path
$targetProject = $null
while ($curr) {
    $pubspec = Join-Path $curr "pubspec.yaml"
    if (Test-Path $pubspec) {
        $content = Get-Content $pubspec -Raw -ErrorAction SilentlyContinue
        if ($content -match "name:\s*ever_dialer_pc") {
            $targetProject = $curr
            break
        }
    }
    $parent = Split-Path $curr -Parent
    if ($parent -eq $curr) { break }
    $curr = $parent
}

if (-not $targetProject) {
    Write-Host "[ERROR] No Ever Dialer PC project found in the current directory:" -ForegroundColor Red
    Write-Host "        $((Get-Location).Path)" -ForegroundColor Yellow
    Write-Host "Please navigate (cd) into the Ever Dialer PC folder to run this command." -ForegroundColor Gray
    exit 1
}

$scriptToRun = Join-Path $targetProject "scripts\app_release_win.ps1"
if (-not (Test-Path $scriptToRun)) {
    Write-Host "[ERROR] Project found at $targetProject, but scripts\app_release_win.ps1 is missing." -ForegroundColor Red
    exit 1
}

if ($ScriptArguments) {
    & $scriptToRun @ScriptArguments
} else {
    & $scriptToRun
}
'@

$dynamicCmd = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { $curr = (Get-Location).Path; $targetProject = $null; while ($curr) { if (Test-Path (Join-Path $curr 'pubspec.yaml')) { if ((Get-Content (Join-Path $curr 'pubspec.yaml') -Raw) -match 'name:\s*ever_dialer_pc') { $targetProject = $curr; break } } $parent = Split-Path $curr -Parent; if ($parent -eq $curr) { break }; $curr = $parent }; if (-not $targetProject) { Write-Host '[ERROR] No Ever Dialer PC project found in current directory.' -ForegroundColor Red; exit 1 }; $runner = Join-Path $targetProject 'scripts\app_release_win.ps1'; if ($args) { & $runner @args } else { & $runner } }" %*
'@

Set-Content -Path "$cliDir\app_release_win.ps1" -Value $dynamicPs1
Set-Content -Path "$cliDir\build_release_win.ps1" -Value $dynamicPs1
Set-Content -Path "$cliDir\app_release.ps1" -Value $dynamicPs1
Set-Content -Path "$cliDir\build_release.ps1" -Value $dynamicPs1

Set-Content -Path "$cliDir\app_release_win.cmd" -Value $dynamicCmd
Set-Content -Path "$cliDir\build_release_win.cmd" -Value $dynamicCmd
Set-Content -Path "$cliDir\app_release.cmd" -Value $dynamicCmd
Set-Content -Path "$cliDir\build_release.cmd" -Value $dynamicCmd
Write-Host "[OK] Dynamic global shims installed to $cliDir"

# 3. Configure PowerShell Profiles strictly bound to current working directory
$profiles = @(
    "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1",
    "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
    "$env:USERPROFILE\Documents\PowerShell\profile.ps1"
)

$profileSnippet = @'

# Ever Dialer PC Dynamic Release Commands
function global:app_release_win {
    $curr = (Get-Location).Path
    $targetProject = $null
    while ($curr) {
        $pubspec = Join-Path $curr "pubspec.yaml"
        if (Test-Path $pubspec) {
            $content = Get-Content $pubspec -Raw -ErrorAction SilentlyContinue
            if ($content -match "name:\s*ever_dialer_pc") {
                $targetProject = $curr
                break
            }
        }
        $parent = Split-Path $curr -Parent
        if ($parent -eq $curr) { break }
        $curr = $parent
    }
    if (-not $targetProject) {
        Write-Host "[ERROR] No Ever Dialer PC project found in current directory: $((Get-Location).Path)" -ForegroundColor Red
        Write-Host "Please navigate (cd) into the Ever Dialer PC project folder to run app_release_win." -ForegroundColor Yellow
        return
    }
    $runner = Join-Path $targetProject "scripts\app_release_win.ps1"
    if (Test-Path $runner) {
        if ($args) {
            & $runner @args
        } else {
            & $runner
        }
    } else {
        Write-Host "[ERROR] scripts\app_release_win.ps1 not found in $targetProject" -ForegroundColor Red
    }
}
function global:build_release_win { global:app_release_win @args }
function global:app_release { global:app_release_win @args }
function global:build_release { global:app_release_win @args }
'@

foreach ($prof in $profiles) {
    try {
        $pDir = Split-Path $prof
        if (-not (Test-Path $pDir)) {
            New-Item -ItemType Directory -Path $pDir -Force | Out-Null
        }
        $existing = if (Test-Path $prof) { Get-Content $prof -Raw } else { "" }
        if ($existing -match 'function (global:)?app_release_win') {
            $cleaned = [regex]::Replace($existing, '(?s)# Ever Dialer PC.*?(function global:build_release \{.*?\}|function build_release \{.*?\})', '')
            Set-Content -Path $prof -Value ($cleaned.TrimEnd() + "`r`n" + $profileSnippet)
        } else {
            Add-Content -Path $prof -Value $profileSnippet
        }
        Write-Host "[OK] Configured profile: $prof"
    } catch {
        Write-Warning "Could not update ${prof} - $_"
    }
}

Write-Host "Dynamic CLI configuration completed."
