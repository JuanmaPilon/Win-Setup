[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $RepositoryRoot 'modules/SetupHelpers.psm1') -Force

Write-SetupStep 'Ensuring applications from Winget manifest are present'
Ensure-WingetAvailable

$manifestPath = Join-Path $RepositoryRoot 'apps/winget-apps.txt'
if (-not (Test-Path $manifestPath)) {
    throw "Winget manifest not found at $manifestPath"
}

$packages = Get-Content $manifestPath | Where-Object { $_ -and -not $_.TrimStart().StartsWith('#') }
$defaultInstallLocation = if ($env:ProgramFiles) { $env:ProgramFiles } else { 'C:\Program Files' }

foreach ($package in $packages) {
    $packageId = $package.Trim()
    if (-not $packageId) {
        continue
    }

    Write-SetupStep "Checking package: $packageId"

    $listOutput = winget list --id $packageId --exact --source winget 2>$null
    if ($LASTEXITCODE -eq 0 -and $listOutput -match [regex]::Escape($packageId)) {
        Write-SetupStep "Package already installed; checking for updates: $packageId"

        $upgradeOutput = winget upgrade --id $packageId --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity 2>&1
        $upgradeText = ($upgradeOutput | Out-String)

        if ($LASTEXITCODE -eq 0) {
            Write-SetupStep "Package already installed and upgrade check completed: $packageId"
            continue
        }

        if ($upgradeText -match 'No applicable update found|No upgrade available|No update available') {
            Write-SetupStep "Package already installed and up to date: $packageId"
            continue
        }

        Write-SetupStep "Package already installed; upgrade check did not return a usable result: $packageId"
        continue
    }

    $installArgs = @('install', '--id', $packageId, '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
    $installOutput = & winget @installArgs 2>&1
    $installText = ($installOutput | Out-String)
    $installExitCode = $LASTEXITCODE

    if ($installExitCode -ne 0 -and $installText -match 'requires an install location|Install location is required') {
        Write-SetupStep "Package requires an install location; retrying with: $defaultInstallLocation"
        $installArgs += @('--location', $defaultInstallLocation)
        $installOutput = & winget @installArgs 2>&1
        $installText = ($installOutput | Out-String)
        $installExitCode = $LASTEXITCODE
    }

    if ($installExitCode -ne 0) {
        Write-SetupStep "Failed to install package: $packageId"
        Write-SetupStep $installText
        Write-SetupStep "Continuing with the next package."
        continue
    }
}

Write-SetupStep 'Application installation stage completed.'
