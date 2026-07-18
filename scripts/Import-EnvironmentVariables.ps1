[CmdletBinding()]
param(
    [string]$InputPath = 'private-configs/backups/environment-variables.json',
    [switch]$DryRun,
    [switch]$SkipMachineVariables,
    [string[]]$UserAllowList = @(),
    [string[]]$MachineAllowList = @(),
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
$ErrorActionPreference = 'Continue'

$repoRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoRoot 'modules/SetupHelpers.psm1') -Force

if ([System.IO.Path]::IsPathRooted($InputPath)) {
    $resolvedInputPath = [System.IO.Path]::GetFullPath($InputPath)
}
else {
    $resolvedInputPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $InputPath))
}

$legacyPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'backups/environment-variables.json'))
if (-not (Test-Path $resolvedInputPath) -and (Test-Path $legacyPath)) {
    $resolvedInputPath = $legacyPath
}

if (-not (Test-Path $resolvedInputPath)) {
    Write-SetupError "Environment variable backup not found: $resolvedInputPath"
    return
}

try {
    $data = Get-Content -Path $resolvedInputPath -Raw | ConvertFrom-Json
}
catch {
    Write-SetupError "Failed to parse environment variables backup: $($_.Exception.Message)"
    return
}

if ($DryRun) {
    Write-SetupWarning 'Dry run mode enabled: no environment variables will be modified.'
}

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

    $currentUser = [System.Environment]::GetEnvironmentVariable('USERNAME', 'User')
    if ([string]::IsNullOrWhiteSpace($currentUser)) {
        $currentUser = $env:USERNAME
    }

    $segments = @($Value -split ';')
    $changed = $false
    $resultSegments = @()

    foreach ($segment in $segments) {
        $trimmedSegment = $segment.Trim()
        $newSegment = $trimmedSegment

        if ($trimmedSegment -match '^(?<drive>[A-Za-z]:)\\Users\\(?<user>[^\\]+)(?<rest>(\\.*)?)$') {
            $matchedUser = $Matches['user']
            $rest = $Matches['rest']

            if (-not $matchedUser.Equals($currentUser, [System.StringComparison]::OrdinalIgnoreCase)) {
                $newSegment = "%USERPROFILE%$rest"
                $changed = $true
            }
        }

        $resultSegments += $newSegment
    }

    return [pscustomobject]@{
        Value = ($resultSegments -join ';')
        Changed = $changed
    }
}

function Test-UnsafeValue {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [AllowNull()][string]$Value
    )

    if ($null -eq $Value -or $Value -eq '') {
        return $null
    }

    $currentUser = [System.Environment]::GetEnvironmentVariable('USERNAME', 'User')
    if ([string]::IsNullOrWhiteSpace($currentUser)) {
        $currentUser = $env:USERNAME
    }

    $userPathMatches = [regex]::Matches($Value, '[A-Za-z]:\\Users\\(?<user>[^\\;]+)')
    foreach ($match in $userPathMatches) {
        $capturedUser = $match.Groups['user'].Value
        if (-not $capturedUser.Equals($currentUser, [System.StringComparison]::OrdinalIgnoreCase)) {
            return "Contains absolute path tied to another user profile ($capturedUser)."
        }
    }

    return $null
}

function Get-AbsolutePathSegments {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value -or $Value -eq '') {
        return @()
    }

    $segments = @($Value -split ';')
    $absolutePaths = @()
    foreach ($segment in $segments) {
        $trimmed = $segment.Trim().Trim('"')
        if ($trimmed -match '^[A-Za-z]:\\') {
            $absolutePaths += $trimmed
        }
    }

    return $absolutePaths
}

function Import-EnvironmentVariableSet {
    param(
        [Parameter(Mandatory = $true)]$Entries,
        [Parameter(Mandatory = $true)][string]$Target,
        [Parameter(Mandatory = $true)][string[]]$DenyList,
        [string[]]$AllowList = @()
    )

    $imported = 0
    $updated = 0
    $skipped = 0
    $unsafe = 0
    $transformed = 0

    if (-not $Entries) {
        return [pscustomobject]@{
            Imported = 0
            Updated = 0
            Skipped = 0
            Unsafe = 0
            Transformed = 0
        }
    }

    foreach ($entry in $Entries.PSObject.Properties) {
        $name = [string]$entry.Name
        $originalValue = if ($null -eq $entry.Value) { '' } else { [string]$entry.Value }

        if ($name.StartsWith('=')) {
            $skipped++
            continue
        }

        if (($null -ne $AllowList) -and ($AllowList.Count -gt 0) -and -not (Test-NameInList -Name $name -List $AllowList)) {
            Write-SetupInfo "Skipping $Target variable '$name' (not in allowlist)."
            $skipped++
            continue
        }

        if (Test-NameInList -Name $name -List $DenyList) {
            Write-SetupInfo "Skipping $Target variable '$name' (managed by Windows / denylist)."
            $skipped++
            continue
        }

        $portable = Convert-ToPortableEnvValue -Value $originalValue
        $candidateValue = $portable.Value
        if ($portable.Changed) {
            $transformed++
            Write-SetupInfo "Transformed $Target variable '$name' to portable profile tokens."
        }

        $unsafeReason = Test-UnsafeValue -Name $name -Value $candidateValue
        if ($unsafeReason) {
            Write-SetupWarning "Skipping unsafe $Target variable '$name': $unsafeReason"
            $unsafe++
            continue
        }

        $nonExistingPathCount = 0
        $absolutePaths = Get-AbsolutePathSegments -Value $candidateValue
        foreach ($pathCandidate in $absolutePaths) {
            if (-not (Test-Path $pathCandidate)) {
                $nonExistingPathCount++
            }
        }

        if ($nonExistingPathCount -gt 0) {
            Write-SetupWarning "$Target variable '$name' contains $nonExistingPathCount non-existing absolute path segment(s)."
        }

        $existingValue = [Environment]::GetEnvironmentVariable($name, $Target)
        if (($existingValue -as [string]) -ceq $candidateValue) {
            Write-SetupInfo "Skipping $Target variable '$name' (already up to date)."
            $skipped++
            continue
        }

        if ($DryRun) {
            Write-SetupInfo "[DryRun] Would set $Target variable '$name'."
            $updated++
            continue
        }

        try {
            [Environment]::SetEnvironmentVariable($name, $candidateValue, $Target)
            Write-SetupSuccess "Imported $Target variable '$name'."
            $imported++
            $updated++
        }
        catch {
            Write-SetupWarning "Could not import $Target variable '$name': $($_.Exception.Message)"
            $skipped++
        }
    }

    return [pscustomobject]@{
        Imported = $imported
        Updated = $updated
        Skipped = $skipped
        Unsafe = $unsafe
        Transformed = $transformed
    }
}

$userStats = Import-EnvironmentVariableSet -Entries $data.user -Target 'User' -DenyList $UserDenyList -AllowList $UserAllowList

$machineStats = if ($SkipMachineVariables) {
    Write-SetupInfo 'Skipping machine variables by request.'
    [pscustomobject]@{ Imported = 0; Updated = 0; Skipped = 0; Unsafe = 0; Transformed = 0 }
}
else {
    Import-EnvironmentVariableSet -Entries $data.machine -Target 'Machine' -DenyList $MachineDenyList -AllowList $MachineAllowList
}

Write-SetupSuccess "User env summary -> updated: $($userStats.Updated), imported: $($userStats.Imported), transformed: $($userStats.Transformed), skipped: $($userStats.Skipped), unsafe: $($userStats.Unsafe)"
Write-SetupSuccess "Machine env summary -> updated: $($machineStats.Updated), imported: $($machineStats.Imported), transformed: $($machineStats.Transformed), skipped: $($machineStats.Skipped), unsafe: $($machineStats.Unsafe)"

if (-not $SkipMachineVariables) {
    Write-SetupWarning 'Machine-level values may require an elevated PowerShell session.'
}
