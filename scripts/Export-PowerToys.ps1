[CmdletBinding()]
param(
    [string]$OutputRoot = 'configs/powertoys'
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

$candidatePaths = @(
    (Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys'),
    (Join-Path $env:APPDATA 'Microsoft\PowerToys'),
    (Join-Path $env:LOCALAPPDATA 'PowerToys')
)

$sourceRoot = $null
foreach ($candidate in $candidatePaths) {
    if (Test-Path $candidate) {
        $sourceRoot = $candidate
        break
    }
}

if (-not $sourceRoot) {
    Write-Host 'PowerToys configuration directory not found in the usual locations.' -ForegroundColor Yellow
    return
}

if (-not (Test-Path $resolvedOutputRoot)) {
    New-Item -ItemType Directory -Path $resolvedOutputRoot -Force | Out-Null
}

Get-Process -Name 'PowerToys' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name 'PowerToys.Settings' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

$filesToExport = Get-ChildItem -Path $sourceRoot -Recurse -File -ErrorAction SilentlyContinue
if (-not $filesToExport) {
    Write-Host "No PowerToys configuration files were found in $sourceRoot" -ForegroundColor Yellow
    return
}

foreach ($sourceFile in $filesToExport) {
    $relativePath = $sourceFile.FullName.Substring($sourceRoot.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $destinationPath = Join-Path $resolvedOutputRoot $relativePath
    $destinationDirectory = Split-Path -Parent $destinationPath
    if (-not (Test-Path $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    Copy-Item -Path $sourceFile.FullName -Destination $destinationPath -Force
    Write-Host "Exported PowerToys file: $relativePath" -ForegroundColor Green
}

Write-Host "PowerToys configuration exported to $resolvedOutputRoot" -ForegroundColor Green
