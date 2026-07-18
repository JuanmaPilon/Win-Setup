[CmdletBinding()]
param(
    [string]$OutputPath = 'private-configs/backups/environment-variables.json',
    [switch]$SkipMachineVariables,
    [string[]]$UserDenyList = @(
        'TEMP', 'TMP', 'USERNAME', 'USERPROFILE', 'HOMEDRIVE', 'HOMEPATH',
        'APPDATA', 'LOCALAPPDATA', 'ONEDRIVE', 'ONEDRIVECONSUMER',
        'SESSIONNAME', 'LOGONSERVER', 'USERDOMAIN', 'USERDOMAIN_ROAMINGPROFILE'
    ),
    [string[]]$MachineDenyList = @(
        'ALLUSERSPROFILE', 'COMPUTERNAME', 'COMSPEC', 'NUMBER_OF_PROCESSORS',
        'OS', 'PATHEXT', 'PROCESSOR_ARCHITECTURE', 'PROCESSOR_IDENTIFIER',
        'PROCESSOR_LEVEL', 'PROCESSOR_REVISION', 'PROGRAMDATA', 'PROGRAMFILES',
        'PROGRAMFILES(X86)', 'PROGRAMW6432', 'SYSTEMDRIVE', 'SYSTEMROOT',
        'TEMP', 'TMP', 'USERDOMAIN', 'USERNAME', 'USERPROFILE', 'WINDIR'
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Test-NameInList {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$List
    )

    return [bool]($List | Where-Object { $_.Equals($Name, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1)
}

function Convert-ToPortableEnvValue {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value -or $Value -eq '') {
        return [pscustomobject]@{ Value = $Value; Changed = $false }
    }

    $replacements = [ordered]@{
        '%USERPROFILE%' = $env:USERPROFILE
        '%LOCALAPPDATA%' = $env:LOCALAPPDATA
        '%APPDATA%' = $env:APPDATA
        '%ProgramData%' = $env:ProgramData
        '%ProgramFiles%' = $env:ProgramFiles
        '%ProgramFiles(x86)%' = ${env:ProgramFiles(x86)}
        '%SystemRoot%' = $env:SystemRoot
    }

    $portableValue = $Value
    $changed = $false

    $replacementKeys = $replacements.Keys | Sort-Object { $replacements[$_].Length } -Descending
    foreach ($token in $replacementKeys) {
        $sourcePath = $replacements[$token]
        if ([string]::IsNullOrWhiteSpace($sourcePath)) {
            continue
        }

        if ($portableValue -imatch [regex]::Escape($sourcePath)) {
            $portableValue = [regex]::Replace($portableValue, [regex]::Escape($sourcePath), [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $token }, 'IgnoreCase')
            $changed = $true
        }
    }

    return [pscustomobject]@{ Value = $portableValue; Changed = $changed }
}

function Get-EnvironmentVariableMap {
    param(
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string[]]$DenyList
    )

    $values = [System.Environment]::GetEnvironmentVariables($Target)
    $map = [ordered]@{}
    $exportedCount = 0
    $skippedCount = 0
    $normalizedCount = 0

    foreach ($key in $values.Keys | Sort-Object) {
        $name = [string]$key
        if ($name.StartsWith('=')) {
            $skippedCount++
            continue
        }

        if (Test-NameInList -Name $name -List $DenyList) {
            $skippedCount++
            continue
        }

        $portable = Convert-ToPortableEnvValue -Value ([string]$values[$key])
        if ($portable.Changed) {
            $normalizedCount++
        }

        $map[$name] = $portable.Value
        $exportedCount++
    }

    return [pscustomobject]@{
        Variables = $map
        ExportedCount = $exportedCount
        SkippedCount = $skippedCount
        NormalizedCount = $normalizedCount
    }
}

$userExport = Get-EnvironmentVariableMap -Target 'User' -DenyList $UserDenyList
$machineExport = if ($SkipMachineVariables) {
    [pscustomobject]@{ Variables = [ordered]@{}; ExportedCount = 0; SkippedCount = 0; NormalizedCount = 0 }
}
else {
    Get-EnvironmentVariableMap -Target 'Machine' -DenyList $MachineDenyList
}

$data = [ordered]@{
    formatVersion = 2
    exportedAt = (Get-Date).ToString('o')
    exportedFromComputer = $env:COMPUTERNAME
    exportedByUser = $env:USERNAME
    policy = [ordered]@{
        skipMachineVariables = [bool]$SkipMachineVariables
        userDenyList = $UserDenyList
        machineDenyList = $MachineDenyList
    }
    user = $userExport.Variables
    machine = $machineExport.Variables
}

if ([System.IO.Path]::IsPathRooted($OutputPath)) {
    $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
}
else {
    $resolvedOutputPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutputPath))
}

$parent = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}

$data | ConvertTo-Json -Depth 5 | Set-Content -Path $resolvedOutputPath -Encoding UTF8
Write-Host "Environment variables exported to $resolvedOutputPath" -ForegroundColor Green
Write-Host "User vars exported: $($userExport.ExportedCount) | skipped: $($userExport.SkippedCount) | normalized: $($userExport.NormalizedCount)" -ForegroundColor Cyan
Write-Host "Machine vars exported: $($machineExport.ExportedCount) | skipped: $($machineExport.SkippedCount) | normalized: $($machineExport.NormalizedCount)" -ForegroundColor Cyan
