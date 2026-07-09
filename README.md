# Windows Setup

This repository is a personal Windows infrastructure-as-code starter for reproducible setup on fresh Windows 11 installations.

## Goals

- Keep the setup idempotent whenever practical.
- Prefer official Microsoft tooling such as PowerShell, Winget, and supported APIs.
- Keep the repository modular and easy to maintain.
- Avoid registry hacks unless there is no supported alternative.

## Repository layout

- apps/: application manifests and Winget package lists
- configs/: application configuration backups and import hooks
- registry/: grouped registry files for exceptional changes
- scripts/: focused PowerShell scripts for setup stages
- modules/: reusable PowerShell helper functions
- docs/: documentation for maintenance and decisions
- backups/: exported settings that are not ideal for version control

## Quick start

1. Install Git for Windows.
2. Clone this repository.
3. Open PowerShell in the repository root.
4. Run:

   ```powershell
   .\Setup.ps1
   ```

## Notes

The initial implementation is intentionally small and modular. Each script has a focused responsibility so the setup process can grow over time without becoming brittle.
