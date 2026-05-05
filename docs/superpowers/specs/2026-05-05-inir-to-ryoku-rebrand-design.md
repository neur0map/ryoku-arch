# iNiR to Ryoku Rebrand: Vendor and Independence

## Context

Ryoku ships a Quickshell-based desktop shell that is currently sourced
from `github.com/snowarch/iNiR` at install time. The integration model is
clone-and-patch:

- `install/config/inir.sh` clones snowarch/iNiR into `~/.local/share/inir`
  and runs iNiR's own `./setup install`.
- `install/config/ryoku-shell-branding.sh` runs perl-regex patches against
  the cloned tree to apply Ryoku branding string substitutions and a set
  of bug-fix workarounds (lock security guard, idle swayidle disable,
  screen corners input mask, wallpaper resolution, sidebar right
  keep-mapped).
- A JSON merge step layers Ryoku-specific defaults onto iNiR's config.

This model couples Ryoku's runtime correctness to upstream's directory
layout, file names, and source patterns. If snowarch reorganizes its
tree, deletes the repo, or even renames a single file referenced by a
perl-regex anchor, Ryoku installs break silently.

The rebrand from iNiR to Ryoku that started with branding-string
substitutions has not finished. The shell code is not yet owned by
Ryoku, just decorated. This spec defines the work to complete that
transition: vendor iNiR's tree into this repo, eliminate the clone
dependency, rename `inir`/`iNiR` to `ryoku-shell`/`Ryoku` throughout,
convert the bug-fix patches into proper commits in the vendored tree,
and migrate existing live systems.

## Goals

- Eliminate the snowarch clone at install time. After this work, the
  Ryoku install pipeline never touches a network endpoint outside of
  Arch's package mirrors.
- Eliminate the perl-regex patch dance. Bug fixes become normal commits
  in the vendored tree. The branding script shrinks to asset copies,
  JSON config merge, and service-cleanup wiring.
- Rename every literal `inir`/`iNiR` reference in code to
  `ryoku-shell`/`Ryoku`. Includes paths, service unit names, launcher
  binary, and config namespaces.
- Provide a one-shot migration for existing systems so the live runtime
  state moves from `~/.config/quickshell/inir/` and friends to the new
  Ryoku-owned paths without losing user state.
- Preserve historical attribution. The About panel keeps iNiR and
  illogical-impulse as credited upstreams; documentation files inside
  the vendored tree retain their original iNiR mentions.

## Non-Goals

- No git subtree or submodule of snowarch. Plain copy. Hermetic seal.
- No "pull from snowarch" command. Future upstream fixes, if wanted, are
  manually cherry-picked at the developer's discretion.
- No rename of the `ii` namespace prefix in QML (`iiBar`, `iiSidebarLeft`,
  `qs.modules.ii.*`). That prefix is inherited from illogical-impulse,
  not iNiR. Out of scope.
- No documentation rewrite. `CHANGELOG.md`, `README.md`, `ARCHITECTURE.md`,
  and other docs inside the vendored tree keep their original iNiR
  references intact.
- No CLI/IPC unification across the existing `ryoku-*` commands. Out of
  scope; future work.

## Architecture

A four-phase refactor on the existing `niri-inir-transition` branch.
Each phase is one or more commits, each phase landable independently,
intermediate states functional.

### Phase 1: Vendor + switch install source (single commit)

Copy `~/.local/share/inir/` (currently a pristine clone of snowarch
HEAD) into the repo at `shell/`. Exclude `.git/` from the copy: we
want a hermetic vendor, not a history-laden mirror. Plain copy. Repo
grows by approximately 74 MB of tracked source (excluding `.git/`),
of which roughly 43 MB is `assets/` (icons, wallpapers, fonts).

Rewrite `install/config/inir.sh` to install from `shell/` instead of
cloning from snowarch:

- Replace the network-clone path with `cp -a "$RYOKU_PATH/shell/."
  "$HOME/.local/share/inir/"`. Same target path for now; rename
  happens in Phase 2.
- Drop the offline-fallback chain (vendor candidates, RYOKU_INIR_REPO).
  No network involvement, so the fallback is meaningless.
- Keep the bundled `./setup install -y --skip-deps --skip-sysupdate`
  invocation. The setup script handles installed_listfile tracking,
  migrations.json, version pinning, systemd unit deployment, and
  desktop entry generation. Reimplementing that in Ryoku is out of
  scope; we just point it at the copied tree.

Update `migrations/1778000000.sh` (the pristine restore migration) to
copy from `shell/` instead of cloning. Same source-resolution mirror,
just no network branch.

After Phase 1: snowarch is gone from the install path. The shell still
lives at `~/.local/share/inir/` and is still called iNiR in code,
visible labels, and identifiers, but its source of truth is this repo.

### Phase 2: Rename in code

Apply systematic renames across `shell/` and the Ryoku-side files that
reference iNiR:

| Pattern | Replacement |
|---------|-------------|
| `inir` (literal lowercase) | `ryoku-shell` |
| `iNiR` (literal mixed case) | `Ryoku` |
| `INIR_` (env var prefix) | `RYOKU_SHELL_` (where it shadows the renamed entity) |

Includes:

- File and directory names containing the literal `inir`. Notably:
  `~/.config/inir/` (user state) becomes `~/.config/ryoku-shell/`,
  `~/.config/quickshell/inir/` (runtime tree) becomes
  `~/.config/quickshell/ryoku-shell/`, `~/.local/bin/inir` becomes
  `~/.local/bin/ryoku-shell`, `inir.service` becomes
  `ryoku-shell.service`, `inir-super-overview.service` becomes
  `ryoku-shell-super-overview.service`.
- Source identifiers that match the literal: `inir setup` invocations,
  `inir cleanup-orphans` subcommand calls, every shell-script reference
  using the binary name.
- Config namespace: the Ryoku JSON overlay key `bar.ryokuTopbarHugFrame`
  is already Ryoku-prefixed, so no change there. The iNiR-side config
  file `defaults/config.json` does not contain literal `inir` keys, so
  no change there either.
- Documentation references INSIDE the vendored tree
  (`shell/CHANGELOG.md`, `shell/README.md`, `shell/ARCHITECTURE.md`,
  `shell/docs/*`) are LEFT UNCHANGED. They are historical record of the
  upstream project and are credited as such in the About panel.

Update the About panel (`shell/modules/settings/About.qml` after the
file rename, or its successor) to lead with Ryoku as the primary entry,
keeping iNiR and illogical-impulse as historical credit entries. The
existing entry list shape is preserved; one row added.

The `ii` prefix in QML (`iiBar`, `iiSidebarLeft`, `qs.modules.ii.*`)
remains untouched. That prefix derives from illogical-impulse and is
out of scope.

### Phase 3: Convert patches to commits

Move the bug-fix perl-patches from `install/config/ryoku-shell-branding.sh`
into proper commits in `shell/`. The five patches:

1. `apply_lock_security_guard` (Lock.qml)
2. `apply_idle_disable_swayidle` (Idle.qml)
3. `apply_screen_corners_input_mask_guard` (ScreenCorners.qml)
4. `apply_wallpaper_resolution_patch` (Wallpapers.qml)
5. `apply_sidebar_right_keep_mapped_workaround` (SidebarRight.qml)

Each becomes a normal edit in the corresponding `shell/modules/*.qml`
file, committed with the same fix rationale that was previously inline
in the branding script's comments.

After this phase, `ryoku-shell-branding.sh` shrinks to:

- `install_visible_assets` (asset copies, mostly icons)
- `apply_replacements_to_tree` becomes a no-op (the strings are already
  Ryoku in the vendored tree); the function and its TSV are removed.
- `apply_installed_labels` for the systemd unit Description and desktop
  entry Name. Even those become questionable, because the unit file in
  `shell/assets/systemd/ryoku-shell.service` can ship with the right
  Description directly. Remove if so.
- `apply_service_cleanup` for the `ExecStopPost` cleanup hook. Same
  question; if the unit ships with the hook, this becomes obsolete.
- `merge_default_config_overrides` and `merge_config_overrides` for
  the JSON overlay. Stays.

Estimated final branding script size: 50 to 100 lines instead of
the current 365.

### Phase 4: Migrate existing systems

A new migration script that transitions live installs from the iNiR
paths to the Ryoku-shell paths.

Steps:

1. Print a banner warning of approximately 1 to 3 minutes of no
   desktop chrome.
2. Pre-flight: if `~/.local/share/inir/` does not exist, exit 0
   (already migrated or never installed).
3. Stop `inir.service` and `inir-super-overview.service`.
4. Move user state: `~/.config/inir/` to
   `~/.config/ryoku-shell/`. Backup-first if a Ryoku-shell config
   already exists.
5. Move runtime tree: `~/.config/quickshell/inir/` to
   `~/.config/quickshell/ryoku-shell/`.
6. Remove old systemd units, desktop entry, launcher binary, icons.
7. Run the install pipeline's shell-install step against the renamed
   target so the new paths are populated correctly.
8. Re-create the `niri.service.wants` symlink for
   `ryoku-shell.service`.
9. `systemctl --user daemon-reload` and `systemctl --user start
   ryoku-shell.service`.

Backup of the user's pre-migration config goes to
`$RYOKU_STATE_PATH/inir-to-ryoku-shell-backup/` so cherry-picking
preferences back is possible.

## Repository Layout After Rebrand

```
ryoku-arch/
  shell/                       <- vendored from iNiR, then renamed
    modules/
      bar/
      lock/
      sidebarRight/
      settings/
      ...
    services/
    assets/
      systemd/ryoku-shell.service
      applications/ryoku-shell.desktop
    sdata/
    setup                       <- installer script, paths updated
    shell.qml
    ShellIiPanels.qml           <- name unchanged (Ii prefix preserved)
    ...
  install/
    config/
      shell.sh                  <- renamed from inir.sh
      ryoku-shell-branding.sh   <- shrunk to ~50-100 lines
      ...
  migrations/
    <ts>.sh                     <- new: inir-to-ryoku-shell migration
  default/
    ryoku-shell/
      config-overrides.json     <- unchanged
      branding-replacements.tsv <- removed (no upstream to substitute)
```

## Data Flow

No new services or runtime data flows. The end-state runtime is
identical to today: a Quickshell process with the same panels, same
config namespaces, same DBus contracts. Only the paths and labels
change.

## Failure Handling

Each phase is `set -euo pipefail` and uses the existing migration
runner's failure semantics. Specific failure modes:

| Phase | Likely failure | User-visible state |
|-------|----------------|---------------------|
| 1 | `cp -a` fails (disk full) | Install aborts, partial copy in target. Manual rm fixes. |
| 2 | Build-time test fails (path stale somewhere) | Test suite catches; phase doesn't merge. |
| 3 | Patch is missing in the vendored tree | The corresponding bug returns. Caught by existing tests for the workaround. |
| 4 | `mv` fails mid-migration (permissions, busy file) | Migration aborts. User left with pre-migration state plus partial new dirs. Manual cleanup needed. State backup preserved. |

## Testing

### Static
- The existing test suite continues to pass after each phase. Test
  files that reference `inir` paths get renamed and asserted against
  new paths.
- `tests/ryoku-shell-branding.sh` updated to reflect the shrunk
  branding script.
- `tests/niri-inir-merge-readiness.sh` continues to pass with
  renamed paths.
- New test asserting `install/config/shell.sh` does not contain
  `git clone` (independence guarantee).
- New test asserting `shell/` exists in the repo and has expected top
  files (`shell/shell.qml`, `shell/setup`, `shell/modules/`).

### Manual verification (after Phase 4 migration runs)
- `systemctl --user is-active ryoku-shell.service` returns `active`.
- `~/.config/quickshell/inir/` does not exist.
- `~/.config/quickshell/ryoku-shell/` exists and has the runtime tree.
- The bar, sidebars, lock, and settings UI work end-to-end.
- About panel shows Ryoku as primary, iNiR and illogical-impulse as
  historical credits.

## Rollback

The migration backs up `~/.config/inir/` to
`$RYOKU_STATE_PATH/inir-to-ryoku-shell-backup/` before any deletion.
Manual rollback: stop the new service, restore the backup, re-run the
old `install/config/inir.sh` from a pre-rebrand revision.

For the rebrand commits themselves: each phase is one or more commits.
Reverting any phase that has not yet been deployed to a system is a
normal `git revert`. Reverting a phase already deployed is harder,
because the migration is destructive of old paths; would require
restoring from backup.

## Repo Changes Summary

- New: `shell/` directory (~50 MB tracked source).
- New: `migrations/<ts>.sh` (rename migration).
- New: tests for `shell/` presence and `install/config/shell.sh`
  network-clone-absence.
- Renamed: `install/config/inir.sh` to `install/config/shell.sh`.
- Modified: `install/config/ryoku-shell-branding.sh` shrunk; eventually
  may be retired entirely if `apply_installed_labels` and
  `apply_service_cleanup` move into shipped unit files.
- Modified: `migrations/1778000000.sh` (pristine restore) updated to
  copy from `shell/` instead of cloning.
- Removed: `default/ryoku-shell/branding-replacements.tsv`.
- Modified: every Ryoku-side file referencing `inir`/`iNiR` (config
  templates, niri config, systemd units, etc.) gets renamed.

## Migration Ordering

Existing systems running through this branch will hit migrations in
this order:

1. `1778000000.sh` (pristine iNiR restore) - already applied on this
   user's system, unchanged in behavior, just sources from `shell/`
   now.
2. `<new-ts>.sh` (iNiR to Ryoku-shell migration) - runs once on each
   existing system, transitions to Ryoku-shell paths.

For fresh installs (ISO), neither migration runs. The install pipeline
deploys directly from `shell/` to the Ryoku-shell paths. No iNiR paths
are ever created.
