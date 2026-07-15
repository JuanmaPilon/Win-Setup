[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $RepositoryRoot 'modules/SetupHelpers.psm1') -Force

Write-SetupStep 'Scanning configuration import scripts'
$configsRoot = Join-Path $RepositoryRoot 'configs'
$importScripts = Get-ChildItem -Path $configsRoot -Filter 'import.ps1' -Recurse -File -ErrorAction SilentlyContinue

if (-not $importScripts) {
    Write-SetupStep 'No configuration import scripts were found.'
    return
}

foreach ($importScript in $importScripts) {
    Write-SetupStep "Running import script: $($importScript.FullName)"
    try {
        & $importScript.FullName -RepositoryRoot $RepositoryRoot
    }
    catch {
        Write-SetupWarning "Import script failed: $($_.Exception.Message)"
        Write-SetupWarning "Continuing with the next import script."
    }
}

Write-SetupStep 'Configuration import stage completed.'
