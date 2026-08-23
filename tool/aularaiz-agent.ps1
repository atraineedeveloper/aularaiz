[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$AgentArgs
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

Push-Location $repoRoot
try {
    & dart run bin/aularaiz_agent.dart @AgentArgs
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
