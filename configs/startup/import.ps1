[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepositoryRoot,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Import-Module (Join-Path $RepositoryRoot 'modules/SetupHelpers.psm1') -Force

Write-SetupStep 'Preparing startup apps import'

$privateSourceRoot = Join-Path $RepositoryRoot 'private-configs/startup'
$publicSourceRoot = Join-Path $RepositoryRoot 'configs/startup'
$sourceRoot = if (Test-Path $privateSourceRoot) { $privateSourceRoot } else { $publicSourceRoot }

if (-not (Test-Path $sourceRoot)) {
    Write-SetupWarning 'Startup config source directory not found.'
    return
}

if ($DryRun) {
    Write-SetupWarning 'Dry run mode enabled: startup entries will not be modified.'
}

function Get-StartupCommandExecutablePath {
    param([string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $null
    }

    $expanded = [Environment]::ExpandEnvironmentVariables($Command.Trim())

    if ($expanded.StartsWith('"')) {
        $quoteEnd = $expanded.IndexOf('"', 1)
        if ($quoteEnd -gt 1) {
            return $expanded.Substring(1, $quoteEnd - 1)
        }
    }

    $pathWithExtensionMatch = [regex]::Match($expanded, '^(?<path>[A-Za-z]:\\.*?\.(exe|com|bat|cmd|lnk|msc))(?=\s|$)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($pathWithExtensionMatch.Success) {
        return $pathWithExtensionMatch.Groups['path'].Value
    }

    $firstToken = ($expanded -split '\s+', 2)[0]
    return $firstToken.Trim('"')
}

function Test-IsSafeStartupCommand {
    param([string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return [pscustomobject]@{ IsSafe = $false; Reason = 'Command is empty.' }
    }

    $exePath = Get-StartupCommandExecutablePath -Command $Command
    if ([string]::IsNullOrWhiteSpace($exePath)) {
        return [pscustomobject]@{ IsSafe = $false; Reason = 'Could not resolve executable path.' }
    }

    if ($exePath -match '^[A-Za-z]:\\') {
        if (-not (Test-Path $exePath)) {
            return [pscustomobject]@{ IsSafe = $false; Reason = "Executable path does not exist: $exePath" }
        }
    }

    return [pscustomobject]@{ IsSafe = $true; Reason = $null }
}

$runEntriesPath = Join-Path $sourceRoot 'startup-run-user.json'
$runImported = 0
$runSkipped = 0
$runUnsafe = 0

if (Test-Path $runEntriesPath) {
    try {
        $runEntries = Get-Content -Path $runEntriesPath -Raw | ConvertFrom-Json
    }
    catch {
        Write-SetupWarning "Could not parse startup run entries file: $($_.Exception.Message)"
        $runEntries = @()
    }

    $runKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    if (-not (Test-Path $runKeyPath)) {
        New-Item -Path $runKeyPath -Force | Out-Null
    }

    foreach ($entry in $runEntries) {
        $name = [string]$entry.Name
        $command = [string]$entry.Command

        if ([string]::IsNullOrWhiteSpace($name)) {
            $runSkipped++
            continue
        }

        $safety = Test-IsSafeStartupCommand -Command $command
        if (-not $safety.IsSafe) {
            Write-SetupWarning "Skipping startup run entry '$name': $($safety.Reason)"
            $runUnsafe++
            continue
        }

        $currentValue = (Get-ItemProperty -Path $runKeyPath -Name $name -ErrorAction SilentlyContinue).$name
        if (($currentValue -as [string]) -ceq $command) {
            Write-SetupInfo "Startup run entry '$name' already up to date."
            $runSkipped++
            continue
        }

        if ($DryRun) {
            Write-SetupInfo "[DryRun] Would set startup run entry '$name'."
            $runImported++
            continue
        }

        try {
            Set-ItemProperty -Path $runKeyPath -Name $name -Value $command -Type String
            Write-SetupSuccess "Imported startup run entry: $name"
            $runImported++
        }
        catch {
            Write-SetupWarning "Failed to import startup run entry '$name': $($_.Exception.Message)"
            $runSkipped++
        }
    }
}
else {
    Write-SetupInfo 'No startup-run-user.json found; skipping startup run entries.'
}

$startupFolderSource = Join-Path $sourceRoot 'startup-folder'
$startupFolderTarget = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$folderImported = 0
$folderSkipped = 0

if (Test-Path $startupFolderSource) {
    if (-not (Test-Path $startupFolderTarget)) {
        New-Item -ItemType Directory -Path $startupFolderTarget -Force | Out-Null
    }

    $files = Get-ChildItem -Path $startupFolderSource -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $destination = Join-Path $startupFolderTarget $file.Name
        if ((Test-Path $destination) -and ((Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash -eq (Get-FileHash -Algorithm SHA256 -Path $destination).Hash)) {
            Write-SetupInfo "Startup folder file '$($file.Name)' already up to date."
            $folderSkipped++
            continue
        }

        if ($DryRun) {
            Write-SetupInfo "[DryRun] Would copy startup folder file '$($file.Name)'."
            $folderImported++
            continue
        }

        try {
            Copy-Item -Path $file.FullName -Destination $destination -Force
            Write-SetupSuccess "Imported startup folder file: $($file.Name)"
            $folderImported++
        }
        catch {
            Write-SetupWarning "Failed to import startup folder file '$($file.Name)': $($_.Exception.Message)"
            $folderSkipped++
        }
    }
}
else {
    Write-SetupInfo 'No startup-folder backup found; skipping startup folder files.'
}

Write-SetupSuccess "Startup run summary -> imported/updated: $runImported, skipped: $runSkipped, unsafe: $runUnsafe"
Write-SetupSuccess "Startup folder summary -> imported/updated: $folderImported, skipped: $folderSkipped"
Write-SetupSuccess 'Startup apps import completed.'