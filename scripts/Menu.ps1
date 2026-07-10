[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

while ($true) {
    Write-Host ''
    Write-Host 'Choose an action:' -ForegroundColor Cyan
    Write-Host '1) Export everything'
    Write-Host '2) Import environment variables'
    Write-Host '3) Run full setup'
    Write-Host '4) Exit'

    $choice = Read-Host 'Selection'

    switch ($choice) {
        '1' {
            & (Join-Path $repoRoot 'scripts/Export-EnvironmentVariables.ps1')
            & (Join-Path $repoRoot 'scripts/Export-StartAllBack.ps1')
            & (Join-Path $repoRoot 'scripts/Export-PowerToys.ps1')
            Write-Host 'Export completed for environment variables, StartAllBack, and PowerToys configuration.' -ForegroundColor Green
        }
        '2' {
            & (Join-Path $repoRoot 'scripts/Import-EnvironmentVariables.ps1')
        }
        '3' {
            & (Join-Path $repoRoot 'Setup.ps1')
        }
        '4' {
            break
        }
        default {
            Write-Host 'Invalid selection.' -ForegroundColor Yellow
        }
    }
}
