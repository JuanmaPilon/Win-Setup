[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

while ($true) {
    Write-Host ''
    Write-Host 'Choose an action:' -ForegroundColor Cyan
    Write-Host '1) Install Winget'
    Write-Host '2) Run full setup'
    Write-Host '3) Import environment variables'
    Write-Host '4) Export everything'
    Write-Host '5) Exit'

    $choice = Read-Host 'Selection'

    switch ($choice) {
        '1' {
            & (Join-Path $repoRoot 'scripts/Install-Winget.ps1') -RepositoryRoot $repoRoot
        }
        '2' {
            $runAsAdmin = Read-Host 'Run full setup as administrator? (y/n)'
            if ($runAsAdmin -match '^(y|yes)$') {
                $setupScript = Join-Path $repoRoot 'Setup.ps1'
                Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $setupScript) | Out-Null
                Write-Host 'Started setup in an elevated PowerShell window.' -ForegroundColor Green
            }
            else {
                & (Join-Path $repoRoot 'Setup.ps1')
            }
        }
        '3' {
            & (Join-Path $repoRoot 'scripts/Import-EnvironmentVariables.ps1')
        }
        '4' {
            & (Join-Path $repoRoot 'scripts/Export-EnvironmentVariables.ps1')
            & (Join-Path $repoRoot 'scripts/Export-StartAllBack.ps1')
            & (Join-Path $repoRoot 'scripts/Export-PowerToys.ps1')
            Write-Host 'Export completed for environment variables, StartAllBack, and PowerToys configuration.' -ForegroundColor Green
        }
        '5' {
            break
        }
        default {
            Write-Host 'Invalid selection.' -ForegroundColor Yellow
        }
    }
}
