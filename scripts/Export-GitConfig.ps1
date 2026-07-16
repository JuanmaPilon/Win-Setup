[CmdletBinding()]
param(
    [string]$OutputRoot = 'private-configs/git'
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

$gitFiles = @(
    @{ Source = (Join-Path $HOME '.gitconfig'); Destination = 'home/.gitconfig' },
    @{ Source = (Join-Path $HOME '.config/git/config'); Destination = 'home/.config/git/config' },
    @{ Source = (Join-Path $HOME '.config/git/ignore'); Destination = 'home/.config/git/ignore' },
    @{ Source = (Join-Path $HOME '.config/git/attributes'); Destination = 'home/.config/git/attributes' }
)

$exported = 0

foreach ($item in $gitFiles) {
    if (-not (Test-Path $item.Source)) {
        continue
    }

    $destinationPath = Join-Path $resolvedOutputRoot $item.Destination
    $destinationDirectory = Split-Path -Parent $destinationPath
    if (-not (Test-Path $destinationDirectory)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    Copy-Item -Path $item.Source -Destination $destinationPath -Force
    Write-Host "Exported Git file: $($item.Destination)" -ForegroundColor Green
    $exported++
}

if ($exported -eq 0) {
    Write-Host 'No Git configuration files were found to export.' -ForegroundColor Yellow
    return
}

Write-Host "Git configuration exported to $resolvedOutputRoot" -ForegroundColor Green