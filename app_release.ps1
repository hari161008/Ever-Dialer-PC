# Ever Dialer PC - Windows Release Shortcut
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArguments
)

$targetScript = Join-Path $PSScriptRoot "scripts\app_release_win.ps1"
if ($ScriptArguments) {
    & $targetScript @ScriptArguments
} else {
    & $targetScript
}
