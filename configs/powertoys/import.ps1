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

$privateConfigSource = Join-Path $RepositoryRoot 'private-configs/powertoys'
$publicConfigSource = Join-Path $RepositoryRoot 'configs/powertoys'
$configSource = if (Test-Path $privateConfigSource) { $privateConfigSource } else { $publicConfigSource }
$powertoysConfigPath = Join-Path $env:LOCALAPPDATA 'Microsoft/PowerToys'

if (-not (Test-Path $configSource)) {
    Write-SetupWarning 'PowerToys config source directory not found.'
    return
}

if (-not (Test-Path $powertoysConfigPath)) {
    Write-SetupWarning 'PowerToys is not installed yet or its config folder is missing.'
    return
}

Get-Process -Name 'PowerToys' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name 'PowerToys.Settings' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

function Test-ShouldImportPowerToysFile {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    $normalizedPath = $RelativePath -replace '\\', '/'

    if ($normalizedPath -match '(^|/)Logs(/|$)' -or $normalizedPath -match '(^|/)RunnerLogs(/|$)' -or $normalizedPath -match '(^|/)UpdateLogs(/|$)' -or $normalizedPath -match '(^|/)Updates(/|$)') {
        return $false
    }

    if ($normalizedPath -match '\.(log|tmp|bak|lock)$') {
        return $false
    }

    switch ($RelativePath) {
        'last_version_run.json' { return $false }
        'log_settings.json' { return $false }
        'oobe_settings.json' { return $false }
        'settings-telemetry.json' { return $false }
        'UpdateState.json' { return $false }
        'settings-placement.json' { return $false }
        'README.md' { return $false }
        'import.ps1' { return $false }
    }

    return $true
}

$filesToCopy = Get-ChildItem -Path $configSource -Recurse -File -ErrorAction SilentlyContinue |
    ForEach-Object {
        $relativePath = $_.FullName.Substring($configSource.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        if (Test-ShouldImportPowerToysFile -RelativePath $relativePath) {
            $_
        }
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

try {
    Start-Process (Join-Path $powertoysConfigPath 'PowerToys.exe') | Out-Null
    Write-SetupSuccess 'Restarted PowerToys to apply restored settings.'
}
catch {
    Write-SetupWarning 'Could not restart PowerToys automatically. Start it manually if needed.'
}

Write-SetupSuccess 'PowerToys configuration import completed.'
