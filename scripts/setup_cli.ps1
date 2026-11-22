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

# 2. Install dynamic shims for release in cliDir
$dynamicReleasePs1 = @'
# Ever Dialer PC - Dynamic Release Packager CLI
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArguments
)

function Find-EverDialerProject {
    $curr = (Get-Location).Path
    while ($curr) {
        $pubspec = Join-Path $curr "pubspec.yaml"
        if (Test-Path $pubspec) {
            $content = Get-Content $pubspec -Raw -ErrorAction SilentlyContinue
            if ($content -match "name:\s*ever_dialer_pc") { return $curr }
        }
        $parent = Split-Path $curr -Parent
        if ($parent -eq $curr) { break }
        $curr = $parent
    }
    $cachePaths = @("$env:LOCALAPPDATA\ever_dialer_pc\project_dir", "$env:USERPROFILE\.config\ever_dialer_pc\project_dir")
    foreach ($cp in $cachePaths) {
        if (Test-Path $cp) {
            $cached = (Get-Content $cp -Raw -ErrorAction SilentlyContinue).Trim()
            if ($cached -and (Test-Path "$cached\pubspec.yaml")) { return $cached }
        }
    }
    return $null
}

$targetProject = Find-EverDialerProject
if (-not $targetProject) {
    Write-Host "[ERROR] No Ever Dialer PC project found in current directory: $((Get-Location).Path)" -ForegroundColor Red
    Write-Host "Please navigate (cd) into the Ever Dialer PC folder to run this command." -ForegroundColor Yellow
    exit 1
}

$scriptToRun = Join-Path $targetProject "scripts\app_release_win.ps1"
if (-not (Test-Path $scriptToRun)) {
    Write-Host "[ERROR] scripts\app_release_win.ps1 missing in $targetProject" -ForegroundColor Red
    exit 1
}

if ($ScriptArguments) { & $scriptToRun @ScriptArguments } else { & $scriptToRun }
'@

$dynamicReleaseCmd = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { function Find-EverDialerProject { $curr = (Get-Location).Path; while ($curr) { $pubspec = Join-Path $curr 'pubspec.yaml'; if (Test-Path $pubspec) { if ((Get-Content $pubspec -Raw) -match 'name:\s*ever_dialer_pc') { return $curr } }; $parent = Split-Path $curr -Parent; if ($parent -eq $curr) { break }; $curr = $parent }; $cachePaths = @(\"$env:LOCALAPPDATA\ever_dialer_pc\project_dir\", \"$env:USERPROFILE\.config\ever_dialer_pc\project_dir\"); foreach ($cp in $cachePaths) { if (Test-Path $cp) { $cached = (Get-Content $cp -Raw).Trim(); if ($cached -and (Test-Path \"$cached\pubspec.yaml\")) { return $cached } } }; return $null }; $targetProject = Find-EverDialerProject; if (-not $targetProject) { Write-Host '[ERROR] No Ever Dialer PC project found.' -ForegroundColor Red; exit 1 }; $runner = Join-Path $targetProject 'scripts\app_release_win.ps1'; if ($args) { & $runner @args } else { & $runner } }" %*
'@

# Dynamic Heal CLI shims
$dynamicHealPs1 = @'
# Ever Dialer PC - Universal Dual-Boot Healer CLI
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArguments
)

function Find-EverDialerProject {
    $curr = (Get-Location).Path
    while ($curr) {
        $pubspec = Join-Path $curr "pubspec.yaml"
        if (Test-Path $pubspec) {
            $content = Get-Content $pubspec -Raw -ErrorAction SilentlyContinue
            if ($content -match "name:\s*ever_dialer_pc") { return $curr }
        }
        $parent = Split-Path $curr -Parent
        if ($parent -eq $curr) { break }
        $curr = $parent
    }
    $cachePaths = @("$env:LOCALAPPDATA\ever_dialer_pc\project_dir", "$env:USERPROFILE\.config\ever_dialer_pc\project_dir")
    foreach ($cp in $cachePaths) {
        if (Test-Path $cp) {
            $cached = (Get-Content $cp -Raw -ErrorAction SilentlyContinue).Trim()
            if ($cached -and (Test-Path "$cached\pubspec.yaml")) { return $cached }
        }
    }
    return $null
}

$targetProject = Find-EverDialerProject
if (-not $targetProject) {
    Write-Host "[ERROR] Could not find the Ever Dialer PC project directory." -ForegroundColor Red
    Write-Host "Please navigate (cd) into the Ever Dialer PC folder once so the path is registered." -ForegroundColor Yellow
    exit 1
}

$healScript = Join-Path $targetProject "scripts\heal.ps1"
if (-not (Test-Path $healScript)) {
    Write-Host "[ERROR] scripts\heal.ps1 missing in $targetProject" -ForegroundColor Red
    exit 1
}

if ($ScriptArguments) { & $healScript @ScriptArguments } else { & $healScript }
'@

$dynamicHealCmd = @'
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { function Find-EverDialerProject { $curr = (Get-Location).Path; while ($curr) { $pubspec = Join-Path $curr 'pubspec.yaml'; if (Test-Path $pubspec) { if ((Get-Content $pubspec -Raw) -match 'name:\s*ever_dialer_pc') { return $curr } }; $parent = Split-Path $curr -Parent; if ($parent -eq $curr) { break }; $curr = $parent }; $cachePaths = @(\"$env:LOCALAPPDATA\ever_dialer_pc\project_dir\", \"$env:USERPROFILE\.config\ever_dialer_pc\project_dir\"); foreach ($cp in $cachePaths) { if (Test-Path $cp) { $cached = (Get-Content $cp -Raw).Trim(); if ($cached -and (Test-Path \"$cached\pubspec.yaml\")) { return $cached } } }; return $null }; $targetProject = Find-EverDialerProject; if (-not $targetProject) { Write-Host '[ERROR] No Ever Dialer PC project found.' -ForegroundColor Red; exit 1 }; $runner = Join-Path $targetProject 'scripts\heal.ps1'; if ($args) { & $runner @args } else { & $runner } }" %*
'@

Set-Content -Path "$cliDir\app_release_win.ps1" -Value $dynamicReleasePs1
Set-Content -Path "$cliDir\build_release_win.ps1" -Value $dynamicReleasePs1
Set-Content -Path "$cliDir\app_release.ps1" -Value $dynamicReleasePs1
Set-Content -Path "$cliDir\build_release.ps1" -Value $dynamicReleasePs1

Set-Content -Path "$cliDir\app_release_win.cmd" -Value $dynamicReleaseCmd
Set-Content -Path "$cliDir\build_release_win.cmd" -Value $dynamicReleaseCmd
Set-Content -Path "$cliDir\app_release.cmd" -Value $dynamicReleaseCmd
Set-Content -Path "$cliDir\build_release.cmd" -Value $dynamicReleaseCmd

# Install heal shims
Set-Content -Path "$cliDir\heal.ps1" -Value $dynamicHealPs1
Set-Content -Path "$cliDir\ever-heal.ps1" -Value $dynamicHealPs1
Set-Content -Path "$cliDir\heal.cmd" -Value $dynamicHealCmd
Set-Content -Path "$cliDir\ever-heal.cmd" -Value $dynamicHealCmd
Write-Host "[OK] Dynamic global shims (release + heal) installed to $cliDir"

# 3. Configure PowerShell Profiles
$profiles = @(
    "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
    "$env:USERPROFILE\Documents\WindowsPowerShell\profile.ps1",
    "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1",
    "$env:USERPROFILE\Documents\PowerShell\profile.ps1"
)

$profileSnippet = @'

# Ever Dialer PC Dynamic Commands
function global:Find-EverDialerProject {
    $curr = (Get-Location).Path
    while ($curr) {
        $pubspec = Join-Path $curr "pubspec.yaml"
        if (Test-Path $pubspec) {
            $content = Get-Content $pubspec -Raw -ErrorAction SilentlyContinue
            if ($content -match "name:\s*ever_dialer_pc") { return $curr }
        }
        $parent = Split-Path $curr -Parent
        if ($parent -eq $curr) { break }
        $curr = $parent
    }
    $cachePaths = @("$env:LOCALAPPDATA\ever_dialer_pc\project_dir", "$env:USERPROFILE\.config\ever_dialer_pc\project_dir")
    foreach ($cp in $cachePaths) {
        if (Test-Path $cp) {
            $cached = (Get-Content $cp -Raw -ErrorAction SilentlyContinue).Trim()
            if ($cached -and (Test-Path "$cached\pubspec.yaml")) { return $cached }
        }
    }
    return $null
}

function global:heal {
    $proj = global:Find-EverDialerProject
    if (-not $proj) {
        Write-Host "[ERROR] Could not find the Ever Dialer PC project directory." -ForegroundColor Red
        return
    }
    $runner = Join-Path $proj "scripts\heal.ps1"
    if (Test-Path $runner) {
        if ($args) { & $runner @args } else { & $runner }
    } else {
        Write-Host "[ERROR] scripts\heal.ps1 not found in $proj" -ForegroundColor Red
    }
}
function global:ever-heal { global:heal @args }
function global:heal_pc { global:heal @args }

function global:app_release_win {
    $proj = global:Find-EverDialerProject
    if (-not $proj) {
        Write-Host "[ERROR] Could not find the Ever Dialer PC project directory." -ForegroundColor Red
        return
    }
    $runner = Join-Path $proj "scripts\app_release_win.ps1"
    if (Test-Path $runner) {
        if ($args) { & $runner @args } else { & $runner }
    } else {
        Write-Host "[ERROR] scripts\app_release_win.ps1 not found in $proj" -ForegroundColor Red
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
        if ($existing -match 'function (global:)?app_release_win' -or $existing -match 'function (global:)?heal') {
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
