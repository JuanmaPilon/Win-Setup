[CmdletBinding()]
param(
    [string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDirectory = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$repoRoot = Split-Path -Parent $scriptDirectory

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = 'configs/startallback'
}

$resolvedOutputRoot = if ([System.IO.Path]::IsPathRooted($OutputRoot)) {
    [System.IO.Path]::GetFullPath($OutputRoot)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputRoot))
}

$candidatePaths = @(
    (Join-Path $env:LOCALAPPDATA 'StartAllBack'),
    (Join-Path $env:LOCALAPPDATA 'Programs\StartAllBack'),
    (Join-Path $env:PROGRAMFILES 'StartAllBack'),
    (Join-Path $env:PROGRAMFILES 'StartAllBack\Themes'),
    (Join-Path $env:APPDATA 'StartAllBack'),
    (Join-Path $env:APPDATA 'Programs\StartAllBack')
)

$sourceRoot = $null
foreach ($candidate in $candidatePaths) {
    if (Test-Path $candidate) {
        $sourceRoot = $candidate
        break
    }
}

if (-not $sourceRoot) {
    Write-Host 'StartAllBack configuration directory not found in the usual locations.' -ForegroundColor Yellow
    return
}

if (-not (Test-Path $resolvedOutputRoot)) {
    New-Item -ItemType Directory -Path $resolvedOutputRoot -Force | Out-Null
}

$filesToExport = Get-ChildItem -Path $sourceRoot -Recurse -File | Where-Object { $_.Name -match 'settings|theme|config|json|xml|ini' } | Select-Object -ExpandProperty FullName

if (-not $filesToExport) {
    Write-Host "No StartAllBack configuration files were found in $sourceRoot" -ForegroundColor Yellow
    return
}

foreach ($sourceFile in $filesToExport) {
    $relativePath = $sourceFile.Substring($sourceRoot.Length).TrimStart([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $destinationPath = Join-Path $resolvedOutputRoot $relativePath
    $destinationDirectory = Split-Path -Parent $destinationPath
    if (-not (Test-Path $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    Copy-Item -Path $sourceFile -Destination $destinationPath -Force
    Write-Host "Exported StartAllBack file: $relativePath" -ForegroundColor Green
}

foreach ($file in $filesToExport) {
    $sourceFile = Join-Path $sourceRoot $file
    if (Test-Path $sourceFile) {
        Copy-Item -Path $sourceFile -Destination (Join-Path $resolvedOutputRoot $file) -Force
        Write-Host "Exported StartAllBack file: $file" -ForegroundColor Green
    }
}

Write-Host "StartAllBack configuration exported to $resolvedOutputRoot" -ForegroundColor Green
