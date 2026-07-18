[CmdletBinding()]
param(
    [string]$OutputRoot = 'private-configs/windows-ui',
    [switch]$IncludeExplorerAdvanced
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

if ($IncludeExplorerAdvanced) {
    Export-RegistryKey -KeyPath 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -DestinationFile (Join-Path $resolvedOutputRoot 'Explorer-Advanced.reg') -Description 'Explorer advanced settings'
}

Write-Host "Windows UI configuration exported to $resolvedOutputRoot" -ForegroundColor Green