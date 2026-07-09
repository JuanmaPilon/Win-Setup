function Write-SetupStep {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Host "[setup] $Message" -ForegroundColor Cyan
}

function Assert-CommandAvailable {
    param([Parameter(Mandatory = $true)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "$Name is required but was not found on PATH."
    }
}

function Ensure-WingetAvailable {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        return
    }

    Write-SetupStep 'Winget was not found. Attempting to bootstrap it automatically.'

    try {
        if (-not (Get-Module -ListAvailable -Name 'Microsoft.WinGet.Client')) {
            Install-PackageProvider -Name NuGet -Force | Out-Null
            Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -Scope CurrentUser
        }

        Import-Module Microsoft.WinGet.Client -Force
        Repair-WinGetPackageManager -Force -Latest
    }
    catch {
        throw "Winget could not be bootstrapped automatically. Install it manually or repair the package manager first. $($_.Exception.Message)"
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'Winget is still unavailable after the bootstrap attempt.'
    }
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

Export-ModuleMember -Function Write-SetupStep, Assert-CommandAvailable, Ensure-WingetAvailable, Import-RegistryGroup
