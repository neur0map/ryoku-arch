# SKWD-Wall Ryoku Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Ryoku's partial wallpaper selector with an upstream-faithful SKWD-wall visual port, backed by Ryoku-owned IPC, paths, services, wallpaper apply behavior, and SKWD-styled theme/font/cursor modes.

**Architecture:** Keep upstream SKWD-wall byte-for-byte under a pinned `upstream/` vendor tree, then maintain Ryoku integration code under `ryoku/`. Copy and adapt SKWD-daemon into `src/ryoku-wallpaper-daemon/`, expose its upstream-compatible JSON-RPC protocol over `$XDG_RUNTIME_DIR/ryoku/wallpaper-daemon.sock`, and route system actions through Ryoku commands. Keep Brain_Shell's existing `WallpaperPopup.qml` entry point as a thin compatibility wrapper for `BS.Popups.wallpaperOpen`, `wallpaperVisible`, and `wallpaperMode`.

**Tech Stack:** Quickshell/QML, Qt Quick/Shapes/Effects/Multimedia, Bash 5, Rust/Cargo/Tokio/Rusqlite, systemd user services, existing Ryoku shell IPC and wallpaper commands.

---

## Source Pins

- `liixini/skwd-wall` commit: `f8e22a4`
- `liixini/skwd-daemon` commit: `2d48800`
- Design spec: `docs/superpowers/specs/2026-05-01-skwd-wall-ryoku-integration-design.md`

If `/tmp/skwd-wall-upstream` or `/tmp/skwd-daemon-upstream` is missing, fetch them before Task 2:

```bash
git clone https://github.com/liixini/skwd-wall /tmp/skwd-wall-upstream
git -C /tmp/skwd-wall-upstream checkout f8e22a4
git clone https://github.com/liixini/skwd-daemon /tmp/skwd-daemon-upstream
git -C /tmp/skwd-daemon-upstream checkout 2d48800
```

## File Structure

Create:

- `config/quickshell/ryoku/vendor/skwd-wall/upstream/` - exact upstream SKWD-wall source.
- `config/quickshell/ryoku/vendor/skwd-wall/ryoku/` - Ryoku QML wrapper and patched integration copy.
- `config/quickshell/ryoku/vendor/skwd-wall/ryoku/RyokuWallpaperSelectorHost.qml` - bridges Ryoku popup state to SKWD wallpaper and appearance selectors.
- `config/quickshell/ryoku/vendor/skwd-wall/ryoku/appearance/AppearanceSelector.qml` - SKWD-styled theme/font/cursor selector.
- `config/quickshell/ryoku/vendor/skwd-wall/ryoku/appearance/AppearanceSelectorService.qml` - loads theme/font/cursor data from existing Ryoku services.
- `config/quickshell/ryoku/vendor/skwd-wall/ryoku/appearance/AppearanceChoiceCard.qml` - skewed SKWD-style cards for non-wallpaper choices.
- `src/ryoku-wallpaper-daemon/` - adapted Rust workspace copied from upstream SKWD-daemon.
- `src/ryoku-wallpaper-daemon/UPSTREAM.md` - upstream source pin and adaptation notes.
- `bin/ryoku-wallpaper-daemon` - Ryoku command wrapper that builds/runs the checked-in Rust daemon.
- `bin/ryoku-wallpaperctl` - Ryoku debug client for JSON-RPC calls.
- `config/systemd/user/ryoku-wallpaper-daemon.service` - user service.
- `migrations/1777644985.sh` - installs/enables the user service for existing systems.
- `tests/skwd-wall-vendor.sh` - vendor, drift, attribution, and package checks.
- `tests/ryoku-wallpaper-daemon.sh` - daemon source, wrapper, service, socket, path, and apply-routing checks.

The tests introduced in Task 1 are red until their owned implementation tasks are complete. Keep those test edits unstaged during intermediate commits, then stage them with the first commit where their commands exit 0.

Modify:

- `config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperPopup.qml` - replace current partial visual implementation with a compatibility wrapper.
- `config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml` - keep `WallpaperPopup {}` mounted.
- `config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml` - keep existing popup contract stable; add mode helper functions only if needed.
- `config/quickshell/ryoku/vendor/brain-shell/src/services/qmldir` - keep existing services and add no SKWD singleton here unless the wrapper requires it.
- `tests/quickshell-wallpaper-skwd.sh` - move assertions from current partial SKWD clone to vendor/wrapper/extension checks.
- `tests/quickshell-wallpaper-switcher.sh` - keep popup-state/keybind assertions and replace bottom-sheet-only checks.
- `tests/ryoku-ipc.sh` - keep existing IPC checks; add daemon debug command only if `ryoku-ipc` gains one.
- `README.md`, `CREDITS.md`, `NOTICE`, `config/quickshell/ryoku/vendor/skwd-wall/UPSTREAM.md`.
- `install/ryoku-base.packages`, `install/ryoku-aur.packages`, and ISO package overlays if the dependency audit finds missing required packages.

---

### Task 1: Add Failing Guardrail Tests

**Files:**
- Create: `tests/skwd-wall-vendor.sh`
- Create: `tests/ryoku-wallpaper-daemon.sh`
- Modify: `tests/quickshell-wallpaper-switcher.sh`
- Modify: `tests/quickshell-wallpaper-skwd.sh`

- [ ] **Step 1: Add the SKWD vendor guardrail test**

Create `tests/skwd-wall-vendor.sh` with:

```bash
#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

root="config/quickshell/ryoku/vendor/skwd-wall"
upstream="$root/upstream"
ryoku="$root/ryoku"
base_packages="install/ryoku-base.packages"
readme="README.md"
credits="CREDITS.md"
notice="NOTICE"

[[ -d $upstream/qml/wallpaper ]] || fail "upstream SKWD wallpaper QML missing"
[[ -d $upstream/data/matugen/templates ]] || fail "upstream SKWD matugen templates missing"
[[ -f $upstream/shell.qml ]] || fail "upstream shell.qml missing"
[[ -f $root/LICENSE ]] || fail "root SKWD-wall license missing"
[[ -f $root/UPSTREAM.md ]] || fail "root SKWD-wall upstream notes missing"
[[ -f $ryoku/RyokuWallpaperSelectorHost.qml ]] || fail "Ryoku SKWD host missing"
[[ -f $ryoku/qml/services/DaemonClient.qml ]] || fail "Ryoku-patched DaemonClient missing"
[[ -f $ryoku/qml/Config.qml ]] || fail "Ryoku-patched Config missing"

grep -q 'liixini/skwd-wall' "$root/UPSTREAM.md" \
  || fail "UPSTREAM.md should identify liixini/skwd-wall"
grep -q 'f8e22a4' "$root/UPSTREAM.md" \
  || fail "UPSTREAM.md should pin the SKWD-wall commit"
grep -q 'Copyright (c) 2026 liixini' "$root/LICENSE" \
  || fail "SKWD-wall MIT copyright notice missing"
! rg -q 'RYOKU_|ryoku-wallpaper|/ryoku/' "$upstream/qml" "$upstream/shell.qml" \
  || fail "upstream SKWD tree should stay free of Ryoku integration edits"
grep -q 'SKWD-wall' "$readme" \
  || fail "README Credits should mention SKWD-wall"
grep -q 'SKWD-wall' "$credits" \
  || fail "CREDITS.md should mention SKWD-wall"
grep -q 'SKWD-daemon' "$credits" \
  || fail "CREDITS.md should mention SKWD-daemon"
grep -q 'liixini/skwd-wall' "$notice" \
  || fail "NOTICE should mention SKWD-wall"

grep -q 'path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku/wallpaper-daemon.sock"' "$ryoku/qml/services/DaemonClient.qml" \
  || fail "DaemonClient should use the Ryoku socket path"
grep -q 'RYOKU_WALLPAPER_DIR' "$ryoku/qml/Config.qml" \
  || fail "Config should read Ryoku wallpaper directory"
grep -q 'RYOKU_STATE_PATH' "$ryoku/qml/Config.qml" \
  || fail "Config should read Ryoku state path"
grep -q 'WlrLayershell.namespace: "ryoku-wallpaper-selector"' "$ryoku/qml/wallpaper/WallpaperSelector.qml" \
  || fail "Ryoku selector should use a Ryoku layershell namespace"

grep -qx 'qt6-declarative' "$base_packages" \
  || fail "qt6-declarative should be a base dependency"
grep -qx 'qt6-multimedia' "$base_packages" \
  || fail "qt6-multimedia should be a base dependency"
grep -qx 'qt6-multimedia-ffmpeg' "$base_packages" \
  || fail "qt6-multimedia-ffmpeg should be a base dependency"
grep -qx 'qt6-imageformats' "$base_packages" \
  || fail "qt6-imageformats should be a base dependency for SKWD thumbnails/previews"
grep -qx 'rust' "$base_packages" \
  || fail "rust should be a base dependency for the checked-in daemon source"

pass "skwd-wall vendor guardrails"
```

- [ ] **Step 2: Add the daemon guardrail test**

Create `tests/ryoku-wallpaper-daemon.sh` with:

```bash
#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

src="src/ryoku-wallpaper-daemon"
wrapper="bin/ryoku-wallpaper-daemon"
ctl="bin/ryoku-wallpaperctl"
service="config/systemd/user/ryoku-wallpaper-daemon.service"
migration="migrations/1777644985.sh"
proto="$src/crates/proto/src/lib.rs"
config="$src/crates/daemon/src/config.rs"
db="$src/crates/daemon/src/db.rs"
apply="$src/crates/daemon/src/wall/apply.rs"

[[ -f $src/Cargo.toml ]] || fail "daemon Cargo workspace missing"
[[ -f $src/Cargo.lock ]] || fail "daemon Cargo lockfile missing"
[[ -f $src/LICENSE ]] || fail "daemon license missing"
[[ -f $src/UPSTREAM.md ]] || fail "daemon upstream notes missing"
[[ -x $wrapper ]] || fail "ryoku-wallpaper-daemon wrapper should be executable"
[[ -x $ctl ]] || fail "ryoku-wallpaperctl wrapper should be executable"
[[ -f $service ]] || fail "ryoku-wallpaper-daemon user service missing"
[[ -f $migration ]] || fail "service migration missing"

grep -q 'name = "ryoku-wallpaper-daemon"' "$src/crates/daemon/Cargo.toml" \
  || fail "daemon crate should be renamed"
grep -q 'name = "ryoku-wallpaperctl"' "$src/crates/cli/Cargo.toml" \
  || fail "debug client crate should be renamed"
grep -q 'name = "ryoku-wallpaper-proto"' "$src/crates/proto/Cargo.toml" \
  || fail "proto crate should be renamed"
grep -q 'join("ryoku").join("wallpaper-daemon.sock")' "$proto" \
  || fail "proto socket path should be in the Ryoku namespace"
grep -q 'RYOKU_WALLPAPER_DIR' "$config" \
  || fail "daemon config should use RYOKU_WALLPAPER_DIR"
grep -q 'RYOKU_STATE_PATH' "$config" \
  || fail "daemon config should use RYOKU_STATE_PATH"
grep -q 'RYOKU_CONFIG_PATH' "$config" \
  || fail "daemon config should use RYOKU_CONFIG_PATH"
grep -q 'RYOKU_PATH' "$config" \
  || fail "daemon config should use RYOKU_PATH for vendored scripts/templates"
grep -q 'ryoku-wallpaper-apply' "$apply" \
  || fail "daemon apply should delegate to ryoku-wallpaper-apply"
grep -q 'wallpaper-meta.json' "$db" \
  || fail "daemon should import existing Ryoku wallpaper metadata"
grep -q 'ExecStart=%h/.local/share/ryoku/bin/ryoku-wallpaper-daemon' "$service" \
  || fail "systemd service should start the Ryoku daemon command"
grep -q 'systemctl --user enable --now ryoku-wallpaper-daemon.service' "$migration" \
  || fail "migration should enable and start the daemon service"

if command -v cargo >/dev/null; then
  cargo test --manifest-path "$src/Cargo.toml" --workspace
fi

pass "ryoku wallpaper daemon guardrails"
```

- [ ] **Step 3: Update popup switcher assertions**

In `tests/quickshell-wallpaper-switcher.sh`, keep the existing IPC/keybind assertions and replace bottom-sheet-specific checks with this wrapper contract:

```bash
grep -q 'WallpaperPopup' "$layer" \
  || fail "PopupLayer should instantiate WallpaperPopup"
! grep -q '^[[:space:]]*//[[:space:]]*WallpaperPopup' "$layer" \
  || fail "WallpaperPopup should not remain dormant"
grep -q 'Binding { target: Popups; property: "wallpaperVisible"' "$wallpaper_popup" \
  || fail "WallpaperPopup should expose visual presence to TopBar"
grep -q 'RyokuSkwd.RyokuWallpaperSelectorHost' "$wallpaper_popup" \
  || fail "WallpaperPopup should load the Ryoku SKWD host"
grep -q 'open: Popups.wallpaperOpen' "$wallpaper_popup" \
  || fail "WallpaperPopup should bind open state to Popups.wallpaperOpen"
grep -q 'mode: Popups.wallpaperMode' "$wallpaper_popup" \
  || fail "WallpaperPopup should bind mode state to Popups.wallpaperMode"
grep -q 'onDismissed: Popups.wallpaperOpen = false' "$wallpaper_popup" \
  || fail "WallpaperPopup should close Ryoku popup state when SKWD dismisses"
```

Remove checks in that test that require `selectorMaxWidth`, `selectorHeight`, `PopupShape`, bottom-edge `y:`, and current partial-card classes inside `WallpaperPopup.qml`.

- [ ] **Step 4: Update SKWD visual assertions**

In `tests/quickshell-wallpaper-skwd.sh`, keep service tests only for theme/font/cursor existing services. Move wallpaper visual checks to the SKWD vendor tree:

```bash
skwd_root="config/quickshell/ryoku/vendor/skwd-wall"
host="$skwd_root/ryoku/RyokuWallpaperSelectorHost.qml"
selector="$skwd_root/ryoku/qml/wallpaper/WallpaperSelector.qml"
slice="$skwd_root/ryoku/qml/wallpaper/SliceDelegate.qml"
settings="$skwd_root/ryoku/qml/wallpaper/SettingsPanel.qml"
appearance_selector="$skwd_root/ryoku/appearance/AppearanceSelector.qml"
appearance_card="$skwd_root/ryoku/appearance/AppearanceChoiceCard.qml"

[[ -f $host ]] || fail "Ryoku SKWD host missing"
[[ -f $selector ]] || fail "Ryoku SKWD wallpaper selector missing"
[[ -f $slice ]] || fail "Ryoku SKWD slice delegate missing"
[[ -f $settings ]] || fail "Ryoku SKWD settings panel missing"
[[ -f $appearance_selector ]] || fail "Ryoku SKWD appearance selector missing"
[[ -f $appearance_card ]] || fail "Ryoku SKWD appearance card missing"

grep -q 'WallpaperSelector' "$host" \
  || fail "host should mount the SKWD wallpaper selector"
grep -q 'AppearanceSelector' "$host" \
  || fail "host should mount the Ryoku SKWD-styled appearance selector"
grep -q 'property bool showing' "$selector" \
  || fail "SKWD selector should keep upstream showing state"
grep -q 'property bool settingsOpen' "$selector" \
  || fail "SKWD selector should keep upstream settings surface"
grep -q 'SettingsPanel' "$selector" \
  || fail "SKWD selector should render upstream settings panel"
grep -q 'roundCorners' "$slice" \
  || fail "SKWD slice delegate should keep rounded-corner support"
grep -q 'QtQuick.Shapes' "$slice" \
  || fail "SKWD slice delegate should use QtQuick Shapes"
grep -q 'MultiEffect' "$slice" \
  || fail "SKWD slice delegate should use masked visuals"
grep -q 'ThemeService.refresh' "$appearance_selector" \
  || fail "appearance selector should load Ryoku themes"
grep -q 'FontService.refresh' "$appearance_selector" \
  || fail "appearance selector should load Ryoku fonts"
grep -q 'CursorService.refresh' "$appearance_selector" \
  || fail "appearance selector should load Ryoku cursors"
grep -q 'ThemeService.applyTheme' "$appearance_selector" \
  || fail "appearance selector should apply Ryoku themes"
grep -q 'FontService.applyFont' "$appearance_selector" \
  || fail "appearance selector should apply Ryoku fonts"
grep -q 'CursorService.applyCursor' "$appearance_selector" \
  || fail "appearance selector should apply Ryoku cursors"
```

- [ ] **Step 5: Run the new failing tests**

Run:

```bash
tests/skwd-wall-vendor.sh
```

Expected: exit 1 with `FAIL: upstream SKWD wallpaper QML missing`.

Run:

```bash
tests/ryoku-wallpaper-daemon.sh
```

Expected: exit 1 with `FAIL: daemon Cargo workspace missing`.

Run:

```bash
tests/quickshell-wallpaper-switcher.sh
```

Expected: exit 1 until `WallpaperPopup.qml` becomes a SKWD host wrapper.

---

### Task 2: Vendor Upstream SKWD-Wall Exactly

**Files:**
- Create: `config/quickshell/ryoku/vendor/skwd-wall/upstream/`
- Create: `config/quickshell/ryoku/vendor/skwd-wall/ryoku/qml/`
- Create/Modify: `config/quickshell/ryoku/vendor/skwd-wall/LICENSE`
- Create/Modify: `config/quickshell/ryoku/vendor/skwd-wall/UPSTREAM.md`
- Modify: `install/ryoku-base.packages`

- [ ] **Step 1: Copy pinned SKWD-wall source**

Run:

```bash
mkdir -p config/quickshell/ryoku/vendor/skwd-wall/upstream
cp -a /tmp/skwd-wall-upstream/shell.qml config/quickshell/ryoku/vendor/skwd-wall/upstream/
cp -a /tmp/skwd-wall-upstream/qml config/quickshell/ryoku/vendor/skwd-wall/upstream/
cp -a /tmp/skwd-wall-upstream/data config/quickshell/ryoku/vendor/skwd-wall/upstream/
cp -a /tmp/skwd-wall-upstream/LICENSE config/quickshell/ryoku/vendor/skwd-wall/upstream/LICENSE
cp -a /tmp/skwd-wall-upstream/LICENSE config/quickshell/ryoku/vendor/skwd-wall/LICENSE
mkdir -p config/quickshell/ryoku/vendor/skwd-wall/ryoku
cp -a /tmp/skwd-wall-upstream/qml config/quickshell/ryoku/vendor/skwd-wall/ryoku/
```

- [ ] **Step 2: Write upstream notes**

Set `config/quickshell/ryoku/vendor/skwd-wall/UPSTREAM.md` to:

```markdown
# SKWD-wall Vendor Notes

- Upstream: https://github.com/liixini/skwd-wall
- Commit: f8e22a4
- License: MIT
- Copyright: Copyright (c) 2026 liixini

## Layout

- `upstream/` is a byte-for-byte copy of upstream `shell.qml`, `qml/`, `data/`, and `LICENSE`.
- `ryoku/qml/` starts as a copy of upstream `qml/` and carries Ryoku integration patches.
- `ryoku/appearance/` contains Ryoku-only theme, font, and cursor selector extensions.

## Ryoku Patch Allowlist

Ryoku integration patches are allowed in:

- `ryoku/qml/Config.qml`
- `ryoku/qml/services/DaemonClient.qml`
- `ryoku/qml/wallpaper/WallpaperSelector.qml`
- `ryoku/RyokuWallpaperSelectorHost.qml`
- `ryoku/appearance/`

The `upstream/` tree should not be edited by Ryoku integration work.
```

- [ ] **Step 3: Add missing required package**

If `qt6-imageformats` is not present in `install/ryoku-base.packages`, add this line next to the other Qt 6 packages:

```text
qt6-imageformats
```

- [ ] **Step 4: Run vendor test**

Run:

```bash
tests/skwd-wall-vendor.sh
```

Expected: exit 1 with `FAIL: Ryoku SKWD host missing`.

- [ ] **Step 5: Commit**

Run:

```bash
git add config/quickshell/ryoku/vendor/skwd-wall install/ryoku-base.packages
git commit -m "feat: vendor skwd-wall visual source"
```

---

### Task 3: Add Ryoku Wallpaper Daemon Source, Wrappers, Service, And Migration

**Files:**
- Create: `src/ryoku-wallpaper-daemon/`
- Create: `src/ryoku-wallpaper-daemon/UPSTREAM.md`
- Create: `bin/ryoku-wallpaper-daemon`
- Create: `bin/ryoku-wallpaperctl`
- Create: `config/systemd/user/ryoku-wallpaper-daemon.service`
- Create: `migrations/1777644985.sh`

- [ ] **Step 1: Copy SKWD-daemon source**

Run:

```bash
mkdir -p src/ryoku-wallpaper-daemon
cp -a /tmp/skwd-daemon-upstream/Cargo.toml src/ryoku-wallpaper-daemon/
cp -a /tmp/skwd-daemon-upstream/Cargo.lock src/ryoku-wallpaper-daemon/
cp -a /tmp/skwd-daemon-upstream/LICENSE src/ryoku-wallpaper-daemon/
cp -a /tmp/skwd-daemon-upstream/clippy.toml src/ryoku-wallpaper-daemon/
cp -a /tmp/skwd-daemon-upstream/rustfmt.toml src/ryoku-wallpaper-daemon/
cp -a /tmp/skwd-daemon-upstream/rust-toolchain.toml src/ryoku-wallpaper-daemon/
cp -a /tmp/skwd-daemon-upstream/crates src/ryoku-wallpaper-daemon/
```

- [ ] **Step 2: Rename Rust workspace crates**

Edit `src/ryoku-wallpaper-daemon/Cargo.toml` so the workspace dependency is:

```toml
ryoku-wallpaper-proto = { path = "crates/proto" }
```

Edit `src/ryoku-wallpaper-daemon/crates/proto/Cargo.toml` so the package name is:

```toml
[package]
name = "ryoku-wallpaper-proto"
version.workspace = true
edition.workspace = true
```

Edit `src/ryoku-wallpaper-daemon/crates/daemon/Cargo.toml` so the package, binary, and dependency names are:

```toml
[package]
name = "ryoku-wallpaper-daemon"
version.workspace = true
edition.workspace = true

[[bin]]
name = "ryoku-wallpaper-daemon"
path = "src/main.rs"

[dependencies]
ryoku-wallpaper-proto = { workspace = true }
```

Keep the remaining upstream dependencies in `crates/daemon/Cargo.toml`.

Edit `src/ryoku-wallpaper-daemon/crates/cli/Cargo.toml` so the package, binary, and dependency names are:

```toml
[package]
name = "ryoku-wallpaperctl"
version.workspace = true
edition.workspace = true

[[bin]]
name = "ryoku-wallpaperctl"
path = "src/main.rs"

[dependencies]
ryoku-wallpaper-proto = { workspace = true }
tokio = { workspace = true }
serde_json = { workspace = true }
```

Replace Rust imports:

```bash
rg -l 'skwd_proto' src/ryoku-wallpaper-daemon/crates | xargs sed -i 's/skwd_proto/ryoku_wallpaper_proto/g'
rg -l 'skwd-proto' src/ryoku-wallpaper-daemon | xargs sed -i 's/skwd-proto/ryoku-wallpaper-proto/g'
```

- [ ] **Step 3: Add daemon upstream notes**

Create `src/ryoku-wallpaper-daemon/UPSTREAM.md`:

```markdown
# SKWD-daemon Ryoku Adaptation Notes

- Upstream: https://github.com/liixini/skwd-daemon
- Commit: 2d48800
- License: MIT
- Copyright: Copyright (c) 2026 liixini

## Ryoku Changes

- Public binaries and services use the `ryoku-` prefix.
- The socket path is `$XDG_RUNTIME_DIR/ryoku/wallpaper-daemon.sock`.
- Wallpaper apply delegates to `ryoku-wallpaper-apply`.
- Config, cache, database, and metadata paths use Ryoku environment variables.
- Protocol method and event names remain SKWD-compatible where that reduces QML drift.
```

- [ ] **Step 4: Add command wrappers**

Create `bin/ryoku-wallpaper-daemon`:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

manifest="$RYOKU_PATH/src/ryoku-wallpaper-daemon/Cargo.toml"
lockfile="$RYOKU_PATH/src/ryoku-wallpaper-daemon/Cargo.lock"
binary="$RYOKU_PATH/src/ryoku-wallpaper-daemon/target/release/ryoku-wallpaper-daemon"

if [[ ! -f $manifest ]]; then
  echo "ryoku-wallpaper-daemon: missing $manifest" >&2
  exit 1
fi

if [[ ! -x $binary || $manifest -nt $binary || $lockfile -nt $binary ]]; then
  cargo build --release --manifest-path "$manifest" --bin ryoku-wallpaper-daemon
fi

exec "$binary" "$@"
```

Create `bin/ryoku-wallpaperctl`:

```bash
#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

manifest="$RYOKU_PATH/src/ryoku-wallpaper-daemon/Cargo.toml"

exec cargo run --release --manifest-path "$manifest" --bin ryoku-wallpaperctl -- "$@"
```

Run:

```bash
chmod +x bin/ryoku-wallpaper-daemon bin/ryoku-wallpaperctl
```

- [ ] **Step 5: Add systemd user service**

Create `config/systemd/user/ryoku-wallpaper-daemon.service`:

```ini
[Unit]
Description=Ryoku wallpaper daemon
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/share/ryoku/bin/ryoku-wallpaper-daemon
Restart=on-failure
RestartSec=2
Environment=RUST_LOG=info

[Install]
WantedBy=default.target
```

- [ ] **Step 6: Add service migration**

Create `migrations/1777644985.sh` with no shebang:

```bash
echo "Install and start Ryoku wallpaper daemon user service"

if [[ -x $RYOKU_PATH/bin/ryoku-wallpaper-daemon && -f $RYOKU_PATH/config/systemd/user/ryoku-wallpaper-daemon.service ]]; then
  mkdir -p ~/.config/systemd/user
  cp "$RYOKU_PATH/config/systemd/user/ryoku-wallpaper-daemon.service" ~/.config/systemd/user/
  systemctl --user daemon-reload
  systemctl --user enable --now ryoku-wallpaper-daemon.service || true
fi
```

- [ ] **Step 7: Run daemon test**

Run:

```bash
tests/ryoku-wallpaper-daemon.sh
```

Expected: exit 1 with a socket, path, or apply-routing failure until Task 4 patches the daemon.

- [ ] **Step 8: Commit**

Run:

```bash
git add src/ryoku-wallpaper-daemon bin/ryoku-wallpaper-daemon bin/ryoku-wallpaperctl config/systemd/user/ryoku-wallpaper-daemon.service migrations/1777644985.sh
git commit -m "feat: add ryoku wallpaper daemon source"
```

---

### Task 4: Adapt Daemon Protocol, Paths, Apply, And Metadata Migration

**Files:**
- Modify: `src/ryoku-wallpaper-daemon/crates/proto/src/lib.rs`
- Modify: `src/ryoku-wallpaper-daemon/crates/cli/src/main.rs`
- Modify: `src/ryoku-wallpaper-daemon/crates/daemon/src/config.rs`
- Modify: `src/ryoku-wallpaper-daemon/crates/daemon/src/db.rs`
- Modify: `src/ryoku-wallpaper-daemon/crates/daemon/src/wall/apply.rs`
- Modify: `src/ryoku-wallpaper-daemon/crates/daemon/src/server.rs`
- Test: `tests/ryoku-wallpaper-daemon.sh`

- [ ] **Step 1: Patch socket path**

Change `socket_path()` in `crates/proto/src/lib.rs` to:

```rust
pub fn socket_path() -> PathBuf {
    let runtime_dir = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    PathBuf::from(runtime_dir).join("ryoku").join("wallpaper-daemon.sock")
}
```

Update `crates/cli/src/main.rs` usage text to use `ryoku-wallpaperctl` and `ryoku-wallpaper-daemon`, while leaving JSON-RPC methods such as `wall.apply` unchanged.

- [ ] **Step 2: Patch Ryoku config paths**

In `crates/daemon/src/config.rs`, add helpers:

```rust
fn env_path(name: &str) -> Option<PathBuf> {
    std::env::var(name).ok().filter(|v| !v.is_empty()).map(PathBuf::from)
}

fn ryoku_path() -> PathBuf {
    env_path("RYOKU_PATH").unwrap_or_else(|| home().join(".local/share/ryoku"))
}

fn ryoku_config_path() -> PathBuf {
    env_path("RYOKU_CONFIG_PATH").unwrap_or_else(|| home().join(".config/ryoku"))
}

fn ryoku_state_path() -> PathBuf {
    env_path("RYOKU_STATE_PATH").unwrap_or_else(|| home().join(".local/state/ryoku"))
}
```

Set defaults:

```rust
pub fn wallpaper_dir(&self) -> PathBuf {
    resolve_path(self.paths.wallpaper.as_deref())
        .or_else(|| env_path("RYOKU_WALLPAPER_DIR"))
        .unwrap_or_else(|| home().join("Pictures/Wallpapers"))
}

pub fn video_dir(&self) -> PathBuf {
    resolve_path(self.paths.video_wallpaper.as_deref()).unwrap_or_else(|| self.wallpaper_dir())
}

pub fn cache_dir(&self) -> PathBuf {
    resolve_path(self.paths.cache.as_deref()).unwrap_or_else(|| ryoku_state_path().join("wallpaper/skwd"))
}

pub fn template_dir(&self) -> PathBuf {
    resolve_path(self.paths.templates.as_deref())
        .unwrap_or_else(|| ryoku_path().join("config/quickshell/ryoku/vendor/skwd-wall/upstream/data/matugen/templates"))
}

pub fn scripts_dir(&self) -> PathBuf {
    resolve_path(self.paths.scripts.as_deref())
        .unwrap_or_else(|| ryoku_path().join("config/quickshell/ryoku/vendor/skwd-wall/upstream/data/scripts"))
}
```

Change `config_dir()` and `config_path()` to:

```rust
pub fn config_dir() -> PathBuf {
    ryoku_config_path().join("wallpaper")
}

pub fn config_path() -> PathBuf {
    config_dir().join("skwd-wall.json")
}
```

- [ ] **Step 3: Store SQLite under Ryoku state**

In `crates/daemon/src/db.rs`, replace `xdg_data_home()`/`db_path()` with:

```rust
fn ryoku_state_path() -> PathBuf {
    std::env::var("RYOKU_STATE_PATH")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
            PathBuf::from(home).join(".local/state/ryoku")
        })
}

pub fn db_path() -> PathBuf {
    ryoku_state_path().join("wallpaper/daemon.sqlite")
}
```

Add migration import helpers:

```rust
fn ryoku_legacy_meta_paths() -> Vec<PathBuf> {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    let ryoku_path = std::env::var("RYOKU_PATH").unwrap_or_else(|_| format!("{home}/.local/share/ryoku"));
    vec![
        PathBuf::from(format!("{home}/.config/quickshell/ryoku/vendor/brain-shell/src/user_data/wallpaper-meta.json")),
        PathBuf::from(ryoku_path).join("config/quickshell/ryoku/vendor/brain-shell/src/user_data/wallpaper-meta.json"),
    ]
}
```

In `open()`, after `migrate(&conn)?`, call:

```rust
import_ryoku_wallpaper_meta(&conn).ok();
```

Add `import_ryoku_wallpaper_meta(conn: &Connection) -> anyhow::Result<()>` that:

- checks `state` key `imported_from_ryoku_wallpaper_meta`;
- reads the first existing path from `ryoku_legacy_meta_paths()`;
- parses JSON object keys for tags and favourites;
- updates matching `meta.key` rows when cache entries already exist;
- writes `state` key `imported_from_ryoku_wallpaper_meta`.

- [ ] **Step 4: Delegate apply through Ryoku command**

In `crates/daemon/src/wall/apply.rs`, replace static/video rendering branches with a shared function:

```rust
async fn run_ryoku_wallpaper_apply(kind: &str, path: &str) -> anyhow::Result<()> {
    let ryoku_path = std::env::var("RYOKU_PATH").unwrap_or_else(|_| {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
        format!("{home}/.local/share/ryoku")
    });
    let cmd = Path::new(&ryoku_path).join("bin/ryoku-wallpaper-apply");
    let output = Command::new(cmd)
        .arg("--type")
        .arg(kind)
        .arg(path)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .await?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);
        anyhow::bail!("ryoku-wallpaper-apply failed: {stderr}{stdout}");
    }
    Ok(())
}
```

Use it from:

```rust
pub async fn apply_static(path: &str, _outputs: &[String], config: &Config) -> anyhow::Result<()> {
    run_ryoku_wallpaper_apply("image", path).await?;
    save_state(&config.cache_dir(), "static", path, "").await;
    Ok(())
}

pub async fn apply_video(path: &str, _outputs: &[String], config: &Config) -> anyhow::Result<()> {
    run_ryoku_wallpaper_apply("video", path).await?;
    save_state(&config.cache_dir(), "video", path, "").await;
    Ok(())
}
```

Leave Wallpaper Engine behind the existing feature check.

- [ ] **Step 5: Prevent SKWD daemon from launching separate SKWD shell apps**

In `crates/daemon/src/server.rs`, make `UiProcess::launch()` a no-op when the shell path points to SKWD-wall. For `wall.toggle`, `wall.show`, and `wall.hide`, only broadcast SKWD-compatible events:

```rust
let _ = broadcast_event(event_tx, "skwd.wall.show", serde_json::json!({}));
Response::ok(req.id, serde_json::json!({"ok": true}))
```

Ryoku opens/closes UI through Brain_Shell popup state, not through daemon-owned Quickshell processes.

- [ ] **Step 6: Run daemon tests**

Run:

```bash
tests/ryoku-wallpaper-daemon.sh
```

Expected: `OK: ryoku wallpaper daemon guardrails`.

Run:

```bash
cargo test --manifest-path src/ryoku-wallpaper-daemon/Cargo.toml --workspace
```

Expected: all Rust tests pass.

- [ ] **Step 7: Commit**

Run:

```bash
git add src/ryoku-wallpaper-daemon
git commit -m "feat: adapt skwd daemon to ryoku"
```

---

### Task 5: Patch SKWD QML For Ryoku Paths, Socket, And Popup State

**Files:**
- Modify: `config/quickshell/ryoku/vendor/skwd-wall/ryoku/qml/Config.qml`
- Modify: `config/quickshell/ryoku/vendor/skwd-wall/ryoku/qml/services/DaemonClient.qml`
- Modify: `config/quickshell/ryoku/vendor/skwd-wall/ryoku/qml/wallpaper/WallpaperSelector.qml`
- Create: `config/quickshell/ryoku/vendor/skwd-wall/ryoku/RyokuWallpaperSelectorHost.qml`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperPopup.qml`

- [ ] **Step 1: Patch DaemonClient socket**

In `ryoku/qml/services/DaemonClient.qml`, change the socket path to:

```qml
path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku/wallpaper-daemon.sock"
```

- [ ] **Step 2: Patch Config defaults**

In `ryoku/qml/Config.qml`, replace SKWD defaults with Ryoku environment paths:

```qml
readonly property string ryokuPath: Quickshell.env("RYOKU_PATH") || (homeDir + "/.local/share/ryoku")
readonly property string ryokuConfigPath: Quickshell.env("RYOKU_CONFIG_PATH") || (homeDir + "/.config/ryoku")
readonly property string ryokuStatePath: Quickshell.env("RYOKU_STATE_PATH") || (homeDir + "/.local/state/ryoku")
readonly property string wallpaperDir: Quickshell.env("RYOKU_WALLPAPER_DIR")
    || _resolve(_data.paths?.wallpaper)
    || (homeDir + "/Pictures/Wallpapers")
readonly property string videoDir: _resolve(_data.paths?.videoWallpaper) || wallpaperDir
readonly property string cacheDir: _resolve(_data.paths?.cache) || (ryokuStatePath + "/wallpaper/skwd")
readonly property string configDir: ryokuConfigPath + "/wallpaper"
readonly property string installDir: ryokuPath + "/config/quickshell/ryoku/vendor/skwd-wall/upstream"
readonly property string templateDir: _resolve(_data.paths?.templates) || (installDir + "/data/matugen/templates")
readonly property string scriptsDir: _resolve(_data.paths?.scripts) || (installDir + "/data/scripts")
```

Set feature defaults so unavailable services are honest:

```qml
readonly property bool matugenEnabled: _data.features?.matugen === true
readonly property bool ollamaEnabled: _data.features?.ollama === true
readonly property bool steamEnabled: _data.features?.steam === true
readonly property bool wallhavenEnabled: _data.features?.wallhaven !== false
```

- [ ] **Step 3: Patch layershell namespace**

In `ryoku/qml/wallpaper/WallpaperSelector.qml`, change:

```qml
WlrLayershell.namespace: "ryoku-wallpaper-selector"
```

Keep the upstream fullscreen centered selector geometry unless a screenshot review proves it conflicts with Ryoku shell surfaces.

- [ ] **Step 4: Add Ryoku SKWD host**

Create `config/quickshell/ryoku/vendor/skwd-wall/ryoku/RyokuWallpaperSelectorHost.qml`:

```qml
import QtQuick
import Quickshell
import "./qml/wallpaper" as SkwdWall
import "./appearance" as RyokuAppearance

Scope {
  id: root

  property bool open: false
  property string mode: "wallpaper"
  readonly property bool visibleState: open

  signal dismissed()

  SkwdWall.WallpaperSelector {
    id: wallpaperSelector
    showing: root.open && root.mode === "wallpaper"

    onShowingChanged: {
      if (!showing && root.open && root.mode === "wallpaper") {
        root.dismissed()
      }
    }
  }

  RyokuAppearance.AppearanceSelector {
    id: appearanceSelector
    showing: root.open && root.mode !== "wallpaper"
    mode: root.mode

    onDismissed: root.dismissed()
  }
}
```

- [ ] **Step 5: Replace Brain_Shell wallpaper popup with compatibility wrapper**

Replace `config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperPopup.qml` with:

```qml
import QtQuick
import Quickshell
import "../"
import "../../../skwd-wall/ryoku" as RyokuSkwd

Scope {
  id: root

  Binding {
    target: Popups
    property: "wallpaperVisible"
    value: host.visibleState
  }

  RyokuSkwd.RyokuWallpaperSelectorHost {
    id: host
    open: Popups.wallpaperOpen
    mode: Popups.wallpaperMode
    onDismissed: Popups.wallpaperOpen = false
  }
}
```

- [ ] **Step 6: Run QML/static tests**

Run:

```bash
tests/quickshell-wallpaper-switcher.sh
```

Expected: `tests/quickshell-wallpaper-switcher.sh` passes. `tests/quickshell-wallpaper-skwd.sh` becomes green after Task 6 adds the appearance selector files, and `tests/skwd-wall-vendor.sh` becomes green after Task 8 adds attribution.

- [ ] **Step 7: Commit**

Run after Task 6 passes the linked Quickshell tests:

```bash
git add config/quickshell/ryoku/vendor/skwd-wall/ryoku config/quickshell/ryoku/vendor/brain-shell/src/popups/WallpaperPopup.qml
git commit -m "feat: host skwd selector in ryoku shell"
```

---

### Task 6: Add SKWD-Styled Theme, Font, And Cursor Modes

**Files:**
- Create: `config/quickshell/ryoku/vendor/skwd-wall/ryoku/appearance/AppearanceSelector.qml`
- Create: `config/quickshell/ryoku/vendor/skwd-wall/ryoku/appearance/AppearanceSelectorService.qml`
- Create: `config/quickshell/ryoku/vendor/skwd-wall/ryoku/appearance/AppearanceChoiceCard.qml`
- Test: `tests/quickshell-wallpaper-skwd.sh`

- [ ] **Step 1: Add appearance service**

Create `AppearanceSelectorService.qml`:

```qml
import QtQuick
import "../../../brain-shell/src/services" as RyokuServices

QtObject {
  id: root

  property string mode: "theme"
  property var activeModel: mode === "font"
      ? RyokuServices.FontService.fontModel
      : (mode === "cursor" ? RyokuServices.CursorService.cursorModel : RyokuServices.ThemeService.themeModel)
  property string statusText: ""

  function refresh() {
    if (mode === "font") {
      RyokuServices.FontService.refresh()
    } else if (mode === "cursor") {
      RyokuServices.CursorService.refresh()
    } else {
      RyokuServices.ThemeService.refresh()
    }
  }

  function apply(item) {
    if (!item) return
    if (mode === "font") {
      RyokuServices.FontService.applyFont(item.family || item.name || "")
      statusText = "Applied font"
    } else if (mode === "cursor") {
      RyokuServices.CursorService.applyCursor(item.name || "", item.size || 24)
      statusText = "Applied cursor"
    } else {
      RyokuServices.ThemeService.applyTheme(item.name || "")
      statusText = "Applied theme"
    }
  }
}
```

- [ ] **Step 2: Add SKWD-style appearance card**

Create `AppearanceChoiceCard.qml`:

```qml
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../../../brain-shell/src" as Brain

Item {
  id: root

  required property var itemData
  property bool selected: false
  property bool hovered: false
  property int compactWidth: 92
  property int expandedWidth: 300
  property int skewOffset: 24
  signal activated(var itemData)

  width: root.selected || root.hovered ? root.expandedWidth : root.compactWidth
  height: 280

  Behavior on width {
    NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
  }

  Shape {
    id: maskShape
    anchors.fill: parent
    visible: false
    ShapePath {
      fillColor: "white"
      strokeWidth: 0
      startX: root.skewOffset
      startY: 0
      PathLine { x: root.width; y: 0 }
      PathLine { x: root.width - root.skewOffset; y: root.height }
      PathLine { x: 0; y: root.height }
      PathLine { x: root.skewOffset; y: 0 }
    }
  }

  Rectangle {
    id: cardFill
    anchors.fill: parent
    radius: 14
    color: Qt.rgba(Brain.Theme.surface.r, Brain.Theme.surface.g, Brain.Theme.surface.b, 0.94)
    border.color: root.selected ? Brain.Theme.accent : Qt.rgba(1, 1, 1, 0.16)
    border.width: root.selected ? 2 : 1

    Column {
      anchors.fill: parent
      anchors.margins: 18
      spacing: 10

      Text {
        text: root.itemData.name || root.itemData.family || ""
        color: Brain.Theme.foreground
        font.pixelSize: 18
        font.bold: true
        elide: Text.ElideRight
        width: parent.width
      }

      Text {
        text: root.itemData.description || root.itemData.path || ""
        color: Qt.rgba(Brain.Theme.foreground.r, Brain.Theme.foreground.g, Brain.Theme.foreground.b, 0.68)
        font.pixelSize: 12
        wrapMode: Text.Wrap
        width: parent.width
        maximumLineCount: 4
      }
    }
  }

  MultiEffect {
    anchors.fill: cardFill
    source: cardFill
    maskEnabled: true
    maskSource: maskShape
  }

  HoverHandler {
    onHoveredChanged: root.hovered = hovered
  }

  TapHandler {
    onTapped: root.activated(root.itemData)
  }
}
```

- [ ] **Step 3: Add appearance selector**

Create `AppearanceSelector.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../../brain-shell/src" as Brain

Scope {
  id: root

  property bool showing: false
  property string mode: "theme"
  signal dismissed()

  AppearanceSelectorService {
    id: service
    mode: root.mode
  }

  onShowingChanged: {
    if (showing) service.refresh()
  }

  PanelWindow {
    id: panel

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    visible: root.showing
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "ryoku-appearance-selector"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.5)
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismissed()
    }

    Item {
      id: cardContainer
      anchors.centerIn: parent
      width: Math.min(parent.width - 80, 1120)
      height: 360

      MouseArea {
        anchors.fill: parent
        onClicked: function(mouse) { mouse.accepted = true }
      }

      ListView {
        id: list
        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: -20
        clip: true
        model: service.activeModel
        currentIndex: 0
        cacheBuffer: 1000

        delegate: AppearanceChoiceCard {
          required property var modelData
          itemData: modelData
          selected: ListView.isCurrentItem
          onActivated: function(item) {
            list.currentIndex = index
            service.apply(item)
            root.dismissed()
          }
        }

        Keys.onEscapePressed: root.dismissed()
        Keys.onReturnPressed: {
          if (currentItem) currentItem.activated(currentItem.itemData)
        }
      }
    }
  }
}
```

- [ ] **Step 4: Run Quickshell selector tests**

Run:

```bash
tests/quickshell-wallpaper-skwd.sh
tests/quickshell-wallpaper-switcher.sh
```

Expected: both tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add config/quickshell/ryoku/vendor/skwd-wall/ryoku/appearance
git commit -m "feat: add skwd styled appearance modes"
```

---

### Task 7: Wire Service Startup Into Shell Open Flow

**Files:**
- Modify: `config/quickshell/ryoku/vendor/skwd-wall/ryoku/RyokuWallpaperSelectorHost.qml`
- Test: `tests/skwd-wall-vendor.sh`

- [ ] **Step 1: Add service start process**

In `RyokuWallpaperSelectorHost.qml`, add:

```qml
import Quickshell.Io
```

Inside `Scope`, add:

```qml
Process {
  id: daemonStarter
  command: ["systemctl", "--user", "start", "ryoku-wallpaper-daemon.service"]
}

onOpenChanged: {
  if (open) {
    daemonStarter.running = true
  }
}
```

- [ ] **Step 2: Add error state bridge**

In the host, add a property that can be displayed by selectors:

```qml
property string daemonStatusText: ""
```

Set it when `DaemonClient` reports disconnected after retry in `ryoku/qml/services/DaemonClient.qml`:

```qml
console.log("DaemonClient: disconnected")
client.ready = false
client._pending = {}
client._reconnectTimer.restart()
```

Keep upstream retry behavior and avoid closing `Popups.wallpaperOpen` from daemon disconnects.

- [ ] **Step 3: Run static tests**

Run:

```bash
tests/skwd-wall-vendor.sh
tests/quickshell-wallpaper-switcher.sh
```

Expected: both tests pass.

- [ ] **Step 4: Commit**

Run:

```bash
git add config/quickshell/ryoku/vendor/skwd-wall/ryoku
git commit -m "feat: start wallpaper daemon from skwd host"
```

---

### Task 8: Documentation, Credits, Notice, And Package Audit

**Files:**
- Modify: `README.md`
- Modify: `CREDITS.md`
- Modify: `NOTICE`
- Modify: `install/ryoku-base.packages`
- Modify: ISO package overlays under `iso/` only if they mirror base packages explicitly.
- Test: `tests/skwd-wall-vendor.sh`

- [ ] **Step 1: Update README Credits**

Add this bullet to the README Credits section:

```markdown
- [**SKWD-wall**](https://github.com/liixini/skwd-wall): wallpaper selector visuals and interaction model by **liixini**. MIT. Vendored under [`config/quickshell/ryoku/vendor/skwd-wall/`](config/quickshell/ryoku/vendor/skwd-wall/), with Ryoku-specific IPC and daemon integration.
```

- [ ] **Step 2: Update CREDITS.md**

Add:

```markdown
## SKWD-wall

- Upstream: https://github.com/liixini/skwd-wall
- Author: liixini
- License: MIT (see config/quickshell/ryoku/vendor/skwd-wall/LICENSE)
- Vendored under: config/quickshell/ryoku/vendor/skwd-wall/
- Upstream commit: f8e22a4
- Ryoku modifications recorded in config/quickshell/ryoku/vendor/skwd-wall/UPSTREAM.md

## SKWD-daemon

- Upstream: https://github.com/liixini/skwd-daemon
- Author: liixini
- License: MIT (see src/ryoku-wallpaper-daemon/LICENSE)
- Adapted under: src/ryoku-wallpaper-daemon/
- Upstream commit: 2d48800
- Public Ryoku commands: bin/ryoku-wallpaper-daemon, bin/ryoku-wallpaperctl
```

- [ ] **Step 3: Update NOTICE**

Add:

```text
SKWD-wall
  Source: https://github.com/liixini/skwd-wall
  License: MIT
  Copyright (c) 2026 liixini
  Used for wallpaper selector visuals and interaction model.

SKWD-daemon
  Source: https://github.com/liixini/skwd-daemon
  License: MIT
  Copyright (c) 2026 liixini
  Adapted as Ryoku's wallpaper daemon backend.
```

- [ ] **Step 4: Verify packages**

Run:

```bash
rg -n '^(quickshell|rust|swaybg|mpvpaper|ffmpegthumbnailer|qt6-declarative|qt6-multimedia|qt6-multimedia-ffmpeg|qt6-svg|qt6-imageformats)$' install/ryoku-base.packages install/ryoku-aur.packages
```

Expected: all required non-AUR packages are in `install/ryoku-base.packages`; `mpvpaper` remains in `install/ryoku-aur.packages`.

- [ ] **Step 5: Run attribution/package test**

Run:

```bash
tests/skwd-wall-vendor.sh
```

Expected: `OK: skwd-wall vendor guardrails`.

- [ ] **Step 6: Commit**

Run:

```bash
git add README.md CREDITS.md NOTICE install/ryoku-base.packages install/ryoku-aur.packages config/quickshell/ryoku/vendor/skwd-wall/UPSTREAM.md src/ryoku-wallpaper-daemon/UPSTREAM.md tests/skwd-wall-vendor.sh tests/ryoku-wallpaper-daemon.sh tests/quickshell-wallpaper-switcher.sh tests/quickshell-wallpaper-skwd.sh
git commit -m "docs: credit skwd wallpaper integration"
```

---

### Task 9: Full Static And Backend Verification

**Files:**
- No code changes unless a verification failure identifies a concrete defect.

- [ ] **Step 1: Run focused shell tests**

Run:

```bash
tests/skwd-wall-vendor.sh
tests/ryoku-wallpaper-daemon.sh
tests/quickshell-wallpaper-switcher.sh
tests/quickshell-wallpaper-skwd.sh
tests/ryoku-ipc.sh
tests/ryoku-wallpaper-cache.sh
tests/ryoku-wallpaper-apply.sh
tests/ryoku-wallhaven-search.sh
```

Expected: every command exits 0 and prints `OK:` lines.

- [ ] **Step 2: Run Rust verification**

Run:

```bash
cargo test --manifest-path src/ryoku-wallpaper-daemon/Cargo.toml --workspace
cargo build --release --manifest-path src/ryoku-wallpaper-daemon/Cargo.toml --bin ryoku-wallpaper-daemon
```

Expected: tests pass and release daemon binary builds.

- [ ] **Step 3: Run QML lint when available**

Run:

```bash
if command -v qmllint >/dev/null; then
  find config/quickshell/ryoku/vendor/skwd-wall/ryoku -name '*.qml' -print0 | xargs -0 qmllint
fi
```

Expected: no `qmllint` errors when `qmllint` is installed.

- [ ] **Step 4: Commit verification fixes**

If verification required code changes, commit them:

```bash
git add config src bin tests README.md CREDITS.md NOTICE install migrations
git commit -m "fix: stabilize skwd wallpaper integration"
```

Skip this commit when Step 1 through Step 3 pass without edits.

---

### Task 10: Live Ryoku Shell Verification

**Files:**
- No code changes unless live verification finds a concrete defect.

- [ ] **Step 1: Refresh Quickshell config**

Run:

```bash
env RYOKU_PATH=/home/omi/prowl/ryoku-arch bin/ryoku-refresh-quickshell
```

Expected: command exits 0.

- [ ] **Step 2: Start daemon service**

Run:

```bash
mkdir -p ~/.config/systemd/user
cp config/systemd/user/ryoku-wallpaper-daemon.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user restart ryoku-wallpaper-daemon.service
systemctl --user status ryoku-wallpaper-daemon.service --no-pager
```

Expected: service status contains `active (running)` or an active build/start sequence from the wrapper.

- [ ] **Step 3: Restart shell**

Run:

```bash
bin/ryoku-restart-shell
```

Expected: a new `quickshell -c ryoku` process starts.

- [ ] **Step 4: Open wallpaper selector through IPC**

Run:

```bash
ryoku-ipc shell toggle wallpaper
sleep 1
grim /tmp/ryoku-skwd-wallpaper-selector.png
```

Expected: screenshot shows the upstream SKWD rounded skew-card selector, not the old sharp partial Ryoku clone.

- [ ] **Step 5: Open appearance modes**

Run:

```bash
ryoku-ipc shell toggle themes
sleep 1
grim /tmp/ryoku-skwd-theme-selector.png
ryoku-ipc shell toggle fonts
sleep 1
grim /tmp/ryoku-skwd-font-selector.png
ryoku-ipc shell toggle cursors
sleep 1
grim /tmp/ryoku-skwd-cursor-selector.png
```

Expected: screenshots show SKWD-styled cards for themes, fonts, and cursors.

- [ ] **Step 6: Apply wallpapers and appearance choices**

Use keyboard or mouse in the selector:

- apply one static wallpaper;
- apply one video wallpaper when a video file is available;
- apply one theme;
- apply one font;
- apply one cursor.

Expected:

- static wallpaper routes through `ryoku-wallpaper-apply --type image`;
- video wallpaper routes through `ryoku-wallpaper-apply --type video`;
- theme/font/cursor modes route through existing Ryoku services;
- selector closes or remains open according to SKWD/Ryoku settings without leaving `Popups.wallpaperOpen` stuck true.

- [ ] **Step 7: Final status check**

Run:

```bash
git status --short
```

Expected: clean working tree, unless screenshots under `/tmp` were created outside git.
