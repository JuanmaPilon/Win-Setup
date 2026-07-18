[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Import-Module (Join-Path $RepositoryRoot 'modules/SetupHelpers.psm1') -Force

Write-SetupStep 'Preparing Windows UI configuration import'

$privateSourceRoot = Join-Path $RepositoryRoot 'private-configs/windows-ui'
$publicSourceRoot = Join-Path $RepositoryRoot 'configs/windows-ui'
$sourceRoot = if (Test-Path $privateSourceRoot) { $privateSourceRoot } else { $publicSourceRoot }

if (-not (Test-Path $sourceRoot)) {
    Write-SetupWarning 'Windows UI config source directory not found.'
    return
}

$registryFiles = @(
    'Mouse.reg',
    'Theme-Personalize.reg',
    'NotifyIconSettings.reg',
    'Desktop-Icons-NewStartPanel.reg',
    'Desktop-Icons-ClassicStartMenu.reg',
    'Explorer-Advanced.reg'
)

$appliedChanges = $false

foreach ($fileName in $registryFiles) {
    $filePath = Join-Path $sourceRoot $fileName
    if (-not (Test-Path $filePath)) {
        continue
    }

    try {
        reg import $filePath | Out-Null
        Write-SetupSuccess "Imported Windows UI registry file: $fileName"
        $appliedChanges = $true
    }
    catch {
        Write-SetupWarning "Failed to import Windows UI registry file '$fileName': $($_.Exception.Message)"
    }
}

$quickAccessSource = Join-Path $sourceRoot 'quick-access/f01b4d95cf55d32a.automaticDestinations-ms'
$quickAccessTarget = Join-Path $env:APPDATA 'Microsoft/Windows/Recent/AutomaticDestinations/f01b4d95cf55d32a.automaticDestinations-ms'

if (Test-Path $quickAccessSource) {
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

        $quickAccessTargetDirectory = Split-Path -Parent $quickAccessTarget
        if (-not (Test-Path $quickAccessTargetDirectory)) {
            New-Item -ItemType Directory -Path $quickAccessTargetDirectory -Force | Out-Null
        }

        Copy-Item -Path $quickAccessSource -Destination $quickAccessTarget -Force
        Write-SetupSuccess 'Imported Quick Access pinned folders database.'
        $appliedChanges = $true
    }
    catch {
        Write-SetupWarning "Failed to import Quick Access pinned folders database: $($_.Exception.Message)"
    }
}

if ($appliedChanges) {
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer.exe | Out-Null
        Write-SetupSuccess 'Restarted Explorer to apply Windows UI settings.'
    }
    catch {
        Write-SetupWarning 'Could not restart Explorer automatically. Sign out and sign in again if changes are not visible.'
    }
}

Write-SetupSuccess 'Windows UI configuration import completed.'