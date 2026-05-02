# Ryoku Shell Rebrand Implementation Plan

> **For Carlos:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to execute this plan task-by-task.

**Goal:** Rebrand the current Niri shell integration so installed user-facing surfaces say Ryoku, install Ryoku branding assets and default colors, and keep the deeper source rename for later phases.

**Architecture:** Keep the working upstream shell checkout as the runtime substrate for Phase 1. Add a Ryoku overlay script that patches visible labels/assets/config after setup. Add a shipped Ryoku theme and make the installer select it by default. Later phases replace compatibility names with Ryoku wrappers and finally a full fork if needed.

**Tech Stack:** Bash install scripts, Ryoku theme files, jq JSON merge, systemd user units, existing shell tests.

---

## Phase 0: Plan And Commit Safety Baseline

**Scope:** Documentation only.

**Tasks:**

- [x] Create `docs/superpowers/specs/2026-05-02-ryoku-shell-rebrand-design.md`.
- [x] Create this implementation plan.
- [x] Commit the spec.
- [x] Commit the plan.

**Verification:**

```bash
git status --short
rg -n "Phase 1|Phase 2|Phase 3|Phase 4|Phase 5|Phase 6" docs/superpowers/specs/2026-05-02-ryoku-shell-rebrand-design.md docs/superpowers/plans/2026-05-02-ryoku-shell-rebrand.md
```

---

## Phase 1: Safe Ryoku Overlay

**Scope:** Execute now.

**Status:** Completed on 2026-05-02. The Ryoku theme, overlay, installer wiring, runtime labels, migration, live application, focused checks, and post-completion theme ownership fix are complete. Continue at Phase 2 in the next session.

**Completion Commits:**

- `e46fed54 feat: add ryoku default theme`
- `ce107eb7 feat: default fresh installs to ryoku theme`
- `2955a2ff feat: add ryoku shell branding overlay`
- `08f9ffcd feat: apply ryoku shell branding during install`
- `8fdee755 chore: use ryoku labels for shell runtime`
- `03b7ee8e test: cover ryoku shell branding contract`
- `166bc354 chore: migrate installs to ryoku shell branding`
- `09dac22d fix: brand shell hotspot defaults`
- `46f63e40 fix: format asus keyboard color for theme sync`
- `fadf1607 docs: mark ryoku shell phase one complete`
- `4ecc278d fix: keep ryoku themes from shell color override`

### Task 1: Add Rebrand Contract Test

**Status:** Completed by `03b7ee8e`.

**Files:**

- `tests/ryoku-shell-branding.sh`

**Steps:**

- Add a shell test that verifies the Phase 1 contract:
  - `themes/ryoku/colors.toml` exists.
  - `install/config/theme.sh` selects the `ryoku` theme.
  - `install/config/ryoku-shell-branding.sh` exists and is executable.
  - `install/config/inir.sh` invokes the Ryoku branding overlay.
  - `config/systemd/user/inir.service` uses Ryoku-visible description text.
  - Ryoku helper messages do not expose upstream shell branding to normal users.
  - Upstream credit remains in `CREDITS.md`.

**Verification:**

```bash
bash tests/ryoku-shell-branding.sh
```

Expected first run before implementation: fails on missing overlay/theme pieces.

**Commit after green:**

```bash
git add tests/ryoku-shell-branding.sh
git commit -m "test: cover ryoku shell branding contract"
```

### Task 2: Add Shipped Ryoku Theme

**Status:** Completed by `e46fed54`.

**Files:**

- `themes/ryoku/colors.toml`
- `themes/ryoku/btop.theme`
- `themes/ryoku/icons.theme`
- `themes/ryoku/vscode.json`
- `themes/ryoku/backgrounds/`

**Steps:**

- Create the Ryoku theme using the approved Greek Noir based Ryoku palette:
  - accent: `#F25623`
  - background: `#171717`
  - foreground: `#CCD0CF`
  - secondary green: `#88A57D`
- Add at least one Ryoku branded default background asset.
- Keep theme file structure consistent with existing themes.

**Verification:**

```bash
ls themes/ryoku
sed -n '1,120p' themes/ryoku/colors.toml
bash tests/ryoku-shell-branding.sh
```

**Commit:**

```bash
git add themes/ryoku tests/ryoku-shell-branding.sh
git commit -m "feat: add ryoku default theme"
```

### Task 3: Make Ryoku The Fresh Install Theme

**Status:** Completed by `ce107eb7`.

**Files:**

- `install/config/theme.sh`

**Steps:**

- Remove the external Omarchy-derived default theme install path.
- Set the default theme with `ryoku-theme-set "ryoku"`.
- Keep the script idempotent.

**Verification:**

```bash
bash -n install/config/theme.sh
rg -n "omarchy|Greek Noir|ryoku-theme-set" install/config/theme.sh
bash tests/ryoku-shell-branding.sh
```

**Commit:**

```bash
git add install/config/theme.sh tests/ryoku-shell-branding.sh
git commit -m "feat: default fresh installs to ryoku theme"
```

### Task 4: Add Ryoku Shell Branding Overlay

**Status:** Completed by `2955a2ff`, with config ownership hardening in `09dac22d` and `4ecc278d`.

**Files:**

- `install/config/ryoku-shell-branding.sh`
- `default/ryoku-shell/config-overrides.json`
- `default/ryoku-shell/branding-replacements.tsv`

**Steps:**

- Create an executable overlay script.
- Resolve the shell checkout path from `RYOKU_SHELL_PATH`, then compatibility env vars, then the current default path.
- Copy Ryoku logo assets into the shell checkout where the current UI expects icons.
- Patch targeted visible strings in welcome, desktop, service, and SDDM source files.
- Merge `default/ryoku-shell/config-overrides.json` into the user shell config when `jq` exists.
- Print Ryoku-facing status messages only.
- Make every operation safe when the shell checkout is missing.

**Verification:**

```bash
bash -n install/config/ryoku-shell-branding.sh
bash tests/ryoku-shell-branding.sh
RYOKU_PATH="$PWD" RYOKU_SHELL_PATH="/tmp/ryoku-shell-probe" bash install/config/ryoku-shell-branding.sh
```

**Commit:**

```bash
git add install/config/ryoku-shell-branding.sh default/ryoku-shell tests/ryoku-shell-branding.sh
git commit -m "feat: add ryoku shell branding overlay"
```

### Task 5: Wire Overlay Into Installer

**Status:** Completed by `08f9ffcd`.

**Files:**

- `install/config/inir.sh`

**Steps:**

- Run the Ryoku branding overlay after upstream setup completes.
- Keep launcher compatibility checks intact for Phase 1.
- Change normal installer output so it says Ryoku shell.

**Verification:**

```bash
bash -n install/config/inir.sh
bash tests/ryoku-shell-branding.sh
```

**Commit:**

```bash
git add install/config/inir.sh tests/ryoku-shell-branding.sh
git commit -m "feat: apply ryoku shell branding during install"
```

### Task 6: Update Ryoku Runtime Messages And Service Labels

**Status:** Completed by `8fdee755`.

**Files:**

- `config/systemd/user/inir.service`
- `bin/ryoku-theme-bg-set`
- `bin/ryoku-theme-bg-next`
- `bin/ryoku-restart-ui`
- `config/matugen/config.toml`

**Steps:**

- Replace user-visible upstream shell names with Ryoku wording.
- Keep internal command/path compatibility unchanged.
- Rename helper functions where useful, but avoid behavior changes.

**Verification:**

```bash
bash -n bin/ryoku-theme-bg-set bin/ryoku-theme-bg-next bin/ryoku-restart-ui
systemd-analyze --user verify config/systemd/user/inir.service
bash tests/ryoku-shell-branding.sh
```

**Commit:**

```bash
git add config/systemd/user/inir.service bin/ryoku-theme-bg-set bin/ryoku-theme-bg-next bin/ryoku-restart-ui config/matugen/config.toml tests/ryoku-shell-branding.sh
git commit -m "chore: use ryoku labels for shell runtime"
```

### Task 7: Add Existing Install Migration

**Status:** Completed by `166bc354`.

**Files:**

- `migrations/<timestamp>.sh`

**Steps:**

- Create the migration with `ryoku-dev-add-migration --no-edit`.
- Apply the overlay script when present.
- Apply the Ryoku theme when present.
- Do not fail an upgrade if the shell checkout has not been installed yet.

**Verification:**

```bash
bash -n migrations/<timestamp>.sh
bash tests/ryoku-shell-branding.sh
```

**Commit:**

```bash
git add migrations/<timestamp>.sh tests/ryoku-shell-branding.sh
git commit -m "chore: migrate installs to ryoku shell branding"
```

### Task 8: Live Application Probe

**Status:** Completed on the live user session. `inir.service` reports `Ryoku shell`; the actual running shell process is `qs`.

**Scope:** Run after repository implementation is green.

**Steps:**

- Apply the overlay to the current live install if the shell checkout exists.
- Restart the Ryoku UI layer through the existing helper.
- Probe service status and shell processes.

**Verification:**

```bash
RYOKU_PATH="$PWD" bash install/config/ryoku-shell-branding.sh
ryoku-restart-ui --quiet
systemctl --user status inir.service --no-pager
pgrep -a -x qs
```

**Commit:** None unless repository files change during the live probe.

### Task 9: Preserve Selected Ryoku Theme Colors

**Status:** Completed by `4ecc278d`.

**Reason:** After Phase 1, changing themes briefly showed the selected Ryoku colors, then the shell wallpaper color generator overwrote terminal/app colors with a lighter generated Material palette.

**Files:**

- `bin/ryoku-theme-set-shell`
- `bin/ryoku-theme-set`
- `default/ryoku-shell/config-overrides.json`
- `tests/ryoku-theme-shell-sync.sh`
- `tests/ryoku-shell-branding.sh`
- `tests/niri-inir-merge-readiness.sh`

**Verification:**

```bash
bash tests/ryoku-theme-shell-sync.sh
bash tests/ryoku-shell-branding.sh
bash tests/niri-inir-merge-readiness.sh
```

**Live Check:**

```bash
ryoku-theme-set ryoku
jq -r '.appearance.wallpaperTheming.enableTerminal, .appearance.palette.accentColor' ~/.config/inir/config.json
sed -n '1,16p' ~/.config/alacritty/colors.toml
```

---

## Phase 2: Legacy Tooling Inventory And Port

**Scope:** Deferred, but must happen before deeper wrapper/source rename work.

**Files:**

- `docs/legacy-tooling-inventory.md`
- `tests/niri-legacy-tooling.sh`
- Legacy runtime files discovered during inventory

**Tasks:**

- Inventory all old pre-Niri runtime surfaces:
  - `bin/ryoku-*` commands
  - `install/config/*.sh` setup scripts
  - `config/systemd/user/*.service` and timers
  - `config/hypr`, `config/niri`, lockscreen, idle, notification, launcher, OSD, wallpaper, and screenshot configs
  - `default/`, `themes/`, `migrations/`, boot branding, SDDM, Plymouth, and Limine assets
- Classify each item as:
  - keep unchanged
  - port to Niri/Ryoku shell
  - replace with a Niri-native tool
  - remove after equivalent is verified
- Keep Ryoku-owned compositor-independent tools:
  - theme and wallpaper helpers
  - screenshot and recording helpers
  - screensavers
  - package and hardware helpers
  - dev scanners and githooks
  - setup wizards that still apply
  - boot, SDDM, Plymouth, and Limine branding
- Port old shell-specific Ryoku tools:
  - restart helpers
  - launcher IPC helpers
  - notification and OSD helpers
  - lock and idle integration
  - wallpaper application paths
- Replace or remove old shell-specific pieces only after the inventory proves the Niri path exists:
  - Hyprland configs, services, and binds
  - Waybar
  - Walker
  - Hyprlock
  - Hypridle
  - stale notification or OSD setup
  - old Omarchy paths and packages
- Add a test that fails if fresh install paths still enable old Hyprland or Omarchy runtime files.
- Add a test that proves retained screensavers are still shipped.

**Verification:**

```bash
bash tests/niri-legacy-tooling.sh
rg -n "hyprland|hyprlock|hypridle|waybar|walker|omarchy" bin install config default themes migrations docs
```

The `rg` output must be reviewed against the inventory. Remaining matches need an explicit keep/port/remove decision.

**Commit:**

```bash
git add docs/legacy-tooling-inventory.md tests/niri-legacy-tooling.sh <ported-files>
git commit -m "docs: inventory legacy ryoku tooling for niri"
```

---

## Phase 3: Ryoku Shell Wrappers And Service Names

**Scope:** Deferred.

**Tasks:**

- Add `bin/ryoku-shell` wrapper for the current launcher.
- Add `config/systemd/user/ryoku-shell.service`.
- Point Niri autostart and restart helpers at `ryoku-shell.service`.
- Keep compatibility links for old service names for one migration window.
- Add tests that prove no Niri bind or Ryoku helper calls the old name directly except in wrappers.

**Verification:**

```bash
systemctl --user daemon-reload
systemctl --user enable --now ryoku-shell.service
systemctl --user status ryoku-shell.service --no-pager
ryoku-restart-ui --quiet
```

---

## Phase 4: Offline ISO Shell Source

**Scope:** Deferred.

**Tasks:**

- Pin the upstream shell source version for Ryoku.
- Store the source tarball, git bundle, or package artifact in the ISO build inputs.
- Make `install/config/inir.sh` prefer bundled content and use network clone only as a development fallback.
- Add a scanner that fails when shell source is required from the network during offline ISO mode.

**Verification:**

```bash
RYOKU_OFFLINE=1 ./setup install -y --skip-deps --skip-sysupdate
```

---

## Phase 5: Full Source Fork Rebrand

**Scope:** Deferred.

**Tasks:**

- Decide whether to fork source permanently or maintain a patchset.
- Rename public commands, desktop files, schemas, and docs.
- Migrate config files from compatibility paths into Ryoku paths.
- Add one-time migration for existing installs.
- Update leak scanners so the upstream shell name is allowed only in credits and licenses.

**Verification:**

```bash
rg -n "upstream shell legacy names" config install bin themes docs
```

Use the real scanner from the phase implementation instead of the placeholder query above.

---

## Phase 6: Remove Compatibility

**Scope:** Deferred until after at least one tested ISO.

**Tasks:**

- Remove compatibility service and command bridges.
- Remove old path fallbacks from installers.
- Remove migration code that only supported the transition.
- Update public docs to describe only the final Ryoku shell paths.

**Verification:**

```bash
./setup doctor
bash tests/ryoku-shell-branding.sh
```
