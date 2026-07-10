[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

while ($true) {
    Write-Host ''
    Write-Host 'Choose an action:' -ForegroundColor Cyan
    Write-Host '1) Export environment variables'
    Write-Host '2) Import environment variables'
    Write-Host '3) Run full setup'
    Write-Host '4) Exit'

    $choice = Read-Host 'Selection'

    switch ($choice) {
        '1' {
            & (Join-Path $repoRoot 'scripts/Export-EnvironmentVariables.ps1')
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
