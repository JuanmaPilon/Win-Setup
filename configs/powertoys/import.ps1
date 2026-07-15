[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

try {
    Import-Module (Join-Path $RepositoryRoot 'modules/SetupHelpers.psm1') -Force
}
catch {
    Write-Host "[error] Failed to import SetupHelpers module: $_" -ForegroundColor Red
    return
}

Write-SetupStep 'Preparing PowerToys configuration import'

$configSource = Join-Path $RepositoryRoot 'configs/powertoys'
$powertoysConfigPath = Join-Path $env:LOCALAPPDATA 'Microsoft/PowerToys'

if (-not (Test-Path $configSource)) {
    Write-SetupWarning 'PowerToys config source directory not found.'
    return
}

if (-not (Test-Path $powertoysConfigPath)) {
    Write-SetupWarning 'PowerToys is not installed yet or its config folder is missing.'
    return
}

$filesToCopy = Get-ChildItem -Path $configSource -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -notin @('import.ps1', 'README.md')
    }

if (-not $filesToCopy) {
    Write-SetupWarning 'No PowerToys configuration files were found to import.'
    return
}

foreach ($sourceFile in $filesToCopy) {
    $relativePath = $sourceFile.FullName.Substring($configSource.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $destinationPath = Join-Path $powertoysConfigPath $relativePath
    $destinationDirectory = Split-Path -Parent $destinationPath

    try {
        if (-not (Test-Path $destinationDirectory)) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        }

        Copy-Item -Path $sourceFile.FullName -Destination $destinationPath -Force
        Write-SetupInfo "Imported PowerToys file: $relativePath"
    }
    catch {
        Write-SetupWarning "Failed to import PowerToys file '$relativePath': $($_.Exception.Message)"
    }
}

Write-SetupSuccess 'PowerToys configuration import completed.'
