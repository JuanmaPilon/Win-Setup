[CmdletBinding()]
param(
    [string]$OutputRoot = 'private-configs/windows-ui',
    [switch]$IncludeExplorerAdvanced,
    [switch]$IncludeQuickAccessPins
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

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

function Export-RegistryKey {
    param(
        [Parameter(Mandatory = $true)][string]$KeyPath,
        [Parameter(Mandatory = $true)][string]$DestinationFile,
        [Parameter(Mandatory = $true)][string]$Description
    )

    try {
        reg export $KeyPath $DestinationFile /y | Out-Null
        Write-Host "Exported $Description" -ForegroundColor Green
    }
    catch {
        Write-Host "Could not export $Description ($KeyPath)." -ForegroundColor Yellow
    }
}

Export-RegistryKey -KeyPath 'HKCU\Control Panel\Mouse' -DestinationFile (Join-Path $resolvedOutputRoot 'Mouse.reg') -Description 'mouse settings'
Export-RegistryKey -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -DestinationFile (Join-Path $resolvedOutputRoot 'Theme-Personalize.reg') -Description 'theme personalization settings'
Export-RegistryKey -KeyPath 'HKCU\Control Panel\NotifyIconSettings' -DestinationFile (Join-Path $resolvedOutputRoot 'NotifyIconSettings.reg') -Description 'notification area icon visibility settings'
Export-RegistryKey -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' -DestinationFile (Join-Path $resolvedOutputRoot 'Desktop-Icons-NewStartPanel.reg') -Description 'desktop icon visibility settings (NewStartPanel)'
Export-RegistryKey -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\ClassicStartMenu' -DestinationFile (Join-Path $resolvedOutputRoot 'Desktop-Icons-ClassicStartMenu.reg') -Description 'desktop icon visibility settings (ClassicStartMenu)'

if ($IncludeExplorerAdvanced) {
    Export-RegistryKey -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -DestinationFile (Join-Path $resolvedOutputRoot 'Explorer-Advanced.reg') -Description 'Explorer advanced settings'
}

if ($IncludeQuickAccessPins) {
    $quickAccessSource = Join-Path $env:APPDATA 'Microsoft\Windows\Recent\AutomaticDestinations\f01b4d95cf55d32a.automaticDestinations-ms'
    $quickAccessDestinationRoot = Join-Path $resolvedOutputRoot 'quick-access'
    $quickAccessDestination = Join-Path $quickAccessDestinationRoot 'f01b4d95cf55d32a.automaticDestinations-ms'

    if (Test-Path $quickAccessSource) {
        if (-not (Test-Path $quickAccessDestinationRoot)) {
            New-Item -ItemType Directory -Path $quickAccessDestinationRoot -Force | Out-Null
        }

        Copy-Item -Path $quickAccessSource -Destination $quickAccessDestination -Force
        Write-Host 'Exported Quick Access pinned folders database.' -ForegroundColor Green
    }
    else {
        Write-Host 'Quick Access pinned folders database was not found.' -ForegroundColor Yellow
    }
}

Write-Host "Windows UI configuration exported to $resolvedOutputRoot" -ForegroundColor Green