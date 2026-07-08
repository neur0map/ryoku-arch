# Changelog: ryoku-shell-installer

## Unreleased

### Added

- Safety gates: non-systemd systems (Artix/openrc/runit/s6/dinit) are
  refused before anything runs; Secure Boot is read from the
  SecureBoot/SetupMode efivars and, when enforcing, forces the NVIDIA
  toggle off and locked (unsigned DKMS modules are rejected at boot while
  nouveau gets blacklisted: black screen), with the way out named in the
  plan and at verify time; Manjaro requires typed consent in the TUI, is
  refused under `--yes`, and `RYOKU_ALLOW_MANJARO=1` overrides both.
- DE coexistence: GNOME/KDE/Cinnamon/Xfce are detected, never uninstalled,
  and named as still selectable at login. The greeter theme is its own
  toggle, default off when KDE's `kde_settings.conf` owns
  `/etc/sddm.conf.d` (turning it on writes a `zz-ryoku.conf` that sorts
  last and wins). Ex-GNOME boxes get `pam_gnome_keyring` re-added to
  `/etc/pam.d/sddm` so the GDM-era login keyring keeps auto-unlocking.
  Keyboard and monitor salvage learned GNOME (gsettings input-sources,
  `monitors.xml`) and KDE (`kxkbrc` with `Use=true`, Plasma 6
  `kwinoutputconfig.json`).
- Rice migration: ML4W, HyDE (and hyprdots), JaKooLit, end-4
  illogical-impulse, and Caelestia are detected by marker paths and named
  in the plan; HyDE's user units joined the conflict list and
  `illogical-impulse-*` metas are swept into the rival removal. Plain
  Hyprland setups get their `monitor=`/`monitorv2`/`input` intent salvaged
  from the hyprlang tree (`source=` includes, `$var` expansion, `desc:`
  pins kept) into `monitors_user.lua`/`keyboard.lua`.
- sway salvage: output and input grammar (multi-subcommand lines folded per
  output, `type:keyboard` > `*` > first device) feeds the same pin path;
  sway stays installed as a fallback session and its config joins the
  backup.
- Cross-run resume: completed step ids and the backup dir persist in
  `~/.local/state/ryoku/shell-install-state.json`; a rerun offers to resume
  from the failed step (automatic with `--yes`) and continues the same
  backup dir. Deleted after a fully successful run.
- `--uninstall`: removes the ryoku packages, drops the `[ryoku]` stanza,
  and walks the backup chain newest to oldest running each `restore.sh`
  with confirmation, which also re-enables the services recorded there.
- The plan screen groups toggles under section headers once the list grows
  past ten entries.

### Added

- Standalone no-ISO installer: `install.sh` curl bootstrap plus the
  `ryoku-shell-install` bubbletea TUI. Scans the machine, backs up configs
  with a generated `restore.sh`, removes rival quickshell shells, disables
  conflicting daemons and display managers, trusts the `[ryoku]` repo, installs
  the desktop set, wires SDDM/qylock/NetworkManager, materializes per-user
  config (salvaging the keyboard layout from a niri setup), builds the AUR
  extras, and converges with `ryoku doctor`. Headless `--yes` and `--dry-run`
  modes included.

### Added

- Developer toolchain toggle (default on): installs `dev.packages`
  (go/rust/node/python/mise) for ISO parity. Without go, `ryoku recovery`
  (rebuild from source) failed its preflight on shell-installed machines.
- Omarchy retirement: an ex-Omarchy box keeps the `[omarchy]` repo and routes
  core/extra through Omarchy's own mirror. When detected, the installer drops
  the repo stanza, restores a standard Arch mirrorlist, and removes
  `omarchy-keyring` (originals kept as `*.pre-ryoku`, undo lines in
  `restore.sh`).

- niri migration now carries real intent over: the full xkb setup (layout,
  variant, options) read across config.kdl and its includes lands in
  keyboard.lua, and output blocks (rotation, scale, position, mode, off, VRR)
  become monitors_user.lua pins that autoscale respects. User-level
  xdg-desktop-portal config is moved aside, the systemd user tree is backed
  up so restore.sh can put wants-wiring back, and clipboard/gamma daemons
  joined the conflict list.

### Fixed

- The post-driver initramfs rebuild probes for the box's actual generator
  (limine-mkinitcpio, mkinitcpio, dracut) and warns instead of aborting the
  install when none is found or the rebuild fails.

- Icon theme reaches shell-installed boxes: `ryoku-desktop` now depends on
  `papirus-icon-theme` (the theme its shipped `qt6ct.conf` selects), so the
  installer pulls it in with the desktop set and the launcher's all-apps grid
  resolves every app logo. The migration backup also carries `.config/qt6ct`
  aside (was `.config/kdeglobals`, no longer shipped) so a prior Qt config is
  preserved before `ryoku materialize` lays the Ryoku one.

- First boot flashed Hyprland's "Your config has errors" overlay: the shipped
  config pcall-requires optional drop-ins that don't exist on a fresh home and
  Hyprland reports the caught failure anyway. The installer now seeds
  comment-only stubs for the six optional files after `ryoku materialize`;
  they become redundant (but stay harmless) once the searchpath-probing
  loader ships in `ryoku-desktop`.
- The package step now survives a repo publish landing mid-install. It
  clears leftover `.part` downloads first (a resume against a mirror whose
  same-name bytes changed trips pacman's "Maximum file size exceeded" cap,
  and every retry inherited the stale prefix), and installs with
  `pacman -Syu` instead of `-S`, so a resumed run transacts against the db
  the mirror serves now rather than the one its first attempt synced. Pairs
  with the publish-side fix that makes published filenames immutable.
