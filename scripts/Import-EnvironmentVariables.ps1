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

$importedUser = 0
$importedMachine = 0
$skipped = 0

foreach ($entry in $data.user.PSObject.Properties) {
    try {
        [Environment]::SetEnvironmentVariable($entry.Name, [string]$entry.Value, 'User')
        $importedUser++
    }
    catch {
        Write-Warning "Could not import user environment variable '$($entry.Name)': $($_.Exception.Message)"
        $skipped++
    }
}

foreach ($entry in $data.machine.PSObject.Properties) {
    try {
        [Environment]::SetEnvironmentVariable($entry.Name, [string]$entry.Value, 'Machine')
        $importedMachine++
    }
    catch {
        Write-Warning "Could not import machine environment variable '$($entry.Name)': $($_.Exception.Message)"
        $skipped++
    }
}

Write-SetupSuccess "Environment variables imported. User: $importedUser, Machine: $importedMachine, Skipped: $skipped"
Write-SetupWarning 'Note: machine-level values may require an elevated PowerShell session.'
