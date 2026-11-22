[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArguments
)
& "$PSScriptRoot\scripts\heal.ps1" @ScriptArguments
