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

$filesToCopy = Get-ChildItem -Path $configSource -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'settings|config|json|xml|ini|theme' }

foreach ($sourceFile in $filesToCopy) {
    $relativePath = $sourceFile.FullName.Substring($configSource.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $destinationPath = Join-Path $powertoysConfigPath $relativePath
    $destinationDirectory = Split-Path -Parent $destinationPath

    if (-not (Test-Path $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    Copy-Item -Path $sourceFile.FullName -Destination $destinationPath -Force
    Write-SetupStep "Imported PowerToys file: $relativePath"
}

Write-SetupStep 'PowerToys configuration import completed.'
