# PowerToys configuration

This folder is intended to hold PowerToys configuration files that can be imported on a fresh machine.

## Suggested workflow

1. Configure PowerToys the way you want on your current machine.
2. Run the exporter from the menu or from the script directly.
3. Keep the resulting files in `private-configs/powertoys`.
4. Run the setup flow so these files are restored on a new machine.

## Notes

PowerToys may store configuration in different files depending on the version and the modules enabled. Keep sensitive exports under `private-configs/powertoys`, which is ignored by Git.

The exporter also captures official PowerToys backup files (`*.ptb`) from `Documents/PowerToys/Backup` into `private-configs/powertoys/ptb-backup`. During import, those `.ptb` files are restored to the target machine's `Documents/PowerToys/Backup` path.

To improve fidelity for Command Palette and launcher/plugin behavior, the exporter also captures `backup_restore_settings.json` files from `%LOCALAPPDATA%/PowerToys` into `private-configs/powertoys/runtime-backup`, and the importer restores them back to `%LOCALAPPDATA%/PowerToys`.
