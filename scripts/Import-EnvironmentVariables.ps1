[CmdletBinding()]
param(
    [string]$InputPath = 'backups/environment-variables.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

if ([System.IO.Path]::IsPathRooted($InputPath)) {
    $resolvedInputPath = [System.IO.Path]::GetFullPath($InputPath)
}
else {
    $resolvedInputPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $InputPath))
}

if (-not (Test-Path $resolvedInputPath)) {
    throw "Environment variable backup not found: $resolvedInputPath"
}

$data = Get-Content -Path $resolvedInputPath -Raw | ConvertFrom-Json

foreach ($entry in $data.user.PSObject.Properties) {
    [Environment]::SetEnvironmentVariable($entry.Name, [string]$entry.Value, 'User')
}

foreach ($entry in $data.machine.PSObject.Properties) {
    [Environment]::SetEnvironmentVariable($entry.Name, [string]$entry.Value, 'Machine')
}

Write-Host 'Environment variables imported.' -ForegroundColor Green
