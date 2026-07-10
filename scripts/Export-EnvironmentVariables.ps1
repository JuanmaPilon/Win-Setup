[CmdletBinding()]
param(
    [string]$OutputPath = 'backups/environment-variables.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Get-EnvironmentVariableMap {
    param([Parameter(Mandatory = $true)][string]$Target)

    $values = [System.Environment]::GetEnvironmentVariables($Target)
    $map = [ordered]@{}

    foreach ($key in $values.Keys | Sort-Object) {
        $map[$key] = $values[$key]
    }

    return $map
}

$userVariables = Get-EnvironmentVariableMap -Target 'User'
$machineVariables = Get-EnvironmentVariableMap -Target 'Machine'

$data = [ordered]@{
    exportedAt = (Get-Date).ToString('o')
    user = $userVariables
    machine = $machineVariables
}

if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
}
else {
    $resolvedOutputPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
}

$parent = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$data | ConvertTo-Json -Depth 5 | Set-Content -Path $resolvedOutputPath -Encoding UTF8
Write-Host "Environment variables exported to $resolvedOutputPath" -ForegroundColor Green
