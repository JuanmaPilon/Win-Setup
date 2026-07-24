[CmdletBinding()]
param(
    [string]$OutputRoot = 'private-configs/startup'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$repoRoot = Split-Path -Parent $scriptDirectory

$resolvedOutputRoot = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
    [System.IO.Path]::GetFullPath($OutputRoot)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputRoot))
}

if (-not (Test-Path $resolvedOutputRoot)) {
    New-Item -ItemType Directory -Path $resolvedOutputRoot -Force | Out-Null
}

$runKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runEntries = @()

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

function Test-IsExportableStartupCommand {
    param([string]$Command)

    if ([string]::IsNullOrWhiteSpace($Command)) {
        return $false
    }

    $exePath = Get-StartupCommandExecutablePath -Command $Command
    if ([string]::IsNullOrWhiteSpace($exePath)) {
        return $false
    }

    if ($exePath -match '^[A-Za-z]:\\') {
        return (Test-Path $exePath)
    }

    return $true
}

$skippedStale = 0

if (Test-Path $runKeyPath) {
    $runProps = Get-ItemProperty -Path $runKeyPath
    foreach ($prop in $runProps.PSObject.Properties) {
        if ($prop.Name -in @('PSPath', 'PSParentPath', 'PSChildName', 'PSDrive', 'PSProvider')) {
            continue
        }

        $command = [string]$prop.Value
        if (-not (Test-IsExportableStartupCommand -Command $command)) {
            Write-Host "Skipping stale startup run entry: $($prop.Name)" -ForegroundColor Yellow
            $skippedStale++
            continue
        }

        $runEntries += [pscustomobject]@{
            Name = [string]$prop.Name
            Command = $command
        }
    }
}

$runEntriesPath = Join-Path $resolvedOutputRoot 'startup-run-user.json'
$runEntries | Sort-Object Name | ConvertTo-Json -Depth 4 | Set-Content -Path $runEntriesPath -Encoding UTF8
Write-Host "Exported startup run entries: $($runEntries.Count)" -ForegroundColor Green
Write-Host "Skipped stale startup run entries: $skippedStale" -ForegroundColor Cyan

$startupFolder = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupBackupRoot = Join-Path $resolvedOutputRoot 'startup-folder'

if (Test-Path $startupFolder) {
    if (-not (Test-Path $startupBackupRoot)) {
        New-Item -ItemType Directory -Path $startupBackupRoot -Force | Out-Null
    }

    $files = Get-ChildItem -Path $startupFolder -File -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        Copy-Item -Path $file.FullName -Destination (Join-Path $startupBackupRoot $file.Name) -Force
        Write-Host "Exported startup folder file: $($file.Name)" -ForegroundColor Green
    }
}
else {
    Write-Host 'Startup folder path not found for current user.' -ForegroundColor Yellow
}

Write-Host "Startup configuration exported to $resolvedOutputRoot" -ForegroundColor Green