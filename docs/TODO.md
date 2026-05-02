# Roadmap

Ryoku's active source track is the Niri + iNiR transition. This file is the
current TODO; older implementation plans under `docs/superpowers/` are
historical records unless an item is copied here.

The immediate goal is a clean, reviewable merge to `main` with source and docs
ready for a later ISO-build session. Fresh ISO building, fresh boot
verification, and the next rebrand pass are intentionally separate sessions.

## Merge To Main

- [ ] Keep the Niri/iNiR branch layered on top of existing history; do not squash
  away the transition commits.
- [ ] Re-run source verification before merge: full `tests/*.sh`,
  `git diff --check`, Bash syntax checks, `niri validate`, `inir status`, and
  the personal leak scanner.
- [ ] Preserve Ryoku screensavers, Plymouth assets, and branding defaults while
  removing obsolete Hyprland-era runtime pieces.
- [ ] Document the deliberate live-to-repo portability exceptions: no personal
  browser state, no credential helpers, no hardcoded user home paths, no
  machine-specific display modes, and no local-only helper paths.
- [ ] Make the final merge notes explicit that ISO build/boot verification and
  full rebrand review are deferred follow-up work.

## Documentation Refresh

- [ ] Rewrite `README.md` so the first impression says Niri + iNiR, not
  Hyprland + the old shell stack.
- [ ] Update `docs/vision.md` for the current compositor, shell, session, and
  non-goals.
- [ ] Rebuild `docs/customization-inventory.md` from the current config tree:
  `config/niri`, `config/fuzzel`, terminals, GTK/Qt, Matugen, systemd user
  units, portals, fonts, and theme templates.
- [ ] Remove or clearly mark stale Hyprland, Waybar, Mako, SwayOSD, Tofi,
  Walker, Brain Shell, and Noctalia references from public docs. Historical
  plan/spec files may keep them when the context is explicitly historical.
- [ ] Update `docs/iso-build-recipe.md` so the older Hyprland ISO proof is
  labeled historical and the current Niri ISO state is clearly pending.
- [ ] Add a user-facing "What remains from Omarchy" document covering upstream
  heritage, retained attribution, compatibility wrappers, cleanup-only legacy
  paths, external package/theme identifiers that must keep their names, and
  what no longer ships.
- [ ] Update `docs/rebrand-inventory.md` after the Niri docs pass so it reflects
  what remains for knowledge and compatibility rather than old migration plans.
- [ ] Add screenshots/video only after the Niri/iNiR desktop is stable enough
  that the media will still match the ISO.

## Keybinding Reference

- [ ] Generate the user-facing keybinding guide from
  `config/niri/config.d/70-binds.kdl` so docs stay aligned with the shipped
  Niri config.
- [ ] Cover session and compositor binds: overview, quit, shortcut-inhibit
  escape hatch, and monitor power-off.
- [ ] Cover iNiR shell binds: Alt-Tab switcher, crosshair overlay, launcher,
  clipboard, lock, region screenshot/OCR/search, wallpaper selector, settings,
  cheatsheet, panel-family cycle, and session dialog.
- [ ] Cover app launchers: terminal, file manager, and browser.
- [ ] Cover window and column management: close, maximize, fullscreen,
  floating, preset widths/heights, centering, resize, consume/expel, and tabbed
  column display if enabled later.
- [ ] Cover navigation and movement: arrow keys, Vim keys, first/last column,
  moving columns/windows, monitor focus, and moving columns between monitors.
- [ ] Cover workspaces, screenshots, audio, brightness, microphone, and media
  keys.

## ISO And Offline Install Readiness

- [ ] Add an ISO readiness gate command that runs every source-level check
  needed before starting a heavy ISO build.
- [ ] Add a first-boot doctor that checks Niri, iNiR, portals, SDDM theme,
  audio, brightness, notifications, shell IPC, and package-cache health.
- [ ] Expand manifest drift tests so every package used by install/setup scripts
  is available through the offline ISO path.
- [ ] Write an offline install contract: what must be in the pacman cache, what
  must be in the AUR boot overlay, and which network calls are forbidden during
  an offline install.
- [ ] Build a migration safety harness that can run migrations against a fake
  home directory and verify idempotency.
- [ ] Maintain a hardware matrix for GPU, Wi-Fi, Bluetooth, fingerprint,
  laptop brightness, Apple T2, Panther Lake, and unusual storage/network
  devices.
- [ ] Define a rollback story for failed first boot, failed iNiR service start,
  broken display manager, and bad package mirror/cache state.
- [ ] Capture local install/support logs in a Ryoku-owned location with a
  redaction path before users share them.

## Safety And Release Hygiene

- [ ] Keep `bin/ryoku-dev-scan-leaks` reusable from hooks, tests, and manual
  review; expand patterns when new leak classes appear.
- [ ] Wire the leak scanner into CI before accepting public contributions.
- [ ] Add a brand/rebrand guard that blocks new `omarchy` text unless the file is
  an approved compatibility, attribution, cleanup, or historical-doc surface.
- [ ] Move expensive AUR rebuilds toward a hosted Ryoku package repo after the
  release pipeline is stable.
- [ ] Keep legacy compatibility wrappers only for a documented migration window,
  then remove them with a migration and release note.

## Security Workstation Baseline

- [ ] Define the default security-tooling set by category: recon, web,
  wireless, forensics, reverse engineering, wordlists, and reporting.
- [ ] Keep heavy, niche, or legally sensitive tools optional instead of default.
- [ ] Add a short "what ships by default" section once the first baseline lands.
- [ ] Document optional tool packs without turning Ryoku into a kitchen-sink
  distribution.
