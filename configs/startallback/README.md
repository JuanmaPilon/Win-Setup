# StartAllBack configuration

This folder is intended to hold StartAllBack configuration files that can be imported on a fresh machine.

## Suggested workflow

1. Configure StartAllBack the way you want on your current machine.
2. Run the exporter from the menu or from the script directly.
3. Copy the relevant configuration files into `private-configs/startallback`.
4. Run the setup flow so these files are restored on a new machine.

## Notes

StartAllBack may store configuration in a different format depending on the version, so keep exported data under `private-configs/startallback`, which is ignored by Git.
