# Changelog: lockscreen/

## Unreleased

### Added
- Vendored the qylock clockwork theme (orbital and tape variants) and the
  Quickshell lockscreen under `qylock/`, trimmed to only what Ryoku ships.
- Per-skin `preview.gif` for the Lockscreen section in Ryoku Settings: orbital
  reuses qylock's own clockwork preview (its dark-mode segment, to match the
  shipped `themeMode=dark`); tape is rendered from the skin itself. They deploy
  inside the themes dir, and `ryoku-hub lock list` reports their paths.
- `install-qylock`: offline installer for the SDDM greeter (orbital) and the
  in-session lock. Writes `/etc/sddm.conf.d/99-ryoku.conf` (Current=orbital),
  installs the Quickshell lockscreen to the user's home, links `themes_link`,
  and sets `~/.config/qylock/theme`. Resolves the login user under sudo and
  pkexec. Honors `RYOKU_DRYRUN=1` and `--dry-run`.
- `sddm/setup`: install-time SDDM wiring (enable sddm.service, default to
  graphical.target, strip pam_gnome_keyring from the SDDM PAM stack, ensure a
  Hyprland wayland session exists). Honors `RYOKU_DRYRUN=1` and `--dry-run`.
