function Write-SetupStep {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Host "[setup] $Message" -ForegroundColor Cyan
}

function Test-CommandAvailable {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required but was not found on PATH."
    }
}

function Get-WingetCommandPath {
    $commandPath = Get-Command winget -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue
    if ($commandPath -and (Test-Path $commandPath)) {
        return $commandPath
    }

    $localWindowsAppsPath = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path $localWindowsAppsPath) {
        return $localWindowsAppsPath
    }

    $windowsAppsRoot = Join-Path $env:ProgramFiles 'WindowsApps'
    if (Test-Path $windowsAppsRoot) {
        $foundPath = Get-ChildItem -Path $windowsAppsRoot -Filter 'winget.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        if ($foundPath) {
            return $foundPath
        }
    }

    return $null
}

function Initialize-Winget {
    $wingetPath = Get-WingetCommandPath
    if ($wingetPath) {
        $wingetDirectory = Split-Path -Parent $wingetPath
        if (-not ($env:Path -split ';' | Where-Object { $_ -eq $wingetDirectory })) {
            $env:Path = "$env:Path;$wingetDirectory"
        }

        return $wingetPath
    }

    Write-SetupStep 'Winget was not found. Attempting to bootstrap it automatically.'

    $tempDir = Join-Path $env:TEMP 'winget-bootstrap'
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    $installerPath = Join-Path $tempDir 'Microsoft.DesktopAppInstaller.exe'
    $installerUrl = 'https://aka.ms/getwinget'

    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -ErrorAction Stop
        $process = Start-Process -FilePath $installerPath -ArgumentList '/silent', '/install', '/passive' -Wait -PassThru -NoNewWindow

        if ($process -and $process.ExitCode -ne 0) {
            throw "The official Winget installer exited with code $($process.ExitCode)."
        }
    }
    catch {
        throw "Winget could not be bootstrapped automatically. Install it manually or repair the package manager first. $($_.Exception.Message)"
    }

    $wingetPath = Get-WingetCommandPath
    if (-not $wingetPath) {
        throw 'Winget is still unavailable after the bootstrap attempt.'
    }

    $wingetDirectory = Split-Path -Parent $wingetPath
    if (-not ($env:Path -split ';' | Where-Object { $_ -eq $wingetDirectory })) {
        $env:Path = "$env:Path;$wingetDirectory"
    }

    return $wingetPath
}

function Import-RegistryGroup {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Test-Path $Path)) {
        Write-SetupStep "No registry file found for $Name"
        return
    }

    Write-SetupStep "Importing registry group: $Name"
    reg import $Path | Out-Null
}

Export-ModuleMember -Function Write-SetupStep, Test-CommandAvailable, Initialize-Winget, Import-RegistryGroup
