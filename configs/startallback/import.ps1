[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $RepositoryRoot 'modules/SetupHelpers.psm1') -Force

Write-SetupStep 'Preparing StartAllBack configuration import'

$sourceRoot = Join-Path $RepositoryRoot 'configs/startallback'
$targetRoot = Join-Path $env:LOCALAPPDATA 'StartAllBack'

if (-not (Test-Path $sourceRoot)) {
    Write-SetupStep 'StartAllBack config source directory not found.'
    return
}

if (-not (Test-Path $targetRoot)) {
    Write-SetupStep 'StartAllBack target directory not found. Install StartAllBack first.'
    return
}

$filesToCopy = @(
    'settings.json',
    'theme.json'
)

foreach ($file in $filesToCopy) {
    $sourceFile = Join-Path $sourceRoot $file
    if (Test-Path $sourceFile) {
        Copy-Item -Path $sourceFile -Destination (Join-Path $targetRoot $file) -Force
        Write-SetupStep "Imported StartAllBack file: $file"
    }
}

Write-SetupStep 'StartAllBack configuration import completed.'
