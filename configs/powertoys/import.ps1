[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $RepositoryRoot 'modules/SetupHelpers.psm1') -Force

Write-SetupStep 'Preparing PowerToys configuration import'

$configSource = Join-Path $RepositoryRoot 'configs/powertoys'
$powertoysConfigPath = Join-Path $env:LOCALAPPDATA 'Microsoft/PowerToys'

if (-not (Test-Path $configSource)) {
    Write-SetupStep 'PowerToys config source directory not found.'
    return
}

if (-not (Test-Path $powertoysConfigPath)) {
    Write-SetupStep 'PowerToys is not installed yet or its config folder is missing.'
    return
}

$filesToCopy = @(
    'settings.json'
)

foreach ($file in $filesToCopy) {
    $sourceFile = Join-Path $configSource $file
    if (Test-Path $sourceFile) {
        Copy-Item -Path $sourceFile -Destination (Join-Path $powertoysConfigPath $file) -Force
        Write-SetupStep "Imported PowerToys file: $file"
    }
}

Write-SetupStep 'PowerToys configuration import completed.'
