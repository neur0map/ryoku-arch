# Ryoku Caelestia-style Frame (Phase 1)

## Context

Ryoku currently ships with Waybar on top and swaybg for the wallpaper. There is no persistent screen-edge decoration: windows fill the screen minus theme-level Hyprland gaps. This makes the Ryoku desktop visually indistinguishable from a plain Omarchy install.

Phase 1 introduces Quickshell into the Ryoku stack as the rendering runtime for a small decorative shell surface: an opaque frame around three edges of every monitor, with a uniform wallpaper strip (matboard) between the frame and every window. Visually, it reads as Caelestia-style perimeter framing tied to the bar; architecturally, it is a deliberate minimum-viable entry point for a broader Quickshell-based Ryoku shell in Phase 2 (bar, launcher, OSD, lockscreen).

Reference: `caelestia-dots/shell` (MIT). We studied their `modules/drawers/ContentWindow.qml`, `Exclusions.qml`, `Background.qml`, and `plugin/src/Caelestia/Config/borderconfig.hpp` to derive the architecture, then stripped out everything not needed for a pure frame (no click mask, no bar, no Blobs renderer, no Material3 palette pipeline).

## Goals

1. Every new Ryoku install boots into the framed look with no extra user action.
2. The frame color stays in lock-step with the Ryoku theme and changes atomically on `ryoku-theme-set`.
3. The frame can be disabled with one command (`ryoku-toggle-frame`) and leaves the system in a clean, unframed state.
4. The QML layout is organized for Phase 2 modules (bar, launcher, dashboard) to slot in without restructuring.
5. Snapshot/rollback is a single git tag at `pre-phase1-frame` in both the dev clone and the installed tree.

## Non-goals (explicitly out of scope)

- Quickshell-native bar, launcher, dashboard, OSD, lockscreen, notifications (Phase 2+).
- Animated frame transitions (thickness morph, fade on fullscreen).
- Per-monitor frame overrides.
- Fullscreen auto-hide. The frame stays visible; this will become a toggle in a later phase.
- Replacing Waybar. Waybar continues to own the top bar in Phase 1.

## Visual parameters (locked)

| Parameter             | Value  | Source                                                |
|-----------------------|--------|-------------------------------------------------------|
| Frame thickness       | 8 px   | Opaque ring on left/right/bottom edges                |
| Matboard (wallpaper)  | 8 px   | Transparent strip between frame and window, all 4 sides |
| Inner corner rounding | 16 px  | Rounded inner corners of the frame cutout             |
| Frame color           | `$background` | Theme token; today `#171717` (same as Waybar bg) |
| Window corner rounding| 16 px  | Hyprland `decoration:rounding`, echoes frame curve    |
| Window inner gaps     | 6 px   | Hyprland `gaps_in` between tiled windows              |

Total window inset from screen edge: 16 px left/right/bottom (8 frame + 8 matboard); 34 px top (26 Waybar + 8 matboard). The top does not get a separate frame strip because Waybar already functions as the top of the frame visually. This matches the design intent "the frame looks like an extension of the bar".

## Architecture

### Layering

Ryoku's Wayland layer stack after Phase 1 lands:

```
Layer        Surface                         Purpose
-----        -------                         -------
Background   swaybg                          wallpaper
Bottom       Quickshell (ryoku)              frame (decorative, non-interactive)
(Tile/Float) Hyprland windows                app content
Top          Waybar                          bar; reserves 26 px top exclusive zone
Overlay      mako, tooltips, etc.            transient
```

The frame runs on `WlrLayer.Bottom`, under windows. Clicks pass naturally to windows above; no click-through mask is required. Caelestia uses `WlrLayer.Overlay` only because their frame hosts interactive bar popouts. Ours does not.

### Exclusion zones

Four per-monitor 1x1 `StyledWindow` surfaces at layer Bottom, each with an empty `Region` mask and a single-edge anchor. They reserve compositor space compositor-side (Wayland layer-shell protocol), so windows cannot overlap the frame/matboard regardless of Hyprland gap settings.

| Edge    | exclusiveZone | Notes                                               |
|---------|---------------|-----------------------------------------------------|
| Left    | 16            | frame 8 + matboard 8                                |
| Right   | 16            | frame 8 + matboard 8                                |
| Bottom  | 16            | frame 8 + matboard 8                                |
| Top     | 8             | matboard only; Waybar already reserves its own 26   |

Hyprland `gaps_out` is forced to `0` by the drop-in below so the exclusion zones alone determine window placement. Otherwise Hyprland would stack its own gaps on top of our zones and break the 8+8 math.

### Frame drawing

One `Frame.qml` surface per monitor, anchored to all four edges. It draws:

- Opaque rectangles on left, right, bottom edges at `Config.frame.thickness` (8 px).
- Nothing on the top edge; Waybar handles it.
- The opaque strips end in a rounded inner corner at the bottom-left and bottom-right with radius `Config.frame.rounding` (16 px). Top-left and top-right are sharp where the left/right strips meet Waybar.

Implementation options discussed:
- **Rect-based**: three `Rectangle` items (left, right, bottom) with rounded corners where they join. Simplest; rounded join handled by rectangle rounding plus a small rounded joiner.
- **Inverted-rect-based** (Caelestia's approach): one filled rect with a rounded-rect cutout subtracted via `MultiEffect` mask. Cleaner math; slightly heavier render.

Implementation plan will pick one; current lean is inverted-rect for exact geometry, with the top slice of the cutout set equal to the surface top so nothing draws above Waybar.

## File layout

Scaffolded for Phase 2 expansion; only `modules/frame/` populated in Phase 1.

```
<repo>/config/quickshell/ryoku/                -> ~/.config/quickshell/ryoku/
|-- shell.qml                                  # entry point: Variants over screens
|-- modules/
|   `-- frame/
|       |-- Frame.qml                          # per-monitor decorative surface
|       `-- ExclusionZones.qml                 # four per-edge reservations
|-- components/                                # (empty, Phase 2 reusables)
|-- services/                                  # (empty, Phase 2 IPC/state)
|-- config/
|   `-- Config.qml                             # singleton: thickness, gap, rounding, color
`-- utils/                                     # (empty, Phase 2 helpers)

<repo>/default/themed/quickshell-colors.qml.tpl   # theme-rendered color source
<repo>/default/hypr/autostart.conf                # add one exec-once line
<repo>/install/packaging/base.sh                  # quickshell added to pacman -S
<repo>/bin/
|-- ryoku-launch-shell                            # exec quickshell -c ryoku
|-- ryoku-toggle-frame                            # flip enabled/disabled, manage drop-in
`-- ryoku-refresh-quickshell                      # sync config/quickshell/ tree to ~/.config
```

### Per-file responsibilities

**`shell.qml`** (root). ShellRoot containing `Variants { model: Screens.screens }` that instantiates `Frame` and `ExclusionZones` per monitor. Imports `modules/frame`, `config`.

**`modules/frame/Frame.qml`**. Per-monitor `StyledWindow` on `WlrLayer.Bottom`, anchors to all four edges, `surfaceFormat.opaque: false`, `exclusionMode: ExclusionMode.Ignore`. Draws the frame shape. Reads thickness and rounding from `Config`, color from `Config.frame.color`.

**`modules/frame/ExclusionZones.qml`**. Scope with four `StyledWindow` surfaces; each `implicitWidth: 1`, `implicitHeight: 1`, `mask: Region {}`, `exclusiveZone: <per-edge value>`, anchored to its edge.

**`config/Config.qml`**. `pragma Singleton QtObject`. Exposes:
- `readonly property int frameThickness: 8`
- `readonly property int matboard: 8`
- `readonly property int rounding: 16`
- `readonly property int topExclusion: 8`
- `readonly property int sideExclusion: 16`  // frameThickness + matboard
- `readonly property color frameColor`: initially `#171717` (first-boot fallback); replaced by value from the theme-rendered file below via `Quickshell.FileView`.

**`default/themed/quickshell-colors.qml.tpl`**. One-line template:
```qml
pragma Singleton
import QtQuick
QtObject { readonly property color frame: "{{ background }}" }
```
Ryoku's existing theme renderer substitutes `{{ background }}` on every `ryoku-theme-set` and writes `~/.config/ryoku/current/theme/quickshell-colors.qml`. `Config.qml` loads this file via `FileView { reloadable: true }`; the theme color change triggers an atomic recolor with no QS restart.

**`bin/ryoku-launch-shell`**. Bash wrapper. If `quickshell` binary is missing, prints a clear error and exits 1 (the autostart line's toggle gate makes this non-fatal for the session). Otherwise `exec quickshell -c ryoku "$@"`.

**`bin/ryoku-toggle-frame`**. Mirrors `ryoku-toggle-waybar`:
1. Check state via `ryoku-toggle-enabled frame-off`.
2. Flip it (`ryoku-toggle-enabled frame-off on|off`).
3. Write or remove `~/.local/state/ryoku/toggles/hypr/frame.conf` with gap overrides (see "Hyprland drop-in" below).
4. `hyprctl reload`.
5. If enabling, `pkill -x quickshell` (cleanup) then `uwsm-app -- ryoku-launch-shell >/dev/null 2>&1 &`. If disabling, just `pkill -x quickshell`.
6. `notify-send` the result.

**`bin/ryoku-refresh-quickshell`**. New Ryoku refresh helper. Walks `$RYOKU_PATH/config/quickshell/ryoku/` and mirrors into `~/.config/quickshell/ryoku/` with `.bak.<timestamp>` backups of any files that differ. Exists because `ryoku-refresh-config` is file-by-file; this one handles a subtree. Used on upgrade (after `ryoku-update` pulls new QML).

### Hyprland drop-in

When the frame is enabled, `ryoku-toggle-frame` writes:

```conf
# Auto-managed by ryoku-toggle-frame. Do not edit by hand.
general {
    gaps_out = 0
    gaps_in = 6
}
decoration {
    rounding = 16
}
```

Path: `~/.local/state/ryoku/toggles/hypr/frame.conf`. Already sourced by `~/.config/hypr/hyprland.conf` via the existing `source = ~/.local/state/ryoku/toggles/hypr/*.conf` line. When disabled, the file is removed; Hyprland falls back to theme-level gap/rounding values.

### Autostart

One new line appended to `default/hypr/autostart.conf`, mirroring the Waybar gate:

```conf
exec-once = ! ryoku-toggle-enabled frame-off && uwsm-app -- ryoku-launch-shell
```

On every new Ryoku install, the frame starts at first login. Disabled state (`frame-off` flag present) short-circuits the exec.

### Packaging

`install/packaging/base.sh` gets `quickshell` appended to the `pacman -S --needed` list (extra repo, ~40 MB compressed / ~120 MB installed, Qt6-based). A comment on the line pins the tested version:

```bash
# quickshell 0.2.1 verified; the project is pre-1.0, inspect release notes on upgrade.
```

## Gaps that need to be implemented in Phase 1

Each of these is a deliberate design choice that is easy to miss during implementation. Flag them on the plan so they do not get skipped.

1. **Top-edge is intentionally frame-less.** Frame.qml must draw on left, right, bottom only. The top matboard is achieved via the 8 px top `ExclusionZone`, not a drawn strip. This is the resolution of "frame is an extension of the bar", not a limitation to fix later.
2. **Config.qml needs a hard-coded fallback color.** The first boot after install runs `ryoku-launch-shell` before `ryoku-theme-set` has rendered `quickshell-colors.qml`. Without a fallback the frame renders transparent and the user sees no frame until they change themes. Fallback is `#171717`.
3. **`ryoku-launch-shell` must fail non-fatally.** A missing `quickshell` binary (bad install) must not break the rest of the Hyprland session. Print to stderr, exit non-zero, let the autostart line swallow the failure.
4. **`ryoku-toggle-frame` must be idempotent.** Running it twice returns to the same state. Writing the drop-in conf uses atomic replace; deleting handles "file does not exist" without error.
5. **Quickshell version note in `base.sh`.** The comment is the only signal during `ryoku-update` that an upgrade might break the shell. Do not skip it.
6. **Waybar is assumed to own the top layer.** Any future change that moves Waybar to left/right/bottom or replaces it with a QS bar must revisit the exclusion zone table. Document in the spec; no code enforcement needed in Phase 1.

## Gaps intentionally deferred to Phase 2+

1. QS-native bar that visually merges with the frame (removes the top Waybar/frame seam).
2. Fullscreen auto-hide of the frame.
3. Per-monitor thickness.
4. Animated transitions on theme switch.
5. IPC command surface (`ryoku-frame set-thickness N`, etc.).
6. Replacing Waybar, mako, hyprlock, walker/tofi.

## Test plan

Incremental. Each step is reversible.

1. **Parse check.** `quickshell --dry-run -c ryoku` returns 0; imports resolve.
2. **Single-monitor smoke test.** Foreground run with `-v`: frame shows on three sides, matboard wallpaper strip visible all four sides including top.
3. **Window placement math.** Open an Alacritty window, `hyprctl activewindow`: position is `(16, 34)`, size is `(screen_w - 32, screen_h - 50)`.
4. **Theme switch.** `ryoku-theme-set tokyo-night` -> frame color tracks. Back to ristretto -> tracks.
5. **Toggle roundtrip.** `ryoku-toggle-frame` off -> frame gone, matboard gone, windows expand to bar edge; on -> frame back.
6. **Multi-monitor (when available).** Plug external, confirm two frames, unplug, confirm one.
7. **Crash recovery.** `pkill -9 quickshell`, relaunch via `ryoku-launch-shell`; exclusion zones and drop-in survive.
8. **Rollback sanity.** `ryoku-toggle-frame` off; `git reset --hard pre-phase1-frame` in both trees; delete `~/.config/quickshell/ryoku/`; `ryoku-refresh-config hypr/autostart.conf`; `hyprctl reload`; state matches pre-Phase 1.

## Snapshot and rollback

Both trees tagged `pre-phase1-frame`:

- Dev clone at `/home/omi/prowl/ryoku-arch`, tag points at commit `42cdc353` ("fix: Ryoku-branded hyprlock lockscreen").
- Installed tree at `~/.local/share/ryoku`, tag points at commit `7f45b365` ("fix: sync Ryoku-branded hyprlock lockscreen from dev clone").

Rollback procedure:

```bash
# stop the frame
ryoku-toggle-frame off 2>/dev/null; pkill -x quickshell 2>/dev/null

# reset both trees
cd /home/omi/prowl/ryoku-arch && git reset --hard pre-phase1-frame
cd ~/.local/share/ryoku && git reset --hard pre-phase1-frame

# clean live
rm -rf ~/.config/quickshell/ryoku
ryoku-refresh-config hypr/autostart.conf
rm -f ~/.local/state/ryoku/toggles/hypr/frame.conf
hyprctl reload
```

The `~/.local/share/omarchy` -> `~/.local/share/ryoku` compat symlink is part of the pre-Phase 1 snapshot state; it is not reverted by git reset. That is intentional; the rename is an orthogonal independence step.

## Phase 2 hooks (for future spec)

- **`modules/bar/`** slots alongside `modules/frame/`. Its exclusion zone replaces Waybar's 26 px top reservation. Frame's exclusion table updates to give the top edge the same 16 px as the others.
- **`services/`** grows to hold Hyprland IPC wrapper, theme watcher, notification bus subscription.
- **`components/`** grows for shared styled widgets (rect with theme tokens, text with theme font, etc.).
- **`Config.qml`** grows with a `bar`, `dashboard`, `launcher` sections alongside `frame`.
- **`ryoku-toggle-frame`** generalises to `ryoku-toggle-shell` once QS owns more surfaces.
