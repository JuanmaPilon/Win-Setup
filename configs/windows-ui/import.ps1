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
    'Explorer-Advanced.reg'
)

foreach ($fileName in $registryFiles) {
    $filePath = Join-Path $sourceRoot $fileName
    if (-not (Test-Path $filePath)) {
        continue
    }

    try {
        reg import $filePath | Out-Null
        Write-SetupSuccess "Imported Windows UI registry file: $fileName"
    }
    catch {
        Write-SetupWarning "Failed to import Windows UI registry file '$fileName': $($_.Exception.Message)"
    }
}

try {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe | Out-Null
    Write-SetupSuccess 'Restarted Explorer to apply Windows UI settings.'
}
catch {
    Write-SetupWarning 'Could not restart Explorer automatically. Sign out and sign in again if changes are not visible.'
}

Write-SetupSuccess 'Windows UI configuration import completed.'