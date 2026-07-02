# Changelog: ryoku-shell

## Unreleased

### Added

- Standalone no-ISO installer: `install.sh` curl bootstrap plus the
  `ryoku-shell-install` bubbletea TUI. Scans the machine, backs up configs
  with a generated `restore.sh`, removes rival quickshell shells, disables
  conflicting daemons and display managers, trusts the `[ryoku]` repo, installs
  the desktop set, wires SDDM/qylock/NetworkManager, materializes per-user
  config (salvaging the keyboard layout from a niri setup), builds the AUR
  extras, and converges with `ryoku doctor`. Headless `--yes` and `--dry-run`
  modes included.
