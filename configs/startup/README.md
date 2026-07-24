# Startup apps configuration

This module exports and restores user startup apps in two places:

- HKCU Run entries (`startup-run-user.json`)
- Startup folder files (`startup-folder/*`)

## Notes

- Import skips unsafe Run entries if they reference missing absolute executable paths.
- Relative or PATH-based commands are allowed.
- Dry run is available by calling:

```powershell
.\configs\startup\import.ps1 -RepositoryRoot <repo-root> -DryRun
```
