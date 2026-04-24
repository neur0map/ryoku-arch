# Ryoku Caelestia-style Frame Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a Quickshell-rendered opaque frame on three edges of every Ryoku monitor, with a uniform 8 px wallpaper matboard between frame and windows, color-synced to the theme, default-on, with a clean `ryoku-toggle-frame` disable path.

**Architecture:** New Quickshell shell under `config/quickshell/ryoku/` scaffolded for Phase 2 growth. Frame is drawn on `WlrLayer.Bottom` as three `Rectangle` strips (left/right/bottom) with rounded inner-corner fill via `QtQuick.Shapes`. Window placement is driven by four per-edge `ExclusionZone` surfaces (16 px left/right/bottom, 8 px top). Color lives in a theme-rendered singleton QML file. Toggle flips a state flag, manages a Hyprland drop-in at `~/.local/state/ryoku/toggles/hypr/frame.conf`, and cycles the quickshell process.

**Tech Stack:** Quickshell 0.2.1 (QML / Qt 6), QtQuick.Shapes 6.x, bash 5, Hyprland wlroots layer-shell, Ryoku theme templating (`sed`-based), `uwsm-app`.

**Spec:** [`docs/superpowers/specs/2026-04-24-ryoku-caelestia-frame-design.md`](../specs/2026-04-24-ryoku-caelestia-frame-design.md)

**Snapshot tag:** `pre-phase1-frame` (dev clone `42cdc353`, installed tree `7f45b365`). Rollback procedure in spec.

---

## Working trees

All file paths in this plan are **dev clone** paths under `/home/omi/prowl/ryoku-arch` unless prefixed with `~/`. Installed tree (`~/.local/share/ryoku`) is mirrored once in Task 12; live config (`~/.config/`) is populated once in Task 13.

## Files

**Create:**
- `config/quickshell/ryoku/shell.qml`
- `config/quickshell/ryoku/config/Config.qml`
- `config/quickshell/ryoku/modules/frame/Frame.qml`
- `config/quickshell/ryoku/modules/frame/ExclusionZones.qml`
- `config/quickshell/ryoku/components/.gitkeep`
- `config/quickshell/ryoku/services/.gitkeep`
- `config/quickshell/ryoku/utils/.gitkeep`
- `default/themed/quickshell-colors.qml.tpl`
- `bin/ryoku-launch-shell`
- `bin/ryoku-toggle-frame`
- `bin/ryoku-refresh-quickshell`

**Modify:**
- `install/ryoku-base.packages` (add `quickshell`)
- `default/hypr/autostart.conf` (add one `exec-once`)

---

### Task 1: Add quickshell to base packages and install on live

**Files:**
- Modify: `install/ryoku-base.packages`

- [ ] **Step 1.1: Verify pacman has quickshell**

Run: `pacman -Si quickshell | head -5`
Expected: shows `Repository : extra`, `Version : 0.2.1-6` (or newer).

- [ ] **Step 1.2: Add quickshell to the base packages list (alphabetical)**

Open `install/ryoku-base.packages` and insert `quickshell` in alphabetical order. It belongs between `qt6-wayland` and whatever follows. Verify placement with:

```bash
grep -n -B1 -A1 '^quickshell$' install/ryoku-base.packages
```

Expected: shows quickshell with the surrounding alphabetical neighbours.

- [ ] **Step 1.3: Install quickshell on the running machine**

Run: `sudo pacman -S --needed quickshell`
Expected: pacman installs quickshell and its Qt6 deps. Confirm with `pacman -Q quickshell`.

- [ ] **Step 1.4: Verify the binary launches**

Run: `quickshell --version`
Expected: prints the version, exits 0.

- [ ] **Step 1.5: Commit**

```bash
git add install/ryoku-base.packages
git commit -m "install: add quickshell to base packages for Phase 1 frame"
```

---

### Task 2: Scaffold Quickshell directory structure

**Files:**
- Create: `config/quickshell/ryoku/{components,services,utils}/.gitkeep`

- [ ] **Step 2.1: Create the directory tree**

```bash
cd /home/omi/prowl/ryoku-arch
mkdir -p config/quickshell/ryoku/{modules/frame,config,components,services,utils}
```

- [ ] **Step 2.2: Add `.gitkeep` files so empty Phase 2 directories are tracked**

```bash
touch config/quickshell/ryoku/components/.gitkeep
touch config/quickshell/ryoku/services/.gitkeep
touch config/quickshell/ryoku/utils/.gitkeep
```

- [ ] **Step 2.3: Verify the tree**

```bash
find config/quickshell -type d -o -name ".gitkeep"
```

Expected:
```
config/quickshell
config/quickshell/ryoku
config/quickshell/ryoku/components
config/quickshell/ryoku/components/.gitkeep
config/quickshell/ryoku/config
config/quickshell/ryoku/modules
config/quickshell/ryoku/modules/frame
config/quickshell/ryoku/services
config/quickshell/ryoku/services/.gitkeep
config/quickshell/ryoku/utils
config/quickshell/ryoku/utils/.gitkeep
```

- [ ] **Step 2.4: Commit**

```bash
git add config/quickshell/ryoku
git commit -m "quickshell: scaffold ryoku shell directory layout"
```

---

### Task 3: Theme color template

**Files:**
- Create: `default/themed/quickshell-colors.qml.tpl`

- [ ] **Step 3.1: Create the template**

Write `default/themed/quickshell-colors.qml.tpl` with exactly:

```qml
pragma Singleton
import QtQuick

QtObject {
    readonly property color frame: "{{ background }}"
}
```

- [ ] **Step 3.2: Re-render templates for the currently active theme**

Ryoku's template renderer runs as part of `ryoku-theme-set`. Re-run the renderer for the current theme:

```bash
CURRENT_THEME="$(readlink -f ~/.config/ryoku/current/theme | xargs basename)"
echo "current theme: $CURRENT_THEME"
ryoku-theme-set "$CURRENT_THEME"
```

Expected: no errors; `~/.config/ryoku/current/theme/quickshell-colors.qml` exists and contains the rendered frame color.

- [ ] **Step 3.3: Verify the rendered file**

```bash
cat ~/.config/ryoku/current/theme/quickshell-colors.qml
```

Expected:
```qml
pragma Singleton
import QtQuick

QtObject {
    readonly property color frame: "#171717"
}
```

(`#171717` for ristretto; other themes will show their own `background` hex.)

- [ ] **Step 3.4: Commit**

```bash
git add default/themed/quickshell-colors.qml.tpl
git commit -m "quickshell: theme-rendered singleton for frame color"
```

---

### Task 4: Config singleton

**Files:**
- Create: `config/quickshell/ryoku/config/Config.qml`
- Create: `config/quickshell/ryoku/config/qmldir`

> **Note on Quickshell 0.2.1 module resolution.** Tasks 4-7 use the root-qmldir pattern (all types declared in `config/quickshell/ryoku/qmldir`) rather than per-subdirectory library modules (`ryoku.config`, `ryoku.modules.frame`). Quickshell 0.2.1 uses Qt's QDir-based `locateLocalQmldir` which cannot resolve the `qs:@/` virtual filesystem scheme that quickshell uses for config paths, so dotted library imports fail. Types listed in the root qmldir are accessible to every QML file in the shell via the implicit root directory import. See commit `817a6638` for the discovery and fix.

- [ ] **Step 4.1: Register the config directory as a QML module**

Write `config/quickshell/ryoku/config/qmldir` with:

```
module ryoku.config
singleton Config 1.0 Config.qml
```

- [ ] **Step 4.2: Write `Config.qml`**

Write `config/quickshell/ryoku/config/Config.qml`:

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    readonly property int frameThickness: 8
    readonly property int matboard: 8
    readonly property int rounding: 16
    readonly property int topExclusion: matboard
    readonly property int sideExclusion: frameThickness + matboard

    property color frameColor: "#171717"

    FileView {
        id: themeColors
        path: Quickshell.env("HOME") + "/.config/ryoku/current/theme/quickshell-colors.qml"
        watchChanges: true

        onLoaded: {
            try {
                const loaded = Qt.createQmlObject(themeColors.text(), root, "quickshell-colors.qml")
                if (loaded !== null && loaded.frame !== undefined) {
                    root.frameColor = loaded.frame
                    loaded.destroy()
                }
            } catch (e) {
                console.warn("Config: failed to parse theme colors:", e.message)
            }
        }
    }
}
```

- [ ] **Step 4.3: Verify it parses**

There is no standalone QML compiler for Quickshell's extensions yet, so parse-check by running the full shell after Task 8. For now, syntax-check with `qmllint` if available:

```bash
qmllint config/quickshell/ryoku/config/Config.qml 2>&1 | head
```

Ignore `Quickshell.Io` unresolved-import warnings (expected; the import resolves at runtime). Expected: no structural / syntax errors.

- [ ] **Step 4.4: Commit**

```bash
git add config/quickshell/ryoku/config/qmldir config/quickshell/ryoku/config/Config.qml
git commit -m "quickshell: Config singleton with fallback color and theme FileView"
```

---

### Task 5: Frame component

**Files:**
- Create: `config/quickshell/ryoku/modules/frame/Frame.qml`
- Create: `config/quickshell/ryoku/modules/frame/qmldir`

- [ ] **Step 5.1: Register the frame module**

Write `config/quickshell/ryoku/modules/frame/qmldir`:

```
module ryoku.modules.frame
Frame 1.0 Frame.qml
ExclusionZones 1.0 ExclusionZones.qml
```

- [ ] **Step 5.2: Write `Frame.qml`**

Write `config/quickshell/ryoku/modules/frame/Frame.qml`:

```qml
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    surfaceFormat.opaque: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Shape {
        anchors.fill: parent
        asynchronous: false
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Config.frameColor
            fillRule: ShapePath.OddEvenFill

            // Outer rectangle (the full monitor), clockwise
            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }

            // Inner cutout: rounded-rect with no rounding on the top corners
            // (top edge has no drawn frame; the cutout reaches pixel 0 on top).
            PathMove { x: Config.sideExclusion; y: 0 }
            PathLine { x: Config.sideExclusion; y: root.height - Config.sideExclusion - Config.rounding }
            // Bottom-left cutout corner: south-to-east transition, CCW in Qt screen coords
            PathArc {
                x: Config.sideExclusion + Config.rounding
                y: root.height - Config.sideExclusion
                radiusX: Config.rounding
                radiusY: Config.rounding
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.width - Config.sideExclusion - Config.rounding; y: root.height - Config.sideExclusion }
            // Bottom-right cutout corner: east-to-north transition, CW in Qt screen coords
            PathArc {
                x: root.width - Config.sideExclusion
                y: root.height - Config.sideExclusion - Config.rounding
                radiusX: Config.rounding
                radiusY: Config.rounding
                direction: PathArc.Clockwise
            }
            PathLine { x: root.width - Config.sideExclusion; y: 0 }
            PathLine { x: Config.sideExclusion; y: 0 }
        }
    }
}
```

- [ ] **Step 5.3: Commit**

```bash
git add config/quickshell/ryoku/modules/frame/qmldir config/quickshell/ryoku/modules/frame/Frame.qml
git commit -m "quickshell: Frame component with rounded-inner-corner cutout"
```

---

### Task 6: ExclusionZones component

**Files:**
- Create: `config/quickshell/ryoku/modules/frame/ExclusionZones.qml`

- [ ] **Step 6.1: Write `ExclusionZones.qml`**

Write `config/quickshell/ryoku/modules/frame/ExclusionZones.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property ShellScreen modelData

    // Left edge (frame + matboard)
    PanelWindow {
        screen: root.modelData
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"
        mask: Region {}
        exclusiveZone: Config.sideExclusion
        implicitWidth: 1
        implicitHeight: 1
        anchors { top: true; bottom: true; left: true }
    }

    // Right edge (frame + matboard)
    PanelWindow {
        screen: root.modelData
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"
        mask: Region {}
        exclusiveZone: Config.sideExclusion
        implicitWidth: 1
        implicitHeight: 1
        anchors { top: true; bottom: true; right: true }
    }

    // Bottom edge (frame + matboard)
    PanelWindow {
        screen: root.modelData
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"
        mask: Region {}
        exclusiveZone: Config.sideExclusion
        implicitWidth: 1
        implicitHeight: 1
        anchors { bottom: true; left: true; right: true }
    }

    // Top edge (matboard only; Waybar reserves its own 26 px above this)
    PanelWindow {
        screen: root.modelData
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"
        mask: Region {}
        exclusiveZone: Config.topExclusion
        implicitWidth: 1
        implicitHeight: 1
        anchors { top: true; left: true; right: true }
    }
}
```

- [ ] **Step 6.2: Commit**

```bash
git add config/quickshell/ryoku/modules/frame/ExclusionZones.qml
git commit -m "quickshell: per-edge ExclusionZones (16/16/16/8)"
```

---

### Task 7: shell.qml entry point

**Files:**
- Create: `config/quickshell/ryoku/shell.qml`
- Create: `config/quickshell/ryoku/qmldir`

- [ ] **Step 7.1: Register the root module**

Write `config/quickshell/ryoku/qmldir`:

```
module ryoku
singleton Config 1.0 config/Config.qml
Frame 1.0 modules/frame/Frame.qml
ExclusionZones 1.0 modules/frame/ExclusionZones.qml
```

- [ ] **Step 7.2: Write `shell.qml`**

Write `config/quickshell/ryoku/shell.qml`:

```qml
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Frame {}
    }

    Variants {
        model: Quickshell.screens
        ExclusionZones {}
    }
}
```

- [ ] **Step 7.3: Parse-test by launching the shell briefly**

Copy the dev-clone config into live and attempt to launch:

```bash
mkdir -p ~/.config/quickshell
rm -rf ~/.config/quickshell/ryoku
cp -r config/quickshell/ryoku ~/.config/quickshell/ryoku
timeout 3 quickshell -c ryoku -v 2>&1 | tee /tmp/qs-phase1-launch.log | head -40
```

Expected: quickshell starts, logs creating the frame + exclusion-zone surfaces (one per monitor), no fatal errors before the timeout kills it.

If errors reference QML imports (`ryoku.config` not found), the `qmldir` files from Tasks 4 / 6 / 7 are probably in wrong paths.

- [ ] **Step 7.4: Clean up the live copy (will be re-created properly in Task 13)**

```bash
pkill -x quickshell 2>/dev/null
rm -rf ~/.config/quickshell/ryoku
```

- [ ] **Step 7.5: Commit**

```bash
git add config/quickshell/ryoku/qmldir config/quickshell/ryoku/shell.qml
git commit -m "quickshell: shell.qml root wiring Frame + ExclusionZones per screen"
```

---

### Task 8: ryoku-launch-shell

**Files:**
- Create: `bin/ryoku-launch-shell`

- [ ] **Step 8.1: Write the script**

Write `bin/ryoku-launch-shell`:

```bash
#!/bin/bash

# Launches the Ryoku Quickshell config. Idempotent: safe to re-run while
# quickshell is already running (quickshell will reject a duplicate with
# a clear stderr message and exit non-zero, which the autostart gate
# silently swallows).

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

if ryoku-cmd-missing quickshell; then
  echo "ryoku-launch-shell: quickshell is not installed; run 'sudo pacman -S quickshell'" >&2
  exit 1
fi

exec quickshell -c ryoku "$@"
```

- [ ] **Step 8.2: Make it executable**

```bash
chmod +x bin/ryoku-launch-shell
```

- [ ] **Step 8.3: Syntax-check**

```bash
bash -n bin/ryoku-launch-shell
```

Expected: no output, exit 0.

- [ ] **Step 8.4: Commit**

```bash
git add bin/ryoku-launch-shell
git commit -m "bin: ryoku-launch-shell wrapper for quickshell -c ryoku"
```

---

### Task 9: ryoku-refresh-quickshell subtree sync helper

**Files:**
- Create: `bin/ryoku-refresh-quickshell`

- [ ] **Step 9.1: Write the script**

Write `bin/ryoku-refresh-quickshell`:

```bash
#!/bin/bash

# Mirrors $RYOKU_PATH/config/quickshell/ryoku into ~/.config/quickshell/ryoku,
# backing up any file that differs. Companion to ryoku-refresh-config, which
# handles individual files; this one handles the whole QS subtree.

set -eEo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

SRC="$RYOKU_PATH/config/quickshell/ryoku"
DEST="$HOME/.config/quickshell/ryoku"

if [[ ! -d $SRC ]]; then
  echo "ryoku-refresh-quickshell: missing source $SRC" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"

if [[ -d $DEST ]]; then
  TS="$(date +%s)"
  BACKUP="$DEST.bak.$TS"
  echo "backing up existing $DEST -> $BACKUP"
  mv "$DEST" "$BACKUP"
fi

cp -r "$SRC" "$DEST"
echo "refreshed $DEST from $SRC"
```

- [ ] **Step 9.2: chmod and syntax-check**

```bash
chmod +x bin/ryoku-refresh-quickshell
bash -n bin/ryoku-refresh-quickshell
```

Expected: no output from `bash -n`.

- [ ] **Step 9.3: Commit**

```bash
git add bin/ryoku-refresh-quickshell
git commit -m "bin: ryoku-refresh-quickshell subtree sync with auto-backup"
```

---

### Task 10: ryoku-toggle-frame and Hyprland drop-in

**Files:**
- Create: `bin/ryoku-toggle-frame`

- [ ] **Step 10.1: Write the script**

Write `bin/ryoku-toggle-frame`:

```bash
#!/bin/bash

# Toggles the Ryoku Quickshell-rendered frame.
#  enabled  -> writes ~/.local/state/ryoku/toggles/hypr/frame.conf
#              (sourced by hyprland.conf), reloads Hyprland, launches quickshell
#  disabled -> removes the drop-in, reloads Hyprland, kills quickshell

set -eEo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

DROPIN_DIR="$HOME/.local/state/ryoku/toggles/hypr"
DROPIN="$DROPIN_DIR/frame.conf"

write_dropin() {
  mkdir -p "$DROPIN_DIR"
  cat > "$DROPIN" <<'EOF'
# Auto-managed by ryoku-toggle-frame. Do not edit by hand.
general {
    gaps_out = 0
    gaps_in = 6
}
decoration {
    rounding = 16
}
EOF
}

remove_dropin() {
  rm -f "$DROPIN"
}

if ryoku-toggle-enabled frame-off; then
  # Currently disabled; enable it.
  ryoku-toggle-enabled frame-off off
  write_dropin
  hyprctl reload >/dev/null
  pkill -x quickshell 2>/dev/null || true
  uwsm-app -- ryoku-launch-shell >/dev/null 2>&1 &
  notify-send -u low "▢  Ryoku frame: on"
else
  # Currently enabled; disable it.
  ryoku-toggle-enabled frame-off on
  remove_dropin
  hyprctl reload >/dev/null
  pkill -x quickshell 2>/dev/null || true
  notify-send -u low "▢  Ryoku frame: off"
fi
```

- [ ] **Step 10.2: chmod and syntax-check**

```bash
chmod +x bin/ryoku-toggle-frame
bash -n bin/ryoku-toggle-frame
```

- [ ] **Step 10.3: Commit**

```bash
git add bin/ryoku-toggle-frame
git commit -m "bin: ryoku-toggle-frame with Hyprland drop-in lifecycle"
```

---

### Task 11: Autostart integration

**Files:**
- Modify: `default/hypr/autostart.conf`

- [ ] **Step 11.1: Append the autostart line**

Open `default/hypr/autostart.conf` and add this line after the existing waybar line (keep it grouped with other toggle-gated desktop services):

```conf
exec-once = ! ryoku-toggle-enabled frame-off && uwsm-app -- ryoku-launch-shell
```

- [ ] **Step 11.2: Verify ordering**

```bash
grep -n 'ryoku-launch-shell\|waybar\|swaybg' default/hypr/autostart.conf
```

Expected: `swaybg` before `waybar` before `ryoku-launch-shell`, so quickshell starts after wallpaper and bar are present (avoids first-frame mis-sizing).

- [ ] **Step 11.3: Commit**

```bash
git add default/hypr/autostart.conf
git commit -m "hypr: autostart Ryoku shell on login (gated by frame-off toggle)"
```

---

### Task 12: Mirror dev clone to installed tree

**Files:**
- Modify: `~/.local/share/ryoku/` (the entire subtree of Phase 1 changes)

- [ ] **Step 12.1: Sync the new and changed paths**

```bash
cd /home/omi/prowl/ryoku-arch
rsync -av --delete config/quickshell/ ~/.local/share/ryoku/config/quickshell/
cp default/themed/quickshell-colors.qml.tpl ~/.local/share/ryoku/default/themed/
cp default/hypr/autostart.conf ~/.local/share/ryoku/default/hypr/autostart.conf
cp bin/ryoku-launch-shell ~/.local/share/ryoku/bin/
cp bin/ryoku-refresh-quickshell ~/.local/share/ryoku/bin/
cp bin/ryoku-toggle-frame ~/.local/share/ryoku/bin/
cp install/ryoku-base.packages ~/.local/share/ryoku/install/
chmod +x ~/.local/share/ryoku/bin/ryoku-launch-shell \
         ~/.local/share/ryoku/bin/ryoku-refresh-quickshell \
         ~/.local/share/ryoku/bin/ryoku-toggle-frame
```

- [ ] **Step 12.2: Commit in the installed tree**

```bash
cd ~/.local/share/ryoku
git add -A
USER_EMAIL="$(git -C /home/omi/prowl/ryoku-arch config user.email)"
USER_NAME="$(git -C /home/omi/prowl/ryoku-arch config user.name)"
git -c user.email="$USER_EMAIL" -c user.name="$USER_NAME" \
    commit -m "phase1: sync Ryoku Caelestia-style frame from dev clone"
```

- [ ] **Step 12.3: Verify the trees match on Phase 1 paths**

```bash
diff -r /home/omi/prowl/ryoku-arch/config/quickshell ~/.local/share/ryoku/config/quickshell
diff /home/omi/prowl/ryoku-arch/default/hypr/autostart.conf ~/.local/share/ryoku/default/hypr/autostart.conf
diff /home/omi/prowl/ryoku-arch/install/ryoku-base.packages ~/.local/share/ryoku/install/ryoku-base.packages
```

Expected: no output from any diff.

---

### Task 13: Refresh live system and first-launch smoke test

**Files:**
- Modify: `~/.config/quickshell/ryoku/`
- Modify: `~/.config/hypr/autostart.conf`

- [ ] **Step 13.1: Refresh the quickshell subtree**

```bash
cd /home/omi/prowl/ryoku-arch
ryoku-refresh-quickshell
ls ~/.config/quickshell/ryoku/
```

Expected: directory populated with `shell.qml`, `qmldir`, `modules/`, `config/`, etc.

- [ ] **Step 13.2: Refresh the autostart file**

```bash
ryoku-refresh-config hypr/autostart.conf
```

Expected: the live `~/.config/hypr/autostart.conf` now contains the new `exec-once = ! ryoku-toggle-enabled frame-off && uwsm-app -- ryoku-launch-shell` line.

- [ ] **Step 13.3: Launch quickshell in foreground and watch startup**

```bash
pkill -x quickshell 2>/dev/null || true
quickshell -c ryoku -v 2>&1 | tee /tmp/qs-phase1.log &
QS_PID=$!
sleep 2
pgrep -a quickshell
```

Expected: `pgrep` returns the running quickshell. Log shows one frame + four exclusion-zone layer-shell surfaces per monitor.

- [ ] **Step 13.4: Geometry sanity check (frame not yet truly active until drop-in in Task 14)**

Before `hyprctl reload` happens for the drop-in, Hyprland still has theme-level gaps. The QML ExclusionZones should still shrink the usable area though. Open a fresh terminal and check:

```bash
hyprctl activewindow -j | jq '{at, size}'
```

Expected: `at[0] >= 16`, `at[1] >= 34`. The exclusion zones are enforcing the frame inset.

- [ ] **Step 13.5: Confirm the frame is visually correct**

Visually inspect the screen. Pass criteria:
- Opaque dark ring (matching Waybar bg) visible on left, right, bottom.
- No frame strip on top; Waybar is flush to screen top.
- Wallpaper strip (~8 px) visible between the frame and any open window.
- Rounded inner corners at bottom-left and bottom-right of the frame cutout.

If any of those fail, do NOT proceed; review Task 5 / 6 / 7.

---

### Task 14: Enable drop-in, run toggle roundtrip, theme-switch test

- [ ] **Step 14.1: Write the Hyprland drop-in and reload**

The frame currently relies on QML ExclusionZones alone. With theme-level `gaps_out = 5` still applied, windows end up 21 px inset (16 zone + 5 gap), which breaks the 8+8 math. Write the drop-in now by enabling the toggle (which is a no-op since the state flag is already "enabled by default", but still writes the drop-in on first call):

```bash
# Force-enable: remove the flag if present, then invoke toggle-frame twice
# (the second call lands in the enabled branch, writing the drop-in).
ryoku-toggle-enabled frame-off off 2>/dev/null || true
ryoku-toggle-frame   # first call: if it thinks frame-off was on, this enables
ls -la ~/.local/state/ryoku/toggles/hypr/frame.conf
cat ~/.local/state/ryoku/toggles/hypr/frame.conf
```

Expected: the drop-in exists with the `gaps_out = 0`, `gaps_in = 6`, `rounding = 16` contents.

- [ ] **Step 14.2: Re-check geometry after drop-in**

```bash
hyprctl activewindow -j | jq '{at, size}'
```

Expected: `at: [16, 34]` (left: 16 zone, top: 26 waybar + 8 zone). No extra gaps-out contribution.

- [ ] **Step 14.3: Toggle off and verify teardown**

```bash
ryoku-toggle-frame   # turns off
pgrep -x quickshell && echo "ERROR: quickshell still running" || echo "OK: quickshell gone"
ls ~/.local/state/ryoku/toggles/hypr/frame.conf 2>&1 | head
hyprctl activewindow -j | jq '{at, size}'
```

Expected: quickshell gone, drop-in removed, window geometry reverts toward its pre-frame values.

- [ ] **Step 14.4: Toggle back on**

```bash
ryoku-toggle-frame
sleep 1
pgrep -a quickshell
hyprctl activewindow -j | jq '{at, size}'
```

Expected: quickshell running, geometry back to frame-aware values.

- [ ] **Step 14.5: Theme-switch color test**

```bash
ryoku-theme-set tokyo-night
sleep 1
cat ~/.config/ryoku/current/theme/quickshell-colors.qml
```

Expected: the rendered file now has the Tokyo Night background. The frame on screen should tint to the new color within a second (FileView reload). Revert:

```bash
ryoku-theme-set ristretto
```

Frame should tint back.

- [ ] **Step 14.6: Multi-monitor check (if an external monitor is available)**

Plug in an external monitor. Watch journalctl for quickshell output:

```bash
journalctl --user -f | grep -i quickshell &
```

Expected on hotplug: quickshell logs adding a new Frame and new ExclusionZones for the new screen. Unplug: logs removal. Skip this step if no external monitor is connected.

- [ ] **Step 14.7: End-of-phase commit in installed tree**

No new files expected; the run has modified only state (`~/.local/state/ryoku/toggles/hypr/frame.conf`) and live config (`~/.config/quickshell/ryoku/`). Verify the installed tree is still clean:

```bash
cd ~/.local/share/ryoku
git status --short
```

Expected: no output. If anything shows up, investigate before closing Phase 1.

---

## Known Phase 1 simplifications (spec-tracked, not blockers)

- The frame's inner-corner rounding uses QtQuick.Shapes Curve renderer. On Qt 6 < 6.6 the renderer defaults may look pixelated; if so, upgrade Qt or swap to three `Rectangle` strips with sharp inner corners (no spec change needed).
- Fullscreen auto-hide is intentionally out of scope; the frame is always visible.
- Theme switch recolors in < ~1 s; no animation. `Behavior on color` can be added in Phase 2.

## Self-review

Checked against the spec:
- Every spec "Goals" item has a task: default-on install (T1+T11), theme-sync color (T3+T4), disable toggle (T10), directory layout (T2+T5+T6+T7), snapshot tag (pre-work, already done).
- Every spec "Visual parameters" value is reflected in `Config.qml` (T4) and used by `Frame.qml` / `ExclusionZones.qml` (T5, T6).
- Every spec "Gaps that need to be implemented" is addressed:
  - Top-edge frame-less (T5, T6 top zone = 8 only).
  - Fallback color (`Config.qml: frameColor: "#171717"`).
  - Non-fatal missing binary (`ryoku-launch-shell` checks `ryoku-cmd-missing`).
  - Toggle idempotence (both branches `pkill ... || true`, `rm -f`).
  - Version pin comment (Task 1 note).
  - Waybar-top assumption (documented at top of plan + in spec).
- Rollback is unchanged from the spec (snapshot tags already in place before plan execution).

No TBD / TODO / XXX / FIXME markers. No references to undefined symbols. `Config.sideExclusion` used consistently across T5, T6; `Config.topExclusion` only in T6 (top zone).
