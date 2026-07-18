# Windows UI configuration

This folder restores baseline Windows UI preferences that are usually portable between machines.

## Current coverage

- Mouse settings (`HKCU\Control Panel\Mouse`), including pointer precision behavior.
- Theme personalization (`HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize`), including light/dark mode.
- Notification area icon visibility (`HKCU\Control Panel\NotifyIconSettings`), including tray icon show/hide preferences.
- Desktop icon visibility (`HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\...`), including Recycle Bin show/hide.
- Optional Explorer advanced settings (`HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced`) when exported with `-IncludeExplorerAdvanced`.
- Optional Quick Access pinned folders database when exported with `-IncludeQuickAccessPins`.

## Suggested workflow

1. Configure mouse and theme preferences on your main machine.
2. Run `scripts/Export-WindowsUI.ps1` (optionally with `-IncludeExplorerAdvanced -IncludeQuickAccessPins`).
3. Keep the export in `private-configs/windows-ui`.
4. Run setup/import on the target machine.

## Notes

Quick Access pins can include folders that do not exist on the target machine. If some pinned entries look broken after import, remove those entries and pin valid local paths.
