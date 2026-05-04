# Pristine iNiR Restore

## Context

The current Ryoku install pipeline mutates iNiR source via
`install/config/ryoku-shell-branding.sh`, which applies ~290 lines of
perl-regex patches against `BarContent.qml`, `Bar.qml`, `Workspaces.qml`,
and `weather/WeatherBar.qml`, plus seven other `apply_*` workarounds, full
branding-string substitutions across the entire shell tree, and a
`merge_config_overrides` step that bakes Ryoku defaults into both the
in-source `defaults/config.json` and the user's runtime config at
`~/.config/inir/config.json`.

The bar patches in particular invalidate the Settings UI's Bar controls:
toggling Battery, Clock, sysTray, etc. does nothing because the patches
hardcode `&& !root.ryokuTopbarHugFrame` into those modules' `visible:`
predicates, while the JSON overlay sets `bar.ryokuTopbarHugFrame=true`
as a default.

The user's request is to wipe all iNiR-related state on disk and bootstrap
a pristine upstream install. The user will rebuild the Ryoku layer
themselves afterward; this design does not attempt to preserve, modify,
or pre-emptively neutralize any Ryoku branding code in the repo.

## Goals

- One-shot migration that leaves the live system with a pristine upstream
  iNiR install fetched from `github.com/snowarch/iNiR.git` HEAD.
- Use iNiR's own `./setup uninstall -y` as the primary cleanup mechanism,
  rather than a hand-rolled file list, because iNiR's `installed_listfile`
  manifest is the source of truth for what iNiR has installed.
- Remove the iNiR source tree itself and Ryoku-only artifacts that
  iNiR's uninstall does not track.
- Save a copy of the user's runtime config to a path outside the wipe
  scope as a safety net. The migration does not read or merge from this
  copy; it is a manual cherry-pick source for the user only.
- Self-mark as applied via the existing `bin/ryoku-migrate` state
  directory so it does not re-run.

## Non-Goals

- Do not edit `install/config/ryoku-shell-branding.sh`,
  `install/config/inir.sh`, or `default/ryoku-shell/config-overrides.json`.
  These stay as-is. The user will edit them themselves.
- Do not edit existing specs or memory files. The 2026-05-03 topbar
  three-island spec and the project memory baseline stay intact as
  historical record.
- Do not touch niri, quickshell, hypridle, hyprlock, or any system
  package.
- Do not touch the SDDM theme at `/usr/share/sddm/themes/ii-pixel/`
  (root-owned; out of scope for a user-level migration).
- Do not touch shared configs that iNiR classifies as
  shared+essential/optional (niri/config.kdl, matugen, fuzzel, Kvantum,
  GTK, fish, fontconfig, Vesktop-non-iNiR themes). iNiR's `-y` uninstall
  preserves these by default.
- Do not attempt to preserve or migrate accent color, wallpaper path,
  theme selections, or any other Settings-UI choice. The backup file
  is a safety net, not a migration source.

## Architecture

A single new shell script at `migrations/<latest-commit-unix-ts>.sh`,
following the existing convention in `migrations/`. Run by
`bin/ryoku-migrate` once on systems where it has not yet been applied;
state is tracked under `$RYOKU_STATE_PATH/migrations/`.

The migration is idempotent by virtue of the runner's state-tracking
mechanism: once it completes successfully, the state file is touched and
the migration will not re-run.

### Migration phases

1. **Banner**: print a multi-line warning that desktop chrome (bar,
   sidebars, lock UI) will be unavailable for approximately 1–3 minutes.
2. **Pre-flight**: abort cleanly with exit 0 if `~/.local/share/inir/setup`
   does not exist or is not executable. This handles the edge case
   where iNiR is already absent (manual prior cleanup, fresh install
   skipped this phase).
3. **Backup**: copy `~/.config/inir/config.json` to
   `$RYOKU_STATE_PATH/inir-restore-backup/config.json.<unix-ts>`. The
   backup target is created with `mkdir -p`. If the source does not
   exist (no prior config), the backup step is silently skipped.
4. **Stop services**: `systemctl --user stop inir.service
   inir-super-overview.service` with stderr suppressed and `|| true`.
   Both units may not exist on every system; absence is not an error.
5. **iNiR uninstall**: `~/.local/share/inir/setup uninstall -y`. iNiR's
   own uninstall logic combines two sources of truth: a static
   `INIR_ONLY_PATHS` map in `sdata/lib/uninstall.sh` and the dynamic
   `~/.config/inir/installed_listfile` manifest. Together they cover
   the iNiR-exclusive paths below (this is a representative, not
   exhaustive, list; the manifest is authoritative):
   - `~/.config/quickshell/inir/`
   - `~/.config/inir/`
   - `~/.local/state/quickshell/user/`
   - `~/.cache/quickshell/inir/`
   - `~/.local/bin/inir`
   - `~/.local/bin/inir_super_overview_daemon.py`
   - `~/.local/bin/sync-pixel-sddm.py`
   - `~/.config/systemd/user/inir.service`
   - `~/.config/systemd/user/inir-super-overview.service`
   - `~/.config/vesktop/themes/{system24.theme.css,ii-colors.css}` and the
     alt-case `~/.config/Vesktop/themes/...` variants
   - `~/.local/share/applications/inir.desktop`
   - `~/.local/share/icons/hicolor/scalable/apps/inir.svg`
6. **Wipe source tree**: `rm -rf ~/.local/share/inir`. iNiR's uninstall
   does not remove its own repo (the script runs from there); we do
   it explicitly after `setup uninstall` returns.
7. **Wipe Ryoku-only extras**: `rm -f
   ~/.local/share/icons/hicolor/scalable/apps/ryoku.svg`. This file is
   installed by `install/config/ryoku-shell-branding.sh:install_visible_assets`
   and is not in iNiR's manifest.
8. **Clone fresh**: `git clone https://github.com/snowarch/iNiR.git
   ~/.local/share/inir`. Network is required at this point. If the
   clone fails, the migration aborts (uninstall has already completed,
   so the user is left without iNiR until re-run after fixing network).
9. **Install fresh**: `~/.local/share/inir/setup install -y
   --skip-deps --skip-sysupdate`. Flags match the existing usage in
   `install/config/inir.sh:68-71` for consistency.
10. **Re-link service unit wants**: `mkdir -p
    ~/.config/systemd/user/niri.service.wants` then `ln -sf
    ~/.config/systemd/user/inir.service
    ~/.config/systemd/user/niri.service.wants/inir.service`. iNiR's
    uninstall removes the symlink target; the install step writes
    `inir.service` but does not re-create the wants symlink. We
    mirror the existing logic in
    `install/config/inir.sh:83-88` so the unit auto-starts with niri.
11. **Reload + start**: `systemctl --user daemon-reload; systemctl
    --user start inir.service`. The service unit is freshly written by
    step 9; `start` brings the bar/sidebars back online.

### Why this order matters

- Backup before uninstall: iNiR's uninstall removes
  `~/.config/inir/config.json` (it is in `INIR_ONLY_PATHS`). The
  backup must happen first.
- Stop services before uninstall: removing the unit file out from under a
  running service is technically tolerated by systemd but produces
  log noise and may leave the service marked active-but-broken until
  daemon-reload. Stopping first is cleaner.
- Wipe source tree after uninstall: the uninstall script runs from the
  source tree: `setup` cd's into `REPO_ROOT` before dispatching
  subcommands. Removing the directory before the script returns risks
  the script's cleanup logic touching missing files.
- Re-link wants symlink before start: niri queries the wants
  directory at session start, but for a manual `systemctl start`
  the symlink is not strictly required. We re-create it for symmetry
  with the existing install path.

## Out-of-Repo Side Effects

The migration writes outside the repo. Specifically:

- Reads: `~/.local/share/inir/setup`, `~/.config/inir/config.json`,
  `~/.config/inir/installed_listfile`.
- Writes: `$RYOKU_STATE_PATH/inir-restore-backup/config.json.<ts>`,
  fresh clone at `~/.local/share/inir/`, regenerated paths from
  iNiR's `./setup install`, and the systemd wants symlink.
- Deletes: as enumerated in phases 5–7.

No `sudo` is used. All paths are user-owned.

## Failure Handling

`set -euo pipefail` at the top of the migration ensures any single
command failure aborts the script before subsequent phases run. The
migration runner (`bin/ryoku-migrate`) treats a non-zero exit as a
failed migration and prompts the user to skip-or-abort via gum.

Specific failure modes:

| Phase | Failure | User-visible state |
|-------|---------|--------------------|
| 2 | `setup` missing | Migration exits 0; nothing changed |
| 3 | Backup target unwritable | Migration aborts; nothing changed |
| 4 | Service stop reports already-stopped | Ignored via `\|\| true` |
| 5 | `setup uninstall` fails mid-way | Partial wipe; user must re-run after the script's failure mode is understood. iNiR's uninstall is itself idempotent. |
| 6 | `rm -rf` fails | Should not happen on user-owned paths; aborts |
| 7 | `rm -f` of Ryoku icon fails | Should not happen; aborts |
| 8 | Network unreachable for `git clone` | Aborts. User has no iNiR until re-run with network. |
| 9 | `setup install` fails | Aborts. Source tree is present but runtime tree may be incomplete. iNiR's setup is documented to be re-runnable. |
| 10–11 | Service start fails | Aborts before user notices, but desktop chrome stays absent. User must investigate. |

The expected most-likely failure is **network during clone**. Mitigation:
the migration prints a hint pointing to manual re-run via
`bin/ryoku-migrate`.

## Live-System Disruption Window

Between phase 4 (service stop) and phase 11 (service start), the user's
desktop chrome is absent. Niri itself keeps running (it is a separate
binary), so existing windows persist and keybinds like `Super+Space`
still launch apps. What goes away:

- Top bar
- Sidebars (left and right)
- Lock surface (do not lock the screen during migration)
- Notifications popup
- OSD (volume/brightness)
- Cheatsheet
- Any other panel registered in `ShellIiPanels.qml`

Estimated total disruption: 1–3 minutes on a typical broadband connection,
dominated by `git clone` and `./setup install` (which runs many
`install -m 0644` and `cp -a` operations across the iNiR tree).

The migration prints an explicit banner before stopping services so
the user can choose to abort with Ctrl+C if the timing is bad.

## Testing

### Static

- `bash -n migrations/<ts>.sh` (syntax check).
- `shellcheck migrations/<ts>.sh` if available.
- The migration must include `set -euo pipefail`.

### Manual verification (post-migration)

1. `git -C ~/.local/share/inir log -1 --format='%H %s'` shows the
   upstream HEAD commit, and `git -C ~/.local/share/inir status` is
   clean (no modified files).
2. `grep -c ryokuTopbarHugFrame
   ~/.config/quickshell/inir/modules/bar/BarContent.qml` returns 0.
3. `systemctl --user is-active inir.service` returns `active`.
4. The Settings UI Bar tab toggles for Battery, Clock, sysTray, etc.
   visibly affect the running bar.
5. The backup file at
   `$RYOKU_STATE_PATH/inir-restore-backup/config.json.<ts>` exists
   and is parseable by `jq`.

### Negative tests

- **Re-run after success.** The migration runner tracks completion in
  `$RYOKU_STATE_PATH/migrations/<filename>`. Once successful, it does
  not re-run. If a user manually clears that state file and re-invokes
  `bin/ryoku-migrate`, the migration will run again end-to-end:
  uninstall the freshly installed iNiR, wipe the source tree, re-clone,
  and reinstall. This is destructive but consistent (idempotent in
  outcome: pristine iNiR every time). It is the user's responsibility
  not to clear the state file unintentionally.
- **No-iNiR pre-state.** If `~/.local/share/inir/setup` does not exist
  when the migration starts (manual prior cleanup, or first-time install
  bypassing iNiR), phase 2 exits 0. No clone or install happens. This
  is intentional: the migration is a wipe-then-restore, not a
  first-time installer.

## Rollback

The migration is destructive of Ryoku layer and Ryoku settings. There
is no automatic rollback path. Manual rollback options for the user:

- Restore prior config: `cp $RYOKU_STATE_PATH/inir-restore-backup/config.json.<ts>
  ~/.config/inir/config.json` then `systemctl --user restart inir.service`.
- Re-apply Ryoku layer: re-run `install/config/inir.sh` (which calls
  `ryoku-shell-branding.sh`). Beware that this will re-introduce the
  bar override that motivated this migration.

## Repo Changes

Single new file: `migrations/<latest-commit-unix-ts>.sh` (filename
generated via the convention in `bin/ryoku-dev-add-migration`:
`git log -1 --format=%cd --date=unix` of the commit that adds it).

No edits to existing files.
