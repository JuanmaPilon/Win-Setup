# Windows UI configuration

This folder restores baseline Windows UI preferences that are usually portable between machines.

## Current coverage

- Mouse settings (`HKCU\Control Panel\Mouse`), including pointer precision behavior.
- Theme personalization (`HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`), including light/dark mode.
- Optional Explorer advanced settings (`HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`) when exported with `-IncludeExplorerAdvanced`.

## Suggested workflow

1. Configure mouse and theme preferences on your main machine.
2. Run `scripts/Export-WindowsUI.ps1` (optionally with `-IncludeExplorerAdvanced`).
3. Keep the export in `private-configs/windows-ui`.
4. Run setup/import on the target machine.
