# iNiR Independence Migration Design

**Date:** 2026-05-03
**Status:** Draft, pending user review
**Owner:** Carlos Mejia (neur0map)

## Purpose

Sever every operational dependency on `snowarch/iNiR`. After this pass, no Ryoku component clones, downloads, or pulls from `https://github.com/snowarch/iNiR.git` to install, run, or update. The shell source lives in-tree at `apps/ryoku-shell/` and is shipped via the same Ryoku source copy that already carries the rest of `$RYOKU_PATH`. ISO builds bundle the shell natively; live installs run it directly from the Ryoku tree.

This is the design input for the follow-on implementation plan. It does not implement the cutover.

## Context

The May-02 Niri/iNiR integration spec (`2026-05-02-ryoku-niri-inir-integration-design.md`) closed out the user-visible Niri transition but explicitly left one question unresolved:

> Whether to vendor iNiR into Ryoku source or keep installing it as a tracked external checkout under `~/.local/share/inir`.

This spec answers that question with **vendor**, and works through the consequences. The pattern follows the precedent set by the Omarchy infrastructure independence pass (commits `559b2c72` design + `82f02323` plan + `68dc7b60` completion): vendor an external upstream into Ryoku source, sever every install-time and runtime network dependency on it, migrate live systems via a snapshot-gated migration, and keep historical attribution in a heritage doc.

Today, a Ryoku system depends on `snowarch/iNiR` in these ways:

- `install/config/inir.sh` clones `https://github.com/snowarch/iNiR.git` (or copies from a fallback chain `vendor/inir`, `/root/inir`, `/opt/ryoku/inir`) into `~/.local/share/inir/`.
- `install/config/ryoku-shell-branding.sh` (~650 LOC of Perl rewrites + a TSV) patches the cloned tree in place to apply Ryoku branding, the topbar hug frame, the Qt 6.11 sidebar UAF workaround, the lock security guard, the screen-corners input mask guard, and the wallpaper resolution patch.
- `iso/builder/build-iso.sh` clones the upstream into the live ISO via `RYOKU_INIR_REPO`, prefetches Python deps from `inir/sdata/uv/requirements.txt`, and copies into `/root/inir` for the installer to pick up.
- `iso/bin/ryoku-iso-make` mounts `~/.local/share/inir` as `/inir:ro` for build-time access.
- `iso/configs/airootfs/root/.automated_script.sh` copies `/root/inir` into the user's `~/.local/share/` during ISO install.
- The runtime CLI is `~/.local/bin/inir`, the systemd unit is `inir.service`, the Quickshell runtime is `~/.config/quickshell/inir/`, the user config is `~/.config/inir/config.json`, env vars are `INIR_*` and `RYOKU_INIR_*`, and ~20 Niri keybinds (`config/niri/config.d/70-binds.kdl`) call `spawn "inir" ...`.
- `tests/niri-inir-merge-readiness.sh` is a 75-assertion contract that explicitly *requires* the upstream-clone behavior, it has to be rewritten to invert the requirement.

Concrete failure modes this spec mitigates:

- Outage of `github.com/snowarch/iNiR` blocks fresh installs and ISO builds entirely.
- A breaking change in upstream iNiR (renamed module, removed module, changed setup contract) silently breaks Ryoku without warning.
- The branding-replacements TSV and the Perl patch functions in `ryoku-shell-branding.sh` are coupled to the exact shape of the upstream tree; an upstream restructure (renamed file, refactored block) silently makes patches no-op without raising an error.
- Sunset or hostile fork of `snowarch/iNiR` leaves Ryoku without a working install path.
- Downstream Ryoku changes can't be reviewed against a stable base because the base is "whatever upstream HEAD was when you ran the script."

## Goals

- Remove every runtime, install, and ISO-build reference to `github.com/snowarch/iNiR` from active code.
- Vendor the iNiR source tree into Ryoku at `apps/ryoku-shell/`, with all current branding/QML patches pre-applied so the committed tree is in its final Ryoku-branded state.
- Rename runtime surfaces (`inir.service`, `~/.local/bin/inir`, `~/.config/quickshell/inir/`, `~/.config/inir/`, env vars, desktop file, CLI verbs, QML IPC handlers) to Ryoku-namespaced equivalents.
- Migrate existing installed systems atomically via a snapshot-gated, idempotent migration that preserves user shell config and rolls back cleanly if the new service fails to start.
- ISO builds bundle the vendored tree natively, no `RYOKU_INIR_REPO` env, no `/inir:ro` mount, no clone fallback.
- Make every chunk individually revertible via `git revert`. Use many small commits within each chunk so any single step can be undone independently.
- Preserve the discipline established by the Omarchy independence pass: no `--no-verify`, no AI trailers, no commit rewrites of prior history (additive only).

## Non-goals

- Renaming QML internal `Ii*` / `ii*` identifiers (`ShellIiPanels.qml`, `iiScreenFrame`, `iiPersist`). Internal-only, never user-visible; renaming is multi-thousand-line churn for no functional gain.
- Renaming the SDDM theme directory `ii-pixel` or its install path `/usr/share/sddm/themes/ii-pixel`. External theme identifier; renaming would break theme lookup.
- Setting up automated upstream tracking (no `git subtree`, no subrepo, no upstream remote in the Ryoku repo). Future cherry-picks are manual, attribution preserved in commit messages.
- Rewriting the vendored `setup` script. It becomes Ryoku-owned post-vendor and may diverge over time; that's expected.
- Any Quickshell-related work beyond renaming the systemd drop-in path that the existing `qt6-qiooperation-patch` writes.
- Any change to the iNiR upstream itself or any contribution back to it.

## Target State

After this pass:

**Source tree.** `apps/ryoku-shell/` contains the iNiR source at the vendored upstream sha, with all current `ryoku-shell-branding.sh` patches pre-applied. The upstream `inir.desktop` and `inir.service` files in the tree are renamed to `ryoku-shell.desktop` and `ryoku-shell.service`. The upstream `.git/` directory is not vendored.

**Install entrypoint.** `install/config/ryoku-shell.sh` (renamed from `install/config/inir.sh`) syncs the vendored tree from `$RYOKU_PATH/apps/ryoku-shell/` to `~/.local/share/ryoku-shell/` via rsync, then runs the vendored `./setup install -y --skip-deps --skip-sysupdate`. The fallback chain (`vendor/inir`, `/root/inir`, `/opt/ryoku/inir`, `git clone`) is removed entirely.

**Runtime patcher retired.** `install/config/ryoku-shell-branding.sh` is deleted along with `default/ryoku-shell/branding-replacements.tsv`. The patches it applied at install time are baked into `apps/ryoku-shell/` directly, so no runtime patching is needed. The lock-security guard, screen-corners input mask guard, wallpaper resolution patch, sidebar Qt6.11 UAF workaround, topbar hug frame, and weather-bar dynamic color all live as committed source in the vendored tree.

**Systemd unit and CLI.** `~/.config/systemd/user/ryoku-shell.service` replaces `inir.service`. `~/.local/bin/ryoku-shell` replaces `~/.local/bin/inir`. `~/.config/systemd/user/niri.service.wants/ryoku-shell.service` is the new wants symlink.

**Runtime paths.** `~/.local/share/ryoku-shell/` (source tree), `~/.config/quickshell/ryoku-shell/` (Quickshell runtime), `~/.config/ryoku-shell/config.json` (user shell config). `~/.local/state/quickshell/.venv` (Python venv) is preserved in place; only the env var pointing at it changes.

**Env vars.** `RYOKU_SHELL_VENV` replaces `INIR_VENV` in `config/niri/config.d/40-environment.kdl`. `RYOKU_SHELL_PATH` is the canonical source path (already used in `install/config/ryoku-shell-branding.sh` today).

**Niri keybinds.** Every `spawn "inir" "<verb>" ...` in `config/niri/config.d/70-binds.kdl` becomes `spawn "ryoku-shell" "<verb>" ...`. Comments in `40-environment.kdl`, `50-startup.kdl`, and `70-binds.kdl` updated to say "Ryoku shell" or "ryoku-shell" where they reference the runtime; "iNiR" is preserved only where it's attribution context.

**CLI consumers.** Every `bin/ryoku-*` script that calls `inir <verb>` is updated to call `ryoku-shell <verb>`. Every script that references `inir.service` references `ryoku-shell.service`. `bin/ryoku-ipc`'s `exec_inir` helper becomes `exec_ryoku_shell`.

**QML IPC handlers.** Inside the vendored tree, IPC handlers registered as `inir.*` are renamed to `ryoku-shell.*`. Done in commit 1b alongside the other branding patches.

**ISO build.** `iso/builder/build-iso.sh` no longer references `RYOKU_INIR_REPO`, no longer clones `https://github.com/snowarch/iNiR.git`, no longer mounts `/inir`, and no longer copies `/root/inir`. The Python uv prefetch still happens, reading from `apps/ryoku-shell/sdata/uv/requirements.txt` inside the bundled Ryoku source. `iso/bin/ryoku-iso-make` no longer accepts `RYOKU_INIR_*` env vars or mounts a separate iNiR checkout. `iso/configs/airootfs/root/.automated_script.sh` no longer copies `/root/inir` into the user's home, the vendored tree comes in as part of the Ryoku source copy that already runs.

**Distro packaging.** `distro/arch/quickshell-ryoku/PKGBUILD` description updated to drop "iNiR project" framing; `DISTRIBUTOR='Ryoku Arch (ryoku-shell-patched)'`. The `fix-extension-uaf.patch` filename stays (it's a Quickshell upstream patch, not iNiR-specific). `distro/arch/qt6-qiooperation-patch/{apply.sh,verify.sh,README.md}` writes to `~/.config/systemd/user/ryoku-shell.service.d/` instead of `inir.service.d/`. Comments referencing the iNiR upstream debugging context are kept as historical attribution.

**Tests.** `tests/niri-inir-merge-readiness.sh` is rewritten as `tests/ryoku-shell-vendoring.sh`. Most `assert_contains "RYOKU_INIR_REPO|github.com/snowarch/iNiR"` lines flip to `assert_not_contains`. New assertions confirm `apps/ryoku-shell/` exists, `apps/ryoku-shell/setup` is executable, `install/config/ryoku-shell.sh` rsyncs from `apps/ryoku-shell/`, no `snowarch/iNiR` string appears in active code, and `ryoku-shell.service` is the canonical unit name.

**Heritage doc.** New `docs/inir-heritage.md` mirroring `docs/omarchy-heritage.md`. README.md Credits updated to clarify iNiR is now vendored as Ryoku source.

## Vendor Tree Layout

```
apps/ryoku-shell/
  ARCHITECTURE.md
  CHANGELOG.md
  CODE_OF_CONDUCT.md
  CONTRIBUTING.md          ← preserved from upstream (heritage)
  LICENSE                  ← upstream LICENSE preserved (attribution)
  README.md                ← preserved from upstream + Ryoku-vendor preamble
  SECURITY.md
  VERSION
  Makefile
  go.mod
  setup                    ← upstream installer entrypoint, Ryoku-owned post-vendor
  shell.qml
  ShellIiPanels.qml        ← QML internals keep Ii* prefix (out of scope)
  ShellWafflePanels.qml
  GlobalStates.qml
  FamilyTransitionOverlay.qml
  killDialog.qml
  settings.qml
  waffleSettings.qml
  welcome.qml              ← branding TSV pre-applied (Welcome → Ryoku, etc.)
  assets/
    applications/
      ryoku-shell.desktop  ← renamed from inir.desktop, branding applied
    systemd/
      ryoku-shell.service  ← renamed from inir.service, branding applied
    ...
  defaults/
    config.json            ← config-overrides.json merged in
  distro/
  docs/                    ← preserved from upstream (heritage)
  dots/
    sddm/
      pixel/               ← branding TSV pre-applied (Name=Ryoku Pixel etc.)
                              dir name "ii-pixel" stays (external SDDM theme id)
  modules/                 ← all the patches from ryoku-shell-branding.sh applied:
    bar/
      Bar.qml              ← topbar hug frame patches applied
      BarContent.qml       ← topbar hug frame patches applied
      Workspaces.qml       ← workspace relocation patches applied
      weather/
        WeatherBar.qml     ← dynamic color patch applied
    sidebarRight/
      SidebarRight.qml     ← Qt 6.11 UAF workaround applied
    lock/
      Lock.qml             ← lock security guard applied
    screenCorners/
      ScreenCorners.qml    ← input mask guard applied
  patches/                 ← upstream patches dir, kept (incl. fix-extension-uaf.patch)
  scripts/
  sdata/
    uv/
      requirements.txt     ← consumed by ISO builder for Python prefetch
  services/
    Wallpapers.qml         ← wallpaper resolution patch applied
  translations/
```

**Not vendored:** the upstream `.git/` directory. Heritage info goes into the commit message of commit 1a and into `docs/inir-heritage.md`, not into the tree.

## Vendoring Mechanics (one-time, recorded for reproducibility)

```bash
# In a scratch dir:
git clone https://github.com/snowarch/iNiR.git /tmp/inir-vendor
cd /tmp/inir-vendor
git rev-parse HEAD > /tmp/inir-upstream-sha
git archive HEAD | tar -x -C "$RYOKU_PATH/apps/ryoku-shell/"
# Commit 1a: vendor: import iNiR @ <sha> as apps/ryoku-shell/

# Apply patches:
RYOKU_SHELL_PATH="$RYOKU_PATH/apps/ryoku-shell" \
  RUNTIME_SHELL_PATH=/dev/null \
  "$RYOKU_PATH/install/config/ryoku-shell-branding.sh"
# Plus file renames inir.desktop → ryoku-shell.desktop, inir.service → ryoku-shell.service.
# Plus QML IPC handler renames (inir.* → ryoku-shell.*) inside the tree.
# Commit 1b: vendor: apply Ryoku branding + IPC rename to apps/ryoku-shell/
```

The script-driven application gives reproducibility: anyone can re-run the same commands against the same upstream sha and get the same commit 1b diff (modulo the `setup` script not running, since it depends on a real install).

## Chunk Queue (8 chunks)

Each chunk owns one failure boundary. No chunk is allowed to cross two boundaries. Within each chunk, prefer many small commits so any single step can be reverted independently via `git revert`.

| # | Chunk | Owned Surfaces | Exit Criteria |
|---|---|---|---|
| 1 | **Vendor source** | Add `apps/ryoku-shell/` containing the iNiR tree at the recorded upstream sha with all current `ryoku-shell-branding.sh` patches pre-applied. **2 commits:** (1a) raw upstream import; (1b) branding patches + IPC handler rename + file renames applied. No other file touched. | `apps/ryoku-shell/setup --help` runs from a clean checkout; raw-import sha recorded in commit 1a body |
| 2 | **Re-point install/config** | Rename `install/config/inir.sh` → `install/config/ryoku-shell.sh`. New script copies from `$RYOKU_PATH/apps/ryoku-shell/` into `~/.local/share/ryoku-shell/` via rsync and runs `./setup install -y --skip-deps --skip-sysupdate`. Drops the `vendor/inir`/`/root/inir`/`/opt/ryoku/inir`/git-clone fallback chain. Update `install/config/all.sh` and `bin/ryoku-update-perform` to call the new script name. **1 commit.** | `install/config/ryoku-shell.sh` runs against vendored tree with no network; old `install/config/inir.sh` is gone |
| 3 | **Rename runtime artifacts** | Vendored tree's `assets/systemd/inir.service` → `ryoku-shell.service`; `assets/applications/inir.desktop` → `ryoku-shell.desktop` (already done in chunk 1b, chunk 3 wires up the consumers). The vendored `setup` script's launcher creation is verified to point at `~/.local/bin/ryoku-shell`. Niri service-wants symlink uses new name. Env var rename across **all consumers**: `INIR_VENV` → `RYOKU_SHELL_VENV` in `config/niri/config.d/40-environment.kdl` (the env-var line plus the explanatory comment block) AND in `config/matugen/templates/kde/kde-material-you-colors-wrapper.sh:46`. **Dual-export during the migration window:** `40-environment.kdl` exports BOTH `INIR_VENV` and `RYOKU_SHELL_VENV` (same value), and the wrapper script reads `${RYOKU_SHELL_VENV:-${INIR_VENV:-$ILLOGICAL_IMPULSE_VIRTUAL_ENV}}` so unmigrated user shells keep working until they re-source niri env. The legacy `INIR_VENV` export drops in the dual-name cleanup follow-up release (see chunk 8 note). `config/systemd/user/inir.service` → `config/systemd/user/ryoku-shell.service` in the Ryoku tree. **4-5 commits:** systemd unit (Ryoku tree side); vendored `setup` launcher verification; env vars in `40-environment.kdl` (with dual-export); env vars in matugen template (with fallback chain); service-wants symlink wiring. | Fresh install lands `ryoku-shell.service` and `~/.local/bin/ryoku-shell`; live boot reaches working shell; `kde-material-you-colors` template renders and runs without `INIR_VENV` set |
| 4 | **Rename CLI consumers** | `bin/ryoku-ipc` (`exec_inir` → `exec_ryoku_shell`), `bin/ryoku-restart-shell`, `bin/ryoku-launch-shell`, `bin/ryoku-refresh-quickshell`, `bin/ryoku-restart-ui`, `bin/ryoku-lock-screen`, `bin/ryoku-system-logout`, `bin/ryoku-shell-cleanup-orphans` (the `inir cleanup-orphans` call **and** the two `pkill -TERM -f '/quickshell/inir/scripts/...'` patterns, runtime PATH PREFIX changes from `/quickshell/inir/` to `/quickshell/ryoku-shell/`; the leaf script paths `scripts/colors/switchwall.sh` and `scripts/daemon/keyboard_lock_state_daemon.py` stay), all the `bin/ryoku-cmd-*` and `bin/ryoku-launch-*` and `bin/ryoku-theme-*` and `bin/ryoku-volume`, etc. Every `inir <verb>` call becomes `ryoku-shell <verb>`. `config/niri/config.d/70-binds.kdl`, every `spawn "inir" ...` becomes `spawn "ryoku-shell" ...` and the surrounding "iNiR" comments become "Ryoku shell" / "ryoku-shell". `config/niri/config.d/50-startup.kdl`, the "iNiR shell" comment block updated to "Ryoku shell" wording. **7-9 commits** split by consumer family: `ryoku-ipc` + lifecycle helpers (`restart-shell`, `restart-ui`, `launch-shell`, `refresh-quickshell`); `ryoku-shell-cleanup-orphans` (CLI call + runtime path patterns, in one commit since both are tightly coupled to the path rename); `cmd-*` wrappers; `launch-*` wrappers; `theme-*`/`volume`/`lock-screen`/`system-logout`/etc.; `70-binds.kdl` spawn calls + comments; `50-startup.kdl` comments. **Dual-name fallback in lifecycle helpers** (`bin/ryoku-restart-shell`, `bin/ryoku-restart-ui`, `bin/ryoku-launch-shell`): try `ryoku-shell.service` / `ryoku-shell` binary first, fall back to `inir.service` / `inir` for unmigrated systems. Fallback stays in place until the dual-name cleanup follow-up release; not removed in chunk 8. | `grep -rE '"inir"\|spawn "inir"\|exec inir\|inir\.service\|inir\.desktop\|RYOKU_INIR\|/quickshell/inir/' bin/ config/ install/ tests/` returns only matches in: (a) the dual-name fallback branches, (b) the dual-export `INIR_VENV` line in `40-environment.kdl`, (c) the `${INIR_VENV:-...}` fallback in the matugen template |
| 5 | **ISO build** | `iso/builder/build-iso.sh`: drop `RYOKU_INIR_REPO`, `/inir` mount handling, the upstream-clone fallback, and the `inir/sdata/uv/requirements.txt` lookup. Replace with a uv prefetch reading from `apps/ryoku-shell/sdata/uv/requirements.txt` inside the bundled Ryoku source. `iso/bin/ryoku-iso-make`: drop `RYOKU_INIR_*` env handling and the `-v $INIR_SOURCE:/inir:ro` mount. `iso/configs/airootfs/root/.automated_script.sh`: drop the `cp -r /root/inir` step that copies into the installed user's `.local/share/` directory. **3 commits:** `build-iso.sh`; `ryoku-iso-make`; ISO automated_script. | ISO builds with `RYOKU_INIR_*` env unset succeed; no `snowarch/iNiR` string in `iso/` tree |
| 6 | **Distro/PKGBUILD** | `distro/arch/quickshell-ryoku/PKGBUILD`: rename description to "Ryoku shell fix-extension-uaf patch applied"; `DISTRIBUTOR='Ryoku Arch (ryoku-shell-patched)'`. The `fix-extension-uaf.patch` file stays in this directory (it's a Quickshell patch, not iNiR-specific). `distro/arch/qt6-qiooperation-patch/{apply.sh,verify.sh,README.md}`: rename `inir.service.d/` paths to `ryoku-shell.service.d/`. Comments/headers may keep "iNiR" only as historical attribution where the patch description references the upstream debugging context. **2 commits:** quickshell-ryoku PKGBUILD; qt6-qiooperation patch. | `grep -rE 'iNiR\|inir\.service' distro/` returns only attribution context (verified line by line in commit) |
| 7 | **Live-system migration** | New migration `migrations/<epoch>.sh` that performs the cutover on installed systems. Snapshot-gated, idempotent, with verification gate before legacy cleanup. Existing migration `1777776000.sh` left unchanged, its existing `[[ -f $tmp_service ]]` guard already gates correctly on post-cutover hosts. **1 commit** (migration is one logical unit; partial migration scripts leave ambiguous state). | Re-runnable on a migrated host with no observable effect; on a pre-cutover host, converges in one run; failed run leaves system bootable on the legacy path |
| 8 | **Tests + heritage doc + final sweep** | **In-place rewrite** of `tests/niri-inir-merge-readiness.sh` (file kept; not renamed): keep the Niri config baseline assertions (Kitty, Foot, Fuzzel, Btop, GTK fonts, etc.); flip the upstream-clone assertions to `assert_not_contains` for `RYOKU_INIR_REPO|github.com/snowarch/iNiR` in `iso/builder/build-iso.sh` and `iso/bin/ryoku-iso-make`; replace the `assert_contains install/config/inir.sh ...` block with `assert_contains install/config/ryoku-shell.sh 'apps/ryoku-shell'` + assertions that the file copies from the vendored path with no clone fallback; flip `assert_contains config/systemd/user/inir.service ...` to `assert_contains config/systemd/user/ryoku-shell.service ...`; flip `assert_contains bin/ryoku-restart-shell 'inir\.service\|inir restart'` to assert the new service name (with the dual-name fallback as an allowed match); flip `assert_contains bin/ryoku-shell-cleanup-orphans 'inir cleanup-orphans'` to `'ryoku-shell cleanup-orphans'`; add new assertions: `apps/ryoku-shell/` exists, `apps/ryoku-shell/setup` is executable, `apps/ryoku-shell/assets/systemd/ryoku-shell.service` exists, `install/config/ryoku-shell-branding.sh` is gone, `default/ryoku-shell/branding-replacements.tsv` is gone, no `github.com/snowarch/iNiR` string anywhere in active code (excluding `docs/`, `apps/ryoku-shell/`, NOTICE/LICENSE/CREDITS/README). Also update `tests/ryoku-session-recovery.sh:70` (`inir cleanup-orphans` → `ryoku-shell cleanup-orphans`). Also update `tests/asus-audio-mixer.sh`, `tests/ryoku-restart-ui.sh`, etc. as needed. **Dual-name fallback NOT removed here**, defer to a follow-up release after dev-machine migration is confirmed (see "Dual-Name Fallback Cleanup" section below). New `docs/inir-heritage.md` (mirrors `omarchy-heritage.md` shape). Update `README.md` Credits section to note "vendored as Ryoku source." Final grep audit. Delete `install/config/ryoku-shell-branding.sh` and `default/ryoku-shell/branding-replacements.tsv` (no longer referenced). **4 commits:** in-place test rewrite; auxiliary tests update; heritage doc + README update; branding script + TSV deletion. | All tests pass; final sweep shows iNiR refs only in `docs/`, `apps/ryoku-shell/`, NOTICE/LICENSE/CREDITS/README, the dual-name fallback branches, the dual-export env var lines, and gated-historical migrations |

### Sequencing Rationale

1→2 lays down the new source path and the new installer that consumes it, but doesn't yet rename anything user-visible. The system is still on `inir.service` at this point.

3→4 swaps the runtime identity (service/binary/CLI/keybinds). After chunk 4 a fresh install boots into `ryoku-shell.service`. **Existing live systems are still on `inir.service` until chunk 7 runs.** The dual-name fallback in chunk 4's lifecycle helpers (`bin/ryoku-restart-shell`, `bin/ryoku-restart-ui`, `bin/ryoku-launch-shell`) keeps unmigrated systems bootable across the release-internal window where chunk 4 has landed but chunk 7's migration hasn't yet run on a given machine.

5→6 cuts the upstream out of build-time and packaging. ISO builds and PKGBUILD stop referencing `snowarch/iNiR`.

7 migrates existing live systems. Last so it inherits the now-tested new code path.

8 closes the loop with tests + heritage doc + dual-name-fallback removal + retired-script deletion.

## Installed-System Migration Contract

This is the highest-risk chunk. The migration runs in the user's session, mutates user-owned paths, and stops the running shell mid-flight. Every step is sequenced for safety: legacy paths are deleted **only after the new service verifies as active**.

### Pre-Migration State on a Typical System

| Path | Owner | Carries User State? |
|---|---|---|
| `~/.local/share/inir/` | upstream-clone + branding patches | no (regenerable from vendor) |
| `~/.config/quickshell/inir/` | runtime sync of source tree | rarely (mostly mirrors `~/.local/share/inir/`) |
| `~/.config/inir/config.json` | user shell prefs | **yes, wallpaper, module toggles, theme** |
| `~/.config/systemd/user/inir.service` | branded service file | no |
| `~/.config/systemd/user/inir.service.d/qt6-qiooperation-patch.conf` | Qt6 patch drop-in (optional) | no, but only present on patched hosts |
| `~/.config/systemd/user/niri.service.wants/inir.service` | wants symlink | no |
| `~/.local/bin/inir` | Python launcher (upstream setup creates it) | no |
| `~/.local/state/quickshell/.venv` | Python venv (referenced by `INIR_VENV`) | yes (cached deps), **preserve in place, just re-point env var** |
| `~/.local/share/applications/inir.desktop` | desktop entry | no |
| `~/.local/share/icons/hicolor/scalable/apps/inir.svg` | icon | no |

### Migration Steps

```
1. Detect state
   LEGACY_SHELL_PRESENT  = -e ~/.local/share/inir   # -e covers both real dirs and symlinks
   NEW_SHELL_PRESENT     = -d ~/.local/share/ryoku-shell
   if !LEGACY_SHELL_PRESENT and NEW_SHELL_PRESENT:
       echo "already migrated"; exit 0
   if !LEGACY_SHELL_PRESENT and !NEW_SHELL_PRESENT:
       echo "no shell installed, will be handled by install/config/ryoku-shell.sh on next update"
       exit 0
   if -L ~/.local/share/inir:
       # Symlink (e.g., user has ~/.local/share/inir -> ~/proj/inir-dev for development).
       # We don't want to delete the target. Warn and refuse to migrate; user must
       # remove the symlink manually first, or move their dev checkout to apps/ryoku-shell/
       # in their Ryoku tree.
       echo "~/.local/share/inir is a symlink to $(readlink -f ~/.local/share/inir)" >&2
       echo "abort: refuse to auto-migrate a custom dev checkout" >&2
       echo "remove the symlink and re-run: rm ~/.local/share/inir" >&2
       exit 1

2. Snapshot gate (best-effort)
   ryoku-snapshot create "pre-ryoku-shell-rename" 2>&1 || warn "snapper unavailable, proceeding"

3. Stop legacy service (don't delete wants symlink yet, that's the rollback signal)
   systemctl --user stop inir.service 2>/dev/null || true

4. Carry over user state, DO THIS BEFORE TOUCHING ANYTHING ELSE
   mkdir -p ~/.config/ryoku-shell
   if [[ -f ~/.config/inir/config.json && ! -f ~/.config/ryoku-shell/config.json ]]; then
       cp -a ~/.config/inir/config.json ~/.config/ryoku-shell/config.json
   fi
   # Future: if iNiR users have written under ~/.config/quickshell/inir/, carry those too.
   # In practice that dir is a runtime sync of the source tree, not user state.

5. Invalidate Python venv so the new setup regenerates it cleanly
   # The venv may have shebangs, .pth files, or pip-recorded paths that reference
   # ~/.local/share/inir/. After the source dir rename, those become broken.
   # Wipe the venv; the new setup recreates it pointing at ~/.local/share/ryoku-shell/.
   # Cost: re-download/install Python deps once. Worth the safety.
   rm -rf ~/.local/state/quickshell/.venv

6. Run new install (lays down vendored tree, writes ryoku-shell.service, creates ~/.local/bin/ryoku-shell)
   bash $RYOKU_PATH/install/config/ryoku-shell.sh

7. Migrate the niri.service.wants symlink
   rm -f ~/.config/systemd/user/niri.service.wants/inir.service
   # The new install/config/ryoku-shell.sh already creates the new wants symlink in step 6.

8. Migrate the Qt6 patch drop-in (only if it was previously applied)
   if [[ -d ~/.config/systemd/user/inir.service.d ]]; then
       mkdir -p ~/.config/systemd/user/ryoku-shell.service.d
       for f in ~/.config/systemd/user/inir.service.d/*; do
           [[ -f $f && ! -f ~/.config/systemd/user/ryoku-shell.service.d/$(basename $f) ]] && \
               cp -a "$f" ~/.config/systemd/user/ryoku-shell.service.d/
       done
   fi

9. Daemon-reload + start new service
   systemctl --user daemon-reload
   systemctl --user start ryoku-shell.service

10. VERIFICATION GATE, wait up to 10s for new service to become active
    for i in {1..10}; do
        systemctl --user is-active --quiet ryoku-shell.service && break
        sleep 1
    done
    if ! systemctl --user is-active --quiet ryoku-shell.service; then
        echo "ryoku-shell.service failed to start; legacy paths preserved; abort cleanup" >&2
        echo "rollback: 'systemctl --user start inir.service' to restore old shell" >&2
        exit 1
    fi

11. Cleanup legacy paths (gated on step 10 success)
    # Note: step 1 already verified ~/.local/share/inir is not a symlink, so rm -rf is safe.
    rm -rf ~/.local/share/inir
    rm -rf ~/.config/quickshell/inir
    rm -rf ~/.config/inir          # config.json already copied in step 4
    rm -rf ~/.config/systemd/user/inir.service.d
    rm -f  ~/.config/systemd/user/inir.service
    rm -f  ~/.local/bin/inir
    rm -f  ~/.local/share/applications/inir.desktop
    rm -f  ~/.local/share/icons/hicolor/scalable/apps/inir.svg
    # INIR_VENV exports in user shell rc files (~/.bashrc, ~/.config/fish/conf.d): leave alone.
    # The dual-export in 40-environment.kdl (set during chunk 3) plus the fallback chain
    # in the matugen template means the legacy export is harmless. The dual-name cleanup
    # follow-up release removes both the dual-export and the legacy rc-file exports.

12. Final daemon-reload to clear stale unit references
    systemctl --user daemon-reload
```

### Failure Mode Matrix

| Failure point | Behavior | Recovery |
|---|---|---|
| Step 1 (legacy path is a symlink) | Abort with explicit message; do not touch the dev checkout | User removes the symlink manually, re-runs |
| Step 2 (snapshot create fails, snapper not installed) | Warn, proceed | None needed; no rollback path beyond the migration's own pre-step-10 safety |
| Step 4 (config.json copy permission error) | Abort with error | Fix permissions, re-run |
| Step 5 (venv wipe fails) | Highly unusual (own user files); would indicate an open file handle from another process | User stops the process, re-runs |
| Step 6 (`install/config/ryoku-shell.sh` fails) | Abort with error from that script | Same as today's `ryoku-update` failure handling, fix the issue, re-run; legacy paths intact |
| Step 9 (daemon-reload fails) | Highly unusual, would indicate broader systemd issue | User intervention; legacy `inir.service` still defined and startable |
| **Step 10 (new service fails to activate)** | **Abort before cleanup**, legacy paths preserved; new paths exist alongside; user can `systemctl --user start inir.service` to restore old shell while debugging | Re-run after fix; step 1 detection sees both present, redoes 3-10 |
| Step 11 partial (some rm fails) | Log; keep going (best-effort cleanup); the next run picks up remaining paths | Re-run; idempotent |

**Critical invariant:** legacy paths are deleted **only after step 10 verifies the new service is active**. If anything before step 10 fails, the system can boot back into the legacy shell with one command.

### Existing Migration `1777776000.sh`

Today it does:
```bash
sed -i [...] "$XDG_CONFIG_HOME/systemd/user/inir.service"
```

After the cutover, freshly migrated systems no longer have `~/.config/systemd/user/inir.service` (deleted in migration step 11). The migration's existing `[[ -f $tmp_service ]]` guard already handles this, it'll be a no-op on post-cutover hosts and still apply to pre-cutover hosts that haven't run the new migration yet. **No change required.**

The migration's *intent* (tune Ryoku shell resume recovery) needs to apply to `ryoku-shell.service` too on freshly-cut hosts. Commit 1b encodes the same tuning directly into `apps/ryoku-shell/assets/systemd/ryoku-shell.service`: drop `PartOf=graphical-session.target` and `Requisite=graphical-session.target`, set `RestartSec=1`. The vendored unit ships in its post-tuning shape, so fresh installs land in the same final state without needing the sed migration to apply later.

## Out of Scope (kept as-is)

| Surface | Why |
|---|---|
| `LICENSE`, `NOTICE` upstream attribution | Required by upstream MIT license |
| `CREDITS.md`, `README.md` Credits section mention of iNiR | Attribution; updated to clarify "now vendored as Ryoku source" but credit preserved |
| Historical `docs/superpowers/{specs,plans}/*.md` referencing inir | Records, not runtime instructions |
| `apps/ryoku-shell/CHANGELOG.md`, `CONTRIBUTING.md`, `README.md`, `docs/` | Vendored from upstream, historical context for the tree's own history. Add a Ryoku-vendor preamble at the top of `apps/ryoku-shell/README.md` noting the fork. |
| QML internal `Ii*` / `ii*` identifiers (`ShellIiPanels.qml`, `iiScreenFrame`, `iiPersist`, etc.) | Internal-only, never user-visible; renaming is multi-thousand-line churn for no functional gain |
| `dots/sddm/pixel/` directory name and `/usr/share/sddm/themes/ii-pixel` | External SDDM theme identifier; renaming would break theme lookup |
| LEAF script names `scripts/colors/switchwall.sh` and `scripts/daemon/keyboard_lock_state_daemon.py` (the file basenames, referenced from `bin/ryoku-shell-cleanup-orphans` `pkill` patterns) | Internal script names inside the vendored tree; stable contract. NOTE: the runtime PATH PREFIX `/quickshell/inir/` in those `pkill` patterns is NOT out of scope, it changes to `/quickshell/ryoku-shell/` in chunk 4 because the runtime config dir name changes. |
| Cleanup-only references in migrations to `~/.local/share/inir`, `~/.config/inir`, `inir.service` | These exist specifically to remove legacy state from pre-cutover systems. The migration in chunk 7 is one of these. |
| `distro/arch/quickshell-ryoku/PKGBUILD` `fix-extension-uaf.patch` filename | Patch is a Quickshell upstream patch, not iNiR-specific. Filename stays. PKGBUILD prose updates to drop "iNiR project" framing. |
| Comments referencing the iNiR upstream debugging context (e.g., `qt6-qiooperation-patch/apply.sh` header explaining the `iNiR / Ryoku` Quickshell crash chain) | Historical attribution for the bug-finding context; no functional code |

## docs/inir-heritage.md (new file, written in chunk 8)

Mirrors the structure of `docs/omarchy-heritage.md`. Sections:

- **Header:** "Ryoku began with iNiR as an external upstream, the shell layer cloned at install time from snowarch/iNiR, then patched in place. As of `<chunk-8 cutover date, filled in when the heritage doc commit lands>`, the iNiR source tree is vendored into Ryoku at `apps/ryoku-shell/` and Ryoku no longer has any external runtime, install, or update dependency on the iNiR repository."
- **What Still Remains:** table covering LICENSE/NOTICE attribution, CREDITS/README mentions, vendored docs/CHANGELOG/CONTRIBUTING, internal `Ii*` QML identifiers, `dots/sddm/pixel/` + `/usr/share/sddm/themes/ii-pixel`, cleanup-only migrations, qt6-qiooperation-patch comments, historical superpowers docs.
- **Current User-Facing Surfaces:** table covering `~/.local/share/ryoku-shell/`, `~/.config/quickshell/ryoku-shell/`, `~/.config/ryoku-shell/config.json`, `ryoku-shell.service`, `~/.local/bin/ryoku-shell`, `ryoku-shell <verb>`, `apps/ryoku-shell/`.
- **How To Review A New Reference:** five-bucket classification matching the omarchy-heritage doc (attribution / external-identifier / cleanup / historical-doc / active-runtime).

## README.md Credits Update

Today: `iNiR: the current shell layer and session UI Ryoku installs on top of Niri.`

After: `iNiR: the original shell project Ryoku's vendored shell at apps/ryoku-shell/ is forked from. See docs/inir-heritage.md.`

## Dual-Name Fallback Cleanup (deferred follow-up release)

The dual-name fallback added in chunk 4 (lifecycle helpers try `ryoku-shell.service` / `ryoku-shell` binary first, fall back to `inir.service` / `inir`) and the dual-export `INIR_VENV` / `RYOKU_SHELL_VENV` lines added in chunk 3 keep unmigrated systems bootable across the window where chunk 4 has landed but chunk 7's migration hasn't yet run on a given machine.

These fallbacks are **not removed in chunk 8**. They stay in place until a follow-up release in which:

1. All known dev/prod machines have run `ryoku-update` after the chunks 1-8 release and successfully migrated (verified by `ryoku-snapshot list` showing the `pre-ryoku-shell-rename` entry, or by `! [ -e ~/.local/share/inir ]` on each host).
2. A new release commits the cleanup: drop the `inir.service` / `inir` fallback branch from `bin/ryoku-restart-shell`, `bin/ryoku-restart-ui`, `bin/ryoku-launch-shell`; drop the `INIR_VENV` export line from `40-environment.kdl`; drop the `${INIR_VENV:-...}` fallback from `config/matugen/templates/kde/kde-material-you-colors-wrapper.sh`.
3. A second migration script (`migrations/<later-epoch>.sh`) cleans `INIR_VENV` exports from `~/.bashrc`, `~/.config/fish/conf.d/`, etc. on user shell rc files (best-effort sed).

This deferral exists because a user can `git pull` chunk-8 source without running `ryoku-update`, leaving them with new `bin/` scripts that no longer know about an unmigrated `inir.service`. The fallback is a small permanent cost with strong correctness guarantees during the window.

The follow-up release is its own spec when ready. This spec does not block on it.

## Verification Bar (per chunk)

Match the Omarchy independence rigor: maximal verification for every chunk because every chunk touches the display stack, the install path, or the ISO build.

For each chunk, verification at minimum:

- `tests/` suite green for the relevant test
- `bash -n` syntax check on every modified shell script
- `git status --short` clean after the chunk's commits
- The chunk's exit criteria from the chunk-queue table met (verbatim)

For chunks that produce a runnable change (3, 4, 5, 7):

- Live run of the affected command(s) on the dev machine
- For chunk 7 specifically: a dry-run on a snapshot before the live run

For the close-out (chunk 8):

- Final grep audit:
  ```
  grep -rE 'inir|iNiR|INIR' \
    --include='*.sh' --include='*.kdl' --include='*.qml' \
    --include='*.toml' --include='*.json' --include='*.css' \
    --include='*.conf' --include='*.service' --include='*.desktop' \
    --include='*.packages' \
    bin/ config/ default/ install/ iso/ tests/ migrations/ distro/ lib/
  ```
  Note: `apps/ryoku-shell/` is excluded from the audit (vendored upstream; its internal references are out of scope per the heritage doc). The audit returns only references that match an `docs/inir-heritage.md` rule, OR are in:
    - the dual-name fallback branches of `bin/ryoku-restart-shell` / `bin/ryoku-restart-ui` / `bin/ryoku-launch-shell`,
    - the dual-export `INIR_VENV` line in `config/niri/config.d/40-environment.kdl`,
    - the `${INIR_VENV:-...}` fallback in `config/matugen/templates/kde/kde-material-you-colors-wrapper.sh`,
    - cleanup-only references in migrations.
  All four of these go away in the dual-name cleanup follow-up release (see "Dual-Name Fallback Cleanup" above).
- Live `systemctl --user is-active ryoku-shell.service` returns `active`.
- Live `~/.local/bin/ryoku-shell --help` works.
- Live `ryoku-ipc overview toggle` opens the overview.
- Live `ryoku-ipc lock activate` activates lock.
- ISO build with `RYOKU_INIR_*` env unset succeeds and produces a working live ISO.

## Decisions Open at Implementation Time

A short list of items that are decided **at the start of chunk 1**, not at spec time:

1. **Upstream sha to vendor from.** Whatever `git -C ~/.local/share/inir rev-parse HEAD` reports on the implementation machine at chunk 1 start. Recorded in commit 1a's body.
2. **Whether the iNiR `setup` script needs a tiny patch in commit 1b** to handle running from `~/.local/share/ryoku-shell` instead of `~/.local/share/inir`. Verified by reading `apps/ryoku-shell/setup` after the raw import; if it uses `BASH_SOURCE`/`pwd` no patch needed; if it has a hardcoded `inir` path string, add a one-line patch.
3. **Whether `~/.config/quickshell/inir/` carries any user state on the implementation machine.** In the upstream design it's a runtime sync of the source tree, not user state, verified by `find ~/.config/quickshell/inir -type f -newer ~/.local/share/inir/setup` at chunk 7 start. If files exist that are newer than the source tree (suggesting user edits), expand step 4 of the migration to carry them over.

## Commit Discipline

- No `--no-verify`. No AI trailers. No commit rewrites of prior history.
- Additive only, every commit is a new commit on top of `niri-inir-transition` (or whichever branch the work lands on).
- Many small commits within each chunk so individual steps can be reverted via `git revert <sha>`.
- Each commit's subject and body follow the existing repo convention (visible in `git log --oneline | head`).
- Each chunk's final commit (or its own dedicated doc-update commit, depending on chunk size) updates `docs/superpowers/` with the chunk's outcome if material.
