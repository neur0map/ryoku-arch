# Brain_Shell Port: Spec 1 (Vendor, TopBar, Dashboard)

**Status:** Draft for implementation
**Date:** 2026-04-28
**Scope:** First spec of the Ryoku visual-layer migration to a vendored fork of Brain_Shell. This document covers the vendoring, theme bridge, security patches, and activation of the TopBar plus the Dashboard popup. Bar widgets, notifications, OSD, network/wallpaper popups, and retirement of existing Ryoku surfaces (waybar, mako, swayosd, fuzzel) are out of scope here and land in subsequent specs.

---

## 1. Problem statement

Ryoku has an existing minimal Quickshell config at `config/quickshell/ryoku/` that renders a decorative Frame and ExclusionZones. Everything else visible (top bar, notifications, OSD, app launcher, settings tree) is provided by separate components: waybar, mako, swayosd, fuzzel via the tofi shim, and the `bin/ryoku-menu` tofi tree.

The strategic direction (per project memory) is to migrate the visual layer to a port of Brain_Shell (Brainiac, MIT, vendored with explicit permission). Brain_Shell ships a coherent Quickshell-based shell with a distinctive 3-notch TopBar, click-to-expand Dashboard with launcher tab, and a popup ecosystem that maps onto the surfaces Ryoku currently splits across waybar/mako/swayosd/fuzzel.

This spec lands the foundation: the vendored upstream code, the theme bridge from Ryoku's existing palette pipeline, the security patches Ryoku requires, and the first user-visible Brain_Shell surfaces (TopBar plus Dashboard). Existing Ryoku surfaces stay running in parallel for safe rollback. Subsequent specs retire each existing surface as Brain_Shell's equivalent comes online.

## 2. Scope

### In scope (Spec 1)

- Vendor Brain_Shell upstream `src/` and `shell.qml` into `config/quickshell/ryoku/vendor/brain-shell/`, preserving MIT attribution.
- Apply three security patches to vendored code (AppLauncher, CpuFreqService, WallpaperService).
- Apply three path rebrands (cache path, two cava temp paths) to vendored code.
- Extend `default/themed/quickshell-colors.qml.tpl` with Brain_Shell color properties; add new `default/themed/ryoku-shell-colors.json.tpl` for Brain_Shell's ColorLoader.
- Modify the existing `config/quickshell/ryoku/shell.qml` to additionally mount Brain_Shell's TopBar, PopupDismiss, ConfirmDialog, and PopupLayer (with Dashboard active and other popups commented out).
- Add `CREDITS.md` at repo root attributing Brainiac and Brain_Shell.
- Add a one-time post-update migration that restarts the running Quickshell process so users see the new shell without re-login.
- Add an end-to-end smoke test script under `tests/`.
- Document the snapshot prerequisite that gates implementation.

### Out of scope (deferred to future specs)

- Activation of any popup other than Dashboard (NetworkPopup, NotificationsPopup, NotificationToast, AudioPopup, QuickControl, WallpaperPopup, ScreenRecOptionsPopup, ArchMenu): vendored as code, dormant in PopupLayer.
- Activation of Brain_Shell's Border (existing Frame stays as the border system in Spec 1).
- Retirement of waybar, mako, swayosd, fuzzel/tofi shim, hyprlock, hypridle.
- Replacement of the `bin/ryoku-menu` tofi tree.
- Removal of any Brain_Shell Dashboard tab (kanban, etc.); future spec evaluates per the cybersecurity-angle filter.
- Hyprland layerrule polish (no_anim, blur, namespace pinning).
- New keybinds; Dashboard opens via clicking the TopBar center notch.
- Quickshell IPC mechanism; Brain_Shell uses internal `Popups` singleton state for triggers.
- Adding `cava`, `bluetoothctl`, `wireguard-tools`, `matugen` to the package set; the popups that need them are dormant.
- Renaming `bin/ryoku-toggle-frame` even though it now controls the whole shell.
- In-system "About" credit surface (LICENSE, UPSTREAM.md, CREDITS.md cover legal and ethical attribution; in-system credit waits for a Dashboard-tab spec).

### Existing Ryoku surfaces NOT modified

- waybar, mako, swayosd, hyprlock, hypridle: unchanged, still autostart, still wired to existing keybinds.
- fuzzel via tofi shim (`bin/tofi`, `bin/tofi-drun`): unchanged. `Super+Space`-equivalent app-launch flows continue to use fuzzel.
- `bin/ryoku-menu` tofi tree: unchanged.
- `bin/ryoku-launch-shell`, `bin/ryoku-restart-shell`, `bin/ryoku-refresh-quickshell`, `bin/ryoku-toggle-frame`: unchanged. These already exist and continue to work; the shell process they control now also hosts Brain_Shell components.
- `config/quickshell/ryoku/config/Config.qml`: unchanged (decorative Frame configuration).
- `config/quickshell/ryoku/modules/frame/Frame.qml` and `ExclusionZones.qml`: unchanged.

## 3. Architecture

### Process model

A single Quickshell process named `quickshell -c ryoku` already runs in the user's session, autostarted via `default/hypr/autostart.conf` line 7:

```
exec-once = ! ryoku-toggle-enabled frame-off && uwsm-app -- ryoku-launch-shell
```

After this spec, that same process hosts both the existing decorative Frame (and ExclusionZones) AND the new Brain_Shell components. Adding Brain_Shell does NOT spawn a second Quickshell process; we extend `config/quickshell/ryoku/shell.qml` to mount more `Variants` blocks alongside the existing two.

The existing `bin/ryoku-toggle-frame` toggle becomes a global on/off for the entire shell (Frame plus Brain_Shell). The script name is misleading after this spec but is not renamed in Spec 1; renaming is a follow-up cleanup.

### Quickshell version

This spec targets the `quickshell` package already in `install/ryoku-base.packages` (Arch `extra` at spec date is `quickshell 0.2.1-6`). Quickshell is pre-1.0 and APIs (`PanelWindow`, `WlrLayershell`, `FileView`, `IpcHandler`, `DesktopEntries`, etc.) can break across minor releases. Brain_Shell's source was authored against a recent Quickshell version; the implementer verifies upstream code starts cleanly under the installed version before vendoring more than the bare minimum, and substitutes equivalents for any renamed APIs.

### Vendoring and cherry-pick model

Brain_Shell upstream source lives under `config/quickshell/ryoku/vendor/brain-shell/`. Vendoring is verbatim with three patch types applied in the same vendoring commit and recorded in `UPSTREAM.md`:

1. The three security patches (Section 6).
2. The three path rebrands (Section 7).
3. The PopupLayer activation patch (Section 9).

All three patch types are small, line-level, and marked with a `// Ryoku: <description>` comment so future cherry-picks know what to re-apply.

Future upstream syncs follow a documented cherry-pick procedure (UPSTREAM.md). No `git submodule`, no `git subtree`, no automated mirror: a manual `cp -r` from a fresh upstream clone, then re-apply the patch list. This matches the omarchy-heritage cherry-pick pattern Ryoku already uses for its bash tooling.

## 4. File layout

### Files added

```
config/quickshell/ryoku/vendor/brain-shell/
  LICENSE                                Verbatim upstream MIT
  UPSTREAM.md                            Provenance, commit SHA, modification list, cherry-pick procedure
  shell.qml                              Vendored upstream root (kept as reference, not loaded)
  src/                                   Mirrors upstream src/ tree, all subdirs and qmldirs preserved

default/themed/
  ryoku-shell-colors.json.tpl            New JSON template for Brain_Shell ColorLoader

migrations/
  <unix-timestamp>.sh                    Restart running Quickshell so it picks up new shell.qml

CREDITS.md                               Repo-root credit doc, attributes Brainiac and Brain_Shell

tests/
  brain-shell-spec1.sh                   End-to-end smoke test for this spec
```

### Files changed

- **`config/quickshell/ryoku/shell.qml`** (existing 16 lines): add three new Variants blocks mounting Brain_Shell's TopBar, PopupDismiss, ConfirmDialog, and PopupLayer. Existing Frame and ExclusionZones blocks stay. Result is one ShellRoot mounting both the Phase-1 frame AND the Brain_Shell components.

- **`default/themed/quickshell-colors.qml.tpl`** (existing 7-line stub with one `frame` property): extend to expose the additional color properties Brain_Shell expects (`background`, `active`, `text`, `subtext`, `icon`, `border`, `iconFont`). The existing `frame` property stays so the decorative Frame keeps working unchanged. **Note**: this template renders to `quickshell-colors.qml` which the existing `Config.qml` reads via `Qt.createQmlObject`. The new properties are read by Brain_Shell components only; Config.qml's parsing tolerates extra properties (it only reads `loaded.frame`).

- **`default/quickshell/`** does NOT exist and is NOT created. All Quickshell QML lives under `config/quickshell/ryoku/` (existing convention).

- **`bin/ryoku-shell`, `bin/ryoku-launcher`, `bin/ryoku-refresh-shell`** are NOT created. The existing `bin/ryoku-launch-shell`, `bin/ryoku-restart-shell`, and `bin/ryoku-refresh-quickshell` cover the equivalent roles.

### Files explicitly NOT touched

- `config/quickshell/ryoku/config/Config.qml`
- `config/quickshell/ryoku/modules/frame/Frame.qml`
- `config/quickshell/ryoku/modules/frame/ExclusionZones.qml`
- `bin/ryoku-launch-shell`, `bin/ryoku-restart-shell`, `bin/ryoku-refresh-quickshell`, `bin/ryoku-toggle-frame`
- `bin/ryoku-menu` (entire menu tree)
- `default/tofi/pickers/*.sh`, `default/tofi/config`
- `bin/tofi`, `bin/tofi-drun`, `bin/ryoku-launch-drun` and all dmenu callers
- `default/hypr/autostart.conf` (the existing `ryoku-launch-shell` exec-once line is sufficient; no new entry)
- `default/hypr/bindings/*.conf` (no new keybind)
- `install/ryoku-base.packages` (`quickshell` is already present; nothing else added)
- waybar, mako, swayosd, hyprlock, hypridle config files and scripts
- Upstream Brain_Shell `README.md` (NOT vendored; contains em-dashes that fail the pre-commit hook, and the devlog content is upstream-internal; `UPSTREAM.md` carries the Ryoku-relevant story)

## 5. Theme bridge

Two template files render into `$RYOKU_CONFIG_PATH/current/theme/` on every `ryoku-theme-set` (no changes to the renderer needed; the existing loop in `bin/ryoku-theme-set-templates` iterates all `.tpl` files automatically).

### Existing template (extended)

`default/themed/quickshell-colors.qml.tpl` was a 7-line stub exposing only `frame`. Extend it to:

```qml
pragma Singleton
import QtQuick

QtObject {
    // Existing property used by the decorative Frame (Config.qml reads this).
    readonly property color frame: "{{ background }}"

    // Properties added in Spec 1 for Brain_Shell components that prefer
    // QML import over JSON file watching. Currently unused; reserved for
    // future Ryoku-authored components that import Theme directly.
    readonly property color background:  "{{ background }}"
    readonly property color foreground:  "{{ foreground }}"
    readonly property color accent:      "{{ accent }}"
}
```

`Config.qml` only reads `loaded.frame` so the additional properties are inert from its perspective. No risk to the existing Frame.

### New template

`default/themed/ryoku-shell-colors.json.tpl`:

```json
{
  "background": "{{ background }}",
  "active":     "{{ accent }}",
  "text":       "{{ foreground }}",
  "subtext":    "{{ color7 }}",
  "icon":       "{{ foreground }}",
  "border":     "{{ accent }}",
  "iconFont":   "{{ color6 }}"
}
```

Renders to `$RYOKU_CONFIG_PATH/current/theme/ryoku-shell-colors.json`. Read by the patched Brain_Shell ColorLoader (Section 7, Patch 4).

### Color mapping rationale

- `background` <- `background` (1:1)
- `active` <- `accent` (highlight color)
- `text` <- `foreground` (primary text)
- `subtext` <- `color7` (lighter foreground variant; matches "muted text" in most themes)
- `icon` <- `foreground` (Brain_Shell convention: icons share text color)
- `border` <- `accent` (subtle border use; consider mapping to `active_border_color` in a follow-up if the visual differs from intent)
- `iconFont` <- `color6` (cyan-ish accent in most palettes; gives icon glyphs a distinct color)

Themes whose `colors.toml` does not define `color6` or `color7` will render literal `{{ color6 }}` / `{{ color7 }}` in the JSON, which Brain_Shell's `_parse` function rejects (try/catch falls back to defaults). The implementer audits the 19 themes under `themes/` and confirms `color6` and `color7` are defined in each (the gruvbox sample does, suggesting the convention is universal). If any theme is missing these keys, the implementer adds sensible values matching the theme palette.

### Live theme reload

When the user runs `ryoku-theme-set <name>`:
1. The template renderer writes both files to `current/next-theme/`.
2. `ryoku-theme-set` swaps `next-theme` to `theme` (atomic rename).
3. `ryoku-theme-set` calls `ryoku-restart-shell`, which kills the Quickshell process and respawns it.
4. Brain_Shell's ColorLoader fires fresh on respawn and reads the new JSON.

Theme switch is therefore process-restart-driven (matches existing Frame behavior). Brain_Shell's `FileView { watchChanges: true }` would in principle support live reload without a restart, but the existing Ryoku theme pipeline already uses the restart pattern for the decorative Frame, and consistency is more valuable than cleverness here. A future spec can switch to live-reload-only once we confirm Brain_Shell's ColorLoader behaves correctly under live reload of a JSON file.

## 6. Security patches

Three patches applied to vendored code in the same vendoring commit. Each is a `// Ryoku: <description>` comment plus the change. Recorded in `UPSTREAM.md` so future cherry-picks re-apply them.

### Patch 1: AppLauncher Exec injection (HIGH)

`vendor/brain-shell/src/services/AppLauncher.qml:71`.

Before:
```javascript
launcher.command = ["bash", "-c", "setsid " + exec + " &>/dev/null &"]
```

After:
```javascript
// Ryoku: parse Exec per freedesktop spec (whitespace-split respecting
// quoted args, strip %f/%u/%i/%c/%k field codes), then exec via Process
// command array directly. Avoids shell injection from malicious or
// buggy .desktop Exec= fields.
function parseExec(raw) {
    var stripped = raw.replace(/%[a-zA-Z]/g, "").trim()
    var args = []
    var cur = ""
    var inQuote = null
    for (var i = 0; i < stripped.length; ++i) {
        var c = stripped[i]
        if (inQuote) {
            if (c === inQuote) { inQuote = null } else { cur += c }
        } else if (c === '"' || c === "'") {
            inQuote = c
        } else if (c === ' ' || c === '\t') {
            if (cur) { args.push(cur); cur = "" }
        } else { cur += c }
    }
    if (cur) args.push(cur)
    return args
}
launcher.command = ["setsid"].concat(parseExec(exec))
```

### Patch 2: CpuFreqService governor injection (MEDIUM)

`vendor/brain-shell/src/services/system/CpuFreqService.qml:116`.

Before:
```javascript
"echo " + gov + " | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
```

After:
```javascript
// Ryoku: validate gov against allowlist before shell interpolation.
// Linux kernel governors are a fixed set; reject anything else.
var allowed = ["performance", "powersave", "ondemand", "conservative", "schedutil", "userspace"]
if (allowed.indexOf(gov) === -1) {
    console.warn("[ryoku-shell] rejected unknown CPU governor:", gov)
    return
}
"echo " + gov + " | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
```

### Patch 3: WallpaperService configPath shell-quote injection (LOW)

`vendor/brain-shell/src/services/WallpaperService.qml:62`.

Before:
```javascript
command: ["bash", "-c", "cat '" + root.configPath + "' 2>/dev/null"]
```

After:
```javascript
// Ryoku: drop the shell wrapper; pass path as a Process arg directly.
// Eliminates single-quote-escape injection in path strings.
command: ["cat", root.configPath]
```

This patch only takes effect when `WallpaperPopup` is active (dormant in Spec 1) but is applied now so the vendored code is safe by default.

## 7. Path rebrands

Three files have hardcoded `brain-shell` / `brain_shell` path components. All rebranded to `ryoku-shell`. Each is a `// Ryoku: ...` comment plus the change. Recorded in `UPSTREAM.md`.

### Patch 4: ColorLoader cache path -> Ryoku theme path

`vendor/brain-shell/src/theme/ColorLoader.qml:39`. The header comment at line 5 is also updated.

Before:
```javascript
colorsFile.path = h + "/.cache/brain-shell/colors.json"
```

After:
```javascript
// Ryoku: read colors from the rendered theme path; written by
// ryoku-theme-set-templates from default/themed/ryoku-shell-colors.json.tpl.
colorsFile.path = h + "/.config/ryoku/current/theme/ryoku-shell-colors.json"
```

### Patch 5: CavaService temp config path

`vendor/brain-shell/src/services/CavaService.qml`. All `/tmp/brain_shell/` occurrences replaced with `/tmp/ryoku-shell/`. The `mkdir -p /tmp/ryoku-shell` line ensures the directory exists before cava writes.

### Patch 6: ScreenRecService temp config path

`vendor/brain-shell/src/services/ScreenRecService.qml`. Same `/tmp/brain_shell/` -> `/tmp/ryoku-shell/` replacement.

## 8. Branding and attribution

Five places carry credit:

1. **`config/quickshell/ryoku/vendor/brain-shell/LICENSE`**: upstream MIT verbatim, never modified.

2. **`config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md`** (Ryoku-authored):

   ```markdown
   # Vendored Brain_Shell

   Source:        https://github.com/Brainitech/Brain_Shell
   Author:        Brainiac (Brainitech)
   License:       MIT (see LICENSE)
   Vendored at:   <commit SHA from clone time>
   Vendored by:   Ryoku Project, with explicit permission from upstream.

   This directory is the Ryoku Quickshell visual layer, derived from
   Brain_Shell. Modifications below preserve the MIT license and the
   upstream copyright. Future cherry-picks from upstream re-apply each
   modification listed here.

   ## Modifications

   1. Security: AppLauncher.qml line 71. Parse Exec field per freedesktop
      spec instead of shell-interpolating the raw string. Prevents command
      injection from malicious or buggy .desktop entries.
   2. Security: CpuFreqService.qml line 116. Validate gov against an
      allowlist before shell interpolation.
   3. Security: WallpaperService.qml line 62. Replace `bash -c "cat
      '<path>'"` with direct `["cat", path]` Process command.
   4. Branding: ColorLoader.qml line 39. Read colors from
      `$HOME/.config/ryoku/current/theme/ryoku-shell-colors.json`,
      written by Ryoku's theme pipeline.
   5. Branding: CavaService.qml. Cava temp config path moved from
      `/tmp/brain_shell/` to `/tmp/ryoku-shell/`.
   6. Branding: ScreenRecService.qml. Cava recording temp config path
      moved from `/tmp/brain_shell/` to `/tmp/ryoku-shell/`.
   7. Activation: PopupLayer.qml. Only Dashboard is instantiated in
      Ryoku Spec 1; other popups are commented out and re-enabled in
      follow-up specs.

   ## Cherry-pick procedure

   When pulling a fresh upstream snapshot:

   1. `git clone https://github.com/Brainitech/Brain_Shell /tmp/brainshell-fresh`
   2. Note new commit SHA.
   3. `cp -r /tmp/brainshell-fresh/src/* config/quickshell/ryoku/vendor/brain-shell/src/`
   4. `cp /tmp/brainshell-fresh/shell.qml config/quickshell/ryoku/vendor/brain-shell/shell.qml`
   5. Re-apply each modification listed above. Diffs of prior patches
      live in git history; `git log --follow config/quickshell/ryoku/vendor/brain-shell/src/<file>`.
   6. Update commit SHA at the top of this file.
   7. Run the smoke test (`tests/brain-shell-spec1.sh`).

   ## Upstream qmldir notes

   Upstream `src/services/qmldir` contains a typo on the line
   `TempService ./system/empService.qml` (should be `TempService.qml`).
   This is an upstream bug. If `TempService` is referenced anywhere in
   the active component graph, QML will fail to resolve it. Spec 1
   activates only Dashboard; if Dashboard's transitive imports do NOT
   touch TempService, the typo is dormant and we leave it untouched
   (preserving verbatim upstream). If Dashboard does touch TempService,
   patch the qmldir to the correct filename and add Patch 8 to UPSTREAM.md.
   ```

3. **Per-file copyright headers** preserved on every vendored file. When a file is modified by a Ryoku patch, the existing header (if any) is preserved and a single line is appended:

   ```qml
   // SPDX-License-Identifier: MIT
   // Copyright (c) 2026 Brainiac (Brainitech)
   // Modifications copyright (c) 2026 Ryoku Project (see vendor/brain-shell/UPSTREAM.md)
   ```

   Files without an existing upstream header get the header added on first modification.

4. **Top-level `CREDITS.md`** at repo root (new file):

   ```markdown
   # Credits

   Ryoku is built on the work of others. The most significant external
   contributions are below.

   ## Brain_Shell

   The Ryoku Quickshell visual layer is derived from Brain_Shell by
   Brainiac (Brainitech), MIT licensed and used with explicit permission.

   - Upstream: https://github.com/Brainitech/Brain_Shell
   - Vendored under: config/quickshell/ryoku/vendor/brain-shell/
   - License: MIT (see config/quickshell/ryoku/vendor/brain-shell/LICENSE)
   - Modifications recorded in config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md

   ## Omarchy

   Ryoku's tooling backbone (the ryoku-* script ecosystem, theme
   pipeline shape, menu architecture) descends from Omarchy. Reference
   is preserved in script structure and patterns rather than file
   headers.
   ```

5. **In-system credit**: deferred. A Dashboard-tab spec adds an "About" tab with the credit text; this requires implementing UI, which is out of scope here. LICENSE plus UPSTREAM.md plus CREDITS.md cover the legal and ethical attribution requirements until then.

## 9. Activation: shell.qml extension and PopupLayer Reading X

### Extended `config/quickshell/ryoku/shell.qml`

```qml
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell

// Existing Phase-1 decorative frame components.
// (Frame and ExclusionZones live under modules/frame/.)

// Brain_Shell vendored components.
import "vendor/brain-shell/src/windows" as BSW
import "vendor/brain-shell/src/popups" as BSP

ShellRoot {
    // Existing decorative Frame, untouched.
    Variants {
        model: Quickshell.screens
        Frame {}
    }

    // Existing exclusion zones, untouched.
    Variants {
        model: Quickshell.screens
        ExclusionZones {}
    }

    // Brain_Shell additions: TopBar, popup-dismiss overlay, confirm-dialog
    // scaffold, and PopupLayer (with only Dashboard active per Reading X).
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                required property var modelData

                BSW.TopBar         { id: bsTopBar; screen: modelData }
                BSW.PopupDismiss   { screen: modelData }
                BSW.ConfirmDialog  { screen: modelData }

                BSP.PopupLayer {
                    topBar:       bsTopBar
                    leftBorder:   null
                    rightBorder:  null
                    bottomBorder: null
                }
            }
        }
    }

    Component.onCompleted: console.log("[ryoku-shell] up with brain-shell components")
}
```

`leftBorder` / `rightBorder` / `bottomBorder` are passed as `null` because Brain_Shell's Border is dormant in Spec 1; the existing Ryoku Frame fills that role. Popups that anchor to those borders (ArchMenu, AudioPopup, NotificationToast) are dormant in Spec 1 and never reference the null anchors. The implementer verifies that PopupLayer tolerates null anchor properties when the dormant popups are commented out (they should: `required property` only fires when the property is read at instantiation time, and dormant popups are never instantiated).

### PopupLayer Reading X (Patch 7)

`vendor/brain-shell/src/popups/PopupLayer.qml` is patched: every popup except `Dashboard` is commented out.

```qml
// Ryoku Spec 1 activation: Dashboard active. Others vendored as code
// but dormant; re-enable each in a follow-up spec when its replacement
// for the existing Ryoku surface (mako, swayosd, fuzzel, etc.) is
// validated.
Item {
    id: root
    required property var topBar
    property var leftBorder:   null
    property var rightBorder:  null
    property var bottomBorder: null

    Dashboard { anchorWindow: root.topBar }

    // ArchMenu              { anchorWindow: root.leftBorder }
    // WallpaperPopup        {}
    // AudioPopup            { anchorWindow: root.rightBorder }
    // QuickControl          { anchorWindow: root.topBar }
    // NotificationsPopup    { anchorWindow: root.topBar }
    // NotificationToast     { anchorWindow: root.rightBorder }
    // ScreenRecOptionsPopup { anchorWindow: root.topBar }
    // NetworkPopup          {}
}
```

The `required property var` declarations for the border anchors are softened to `property var ... : null` so callers can pass null without QML errors when dormant popups would have been their only consumers.

### Multi-monitor behavior

The shell.qml uses `Variants { model: Quickshell.screens }`, mounting one TopBar instance per monitor. Brain_Shell's `Popups.dashboardOpen` is a global singleton, so opening Dashboard on one monitor opens it on all monitors simultaneously. This is upstream behavior; we ship it as-is in Spec 1. A follow-up spec can scope Dashboard visibility per monitor if the multi-monitor experience is poor, by patching Popups.qml to track per-screen state.

## 10. Snapshot prerequisite

**Implementation does not begin until all snapshots are recorded.** The first task in the implementation plan runs these and prints the resulting paths so the user knows what to revert to.

```bash
# Layer 1: git tag the dev clone.
cd /home/omi/prowl/ryoku-arch
git tag pre-brainshell-vendor-2026-04-28 HEAD

# Layer 2: backup the installed Ryoku tree (omarchy heritage).
tstamp=$(date +%Y%m%d-%H%M%S)
cp -aL ~/.local/share/ryoku ~/.local/share/ryoku.pre-brainshell.$tstamp

# Layer 3: backup the live Quickshell config (separate path).
[[ -d ~/.config/quickshell/ryoku ]] && \
  cp -aL ~/.config/quickshell/ryoku ~/.config/quickshell/ryoku.pre-brainshell.$tstamp

# Layer 4 (optional): full filesystem snapshot if available.
command -v timeshift >/dev/null && \
  sudo timeshift --create --comments "pre-brainshell-vendor-$tstamp"
command -v snapper >/dev/null && \
  sudo snapper -c root create -d "pre-brainshell-vendor-$tstamp"
```

If layers 3 or 4 are skipped (no live config yet, no timeshift/snapper installed, non-btrfs filesystem), layers 1 and 2 are sufficient for hard rollback per Section 13's rollback procedure.

## 11. Hyprland integration

**No Hyprland configuration changes in Spec 1.** The existing autostart line at `default/hypr/autostart.conf:7` already starts the Quickshell process via `ryoku-launch-shell`. After this spec, the same process hosts Brain_Shell components alongside the existing Frame; no new exec-once entry, no new keybind, no layerrule polish.

The implementer notes that `config/quickshell/ryoku/qmldir` (top-level) and per-subdirectory qmldir files already exist for the Phase-1 Frame components. The vendored Brain_Shell tree under `vendor/brain-shell/` ships its own qmldir files (one at `src/`, `src/theme/`, `src/services/`); these are imported explicitly in the extended shell.qml via the `import "vendor/brain-shell/src/..."` lines in Section 9 and do not need to be merged into Ryoku's top-level qmldir.

Brain_Shell PanelWindows do not set `WlrLayershell.namespace` explicitly. Hyprland defaults apply, which means default Hyprland layer-shell animations may compound with any QML animations on open. This is accepted in Spec 1; a follow-up "visual polish" spec adds explicit namespaces and matching `layerrule` entries once we know which namespaces Quickshell auto-assigns.

## 12. Migration script

`migrations/<unix-timestamp>.sh`. The implementer picks a timestamp with `date +%s`, ensuring the value exceeds the highest existing migration filename. The script:

```bash
#!/bin/bash
# Spec 1 migration: the Quickshell process is already running at update
# time with the OLD shell.qml that mounts only Frame and ExclusionZones.
# After update, restart it so it picks up the NEW shell.qml that ALSO
# mounts Brain_Shell components. Without this, users wait until next
# session login to see the new shell.

set -e
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/lib/runtime-env.sh"

# Skip if no graphical session.
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
  exit 0
fi

# Skip if user has explicitly disabled the shell (frame-off toggle).
if ryoku-toggle-enabled frame-off; then
  exit 0
fi

# Mirror the dev tree to the user's installed config (gets the new
# shell.qml + vendor/brain-shell/ tree into ~/.config/quickshell/ryoku/).
ryoku-refresh-quickshell

# Restart the running Quickshell process so it loads the new shell.qml.
# Uses the existing helper which does pkill + setsid-respawn.
ryoku-restart-shell

# Brief grace period, then notify if the new shell came up.
sleep 0.5
if pgrep -x quickshell >/dev/null 2>&1; then
  notify-send -u low \
    "Ryoku Shell updated" \
    "Brain_Shell components are now visible alongside the existing frame and waybar. Click the center of the top to open the Dashboard. To disable everything (frame plus new components), run: ryoku-toggle-frame"
fi
```

The notification copy explicitly tells the user the rollback command (`ryoku-toggle-frame`) to support the easy-returns requirement.

## 13. Acceptance criteria: snapshot, static, runtime, rollback

This list is the implementer's done-definition. Per repo memory, picker-opens / process-up is not proof; runtime checks must verify the actual visible outcome.

### Pre-implementation verification

Before writing any vendoring patch, verify the assumed Quickshell APIs work against the installed version. Steps:

1. Clone Brain_Shell to /tmp:
   `git clone --depth 1 https://github.com/Brainitech/Brain_Shell /tmp/bs-probe`
2. Note the upstream commit SHA.
3. Try running the upstream shell directly without any patches:
   `qs -c bs-probe -p /tmp/bs-probe` (or `quickshell -c bs-probe -p /tmp/bs-probe`)
4. If the daemon starts cleanly without QML errors, the API surface is compatible. Record the SHA in UPSTREAM.md and proceed.
5. If errors appear, identify which APIs Quickshell renamed/removed and adapt vendored files (add to UPSTREAM.md as additional patches).
6. Tear down: `pkill -f "qs -c bs-probe"` and remove `/tmp/bs-probe`.

### Snapshot evidence

```bash
git rev-parse pre-brainshell-vendor-2026-04-28 >/dev/null 2>&1 || fail "git tag missing"
ls ~/.local/share/ryoku.pre-brainshell.*       >/dev/null 2>&1 || fail "installed-tree backup missing"
```

(Quickshell config backup and timeshift snapshot are optional per Section 10.)

### Static checks (`tests/brain-shell-spec1.sh`)

```bash
#!/bin/bash
set -e
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "OK: $1"; }

# --- File structure ----------------------------------------------------
[[ -f config/quickshell/ryoku/vendor/brain-shell/LICENSE ]]    || fail "vendored LICENSE missing"
[[ -f config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md ]] || fail "UPSTREAM.md missing"
[[ -d config/quickshell/ryoku/vendor/brain-shell/src/popups ]]  || fail "vendored src/popups missing"
[[ -d config/quickshell/ryoku/vendor/brain-shell/src/windows ]] || fail "vendored src/windows missing"
[[ -f config/quickshell/ryoku/shell.qml ]]                       || fail "shell.qml missing"
[[ -f default/themed/ryoku-shell-colors.json.tpl ]]              || fail "JSON theme template missing"
[[ -f default/themed/quickshell-colors.qml.tpl ]]                || fail "QML theme template missing"
[[ -f CREDITS.md ]]                                              || fail "CREDITS.md missing"
pass "file structure"

# --- shell.qml extends, does not replace -------------------------------
grep -q '^\s*Frame\s*{}' config/quickshell/ryoku/shell.qml \
  || fail "Frame removed from shell.qml (Spec 1 requires it stay)"
grep -q '^\s*ExclusionZones\s*{}' config/quickshell/ryoku/shell.qml \
  || fail "ExclusionZones removed from shell.qml (Spec 1 requires it stay)"
grep -q 'BSW.TopBar' config/quickshell/ryoku/shell.qml \
  || fail "Brain_Shell TopBar not mounted in shell.qml"
grep -q 'BSP.PopupLayer' config/quickshell/ryoku/shell.qml \
  || fail "Brain_Shell PopupLayer not mounted in shell.qml"
pass "shell.qml extension"

# --- Security patches applied ------------------------------------------
grep -q "Ryoku: parse Exec per freedesktop spec" \
  config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml \
  || fail "AppLauncher security patch missing"
grep -q "Ryoku: validate gov against allowlist" \
  config/quickshell/ryoku/vendor/brain-shell/src/services/system/CpuFreqService.qml \
  || fail "CpuFreqService security patch missing"
grep -q '"cat", root.configPath' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/WallpaperService.qml \
  || fail "WallpaperService security patch missing"
pass "security patches"

# --- Path rebrands (only on the three patched files) -------------------
! grep -q '/.cache/brain-shell/' \
  config/quickshell/ryoku/vendor/brain-shell/src/theme/ColorLoader.qml \
  || fail "ColorLoader still references brain-shell cache path"
! grep -q '/tmp/brain_shell/' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml \
  || fail "CavaService still references brain_shell tmp path"
! grep -q '/tmp/brain_shell/' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/ScreenRecService.qml \
  || fail "ScreenRecService still references brain_shell tmp path"
pass "path rebrands"

# --- Theme bridge: rendered JSON is valid and substituted -------------
ryoku-theme-set-templates 2>/dev/null || true
RENDERED="$HOME/.config/ryoku/current/theme/ryoku-shell-colors.json"
[[ -f $RENDERED ]] || RENDERED="$HOME/.config/ryoku/current/next-theme/ryoku-shell-colors.json"
if [[ -f $RENDERED ]]; then
  ! grep -q '{{' "$RENDERED"                            || fail "rendered JSON has unsubstituted placeholders"
  python3 -c "import json,sys; json.load(open('$RENDERED'))" \
    || fail "rendered JSON is malformed"
  pass "theme bridge"
else
  echo "SKIP: rendered JSON not found at $RENDERED"
fi

# --- PopupLayer activation matches Reading X --------------------------
grep -E '^\s*Dashboard\s*\{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml \
  | grep -v '//' >/dev/null \
  || fail "Dashboard not active in PopupLayer"
DORMANT_COUNT=$(grep -cE '^\s*//\s*(ArchMenu|WallpaperPopup|AudioPopup|QuickControl|NotificationsPopup|NotificationToast|ScreenRecOptionsPopup|NetworkPopup)\s*\{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml)
[[ $DORMANT_COUNT -eq 8 ]] \
  || fail "expected 8 dormant popups in PopupLayer, got $DORMANT_COUNT"
pass "PopupLayer activation"

# --- Existing stack untouched -----------------------------------------
grep -q "uwsm-app -- waybar" default/hypr/autostart.conf \
  || fail "waybar exec-once was removed (Spec 1 requires it stay)"
grep -q "uwsm-app -- mako" default/hypr/autostart.conf \
  || fail "mako exec-once was removed (Spec 1 requires it stay)"
[[ -x bin/tofi && -x bin/tofi-drun ]] \
  || fail "tofi shims were removed (Spec 1 requires they stay)"
[[ -x bin/ryoku-launch-shell ]]  || fail "ryoku-launch-shell removed"
[[ -x bin/ryoku-restart-shell ]] || fail "ryoku-restart-shell removed"
[[ -x bin/ryoku-refresh-quickshell ]] || fail "ryoku-refresh-quickshell removed"
[[ -x bin/ryoku-toggle-frame ]]  || fail "ryoku-toggle-frame removed"
pass "existing stack untouched"

echo ""
echo "Static checks pass. Now run the manual checklist in the spec."
```

### Manual runtime checks (must verify visible outcomes, per repo memory)

After the bash script passes:

1. **Mirror dev tree to live config**: `ryoku-refresh-quickshell` (mirrors `config/quickshell/ryoku/` to `~/.config/quickshell/ryoku/`), then `ryoku-refresh-config` if needed for non-Quickshell files.
2. **Run the migration**: `./migrations/<timestamp>.sh`. Expected: notification appears, Quickshell process restarts.
3. **Daemon up**: `pgrep -x quickshell` returns a PID. Stderr/journalctl shows `[ryoku-shell] up with brain-shell components` with no QML parse errors.
4. **Existing Frame intact**: the decorative border around the screen edges is visible exactly as before. Frame width and color match pre-Spec-1 appearance.
5. **TopBar visible**: a 3-notch Brain_Shell bar appears at the top of each focused monitor, in addition to the existing waybar. Waybar still renders unchanged. **Two bars at top is expected for Spec 1** and is the validation that Reading X (additive) is working.
6. **Dashboard opens by clicking center notch**: the center notch expands into the Dashboard panel (~900x520). Tabs visible: home, stats, kanban, launcher, config.
7. **Theme colors correct**: TopBar and Dashboard colors match the active Ryoku theme (palette from `colors.toml` flowed through the JSON template into ColorLoader).
8. **Theme switch propagates**: run `ryoku-theme-set tokyo-night` (or any other theme). Quickshell process restarts (per existing `ryoku-theme-set` behavior). New colors appear on TopBar, Dashboard, AND the existing Frame (single restart updates everything).
9. **Launcher tab works end-to-end**: navigate to the Dashboard launcher tab. Real installed apps appear with real icons. Click an app: **the actual app window opens on screen** (not just "tab closed without erroring"; verify a window).
10. **Dashboard closes**: click the center notch again, or click outside. Dashboard collapses back to notch.
11. **Existing surfaces still work**: `Super+Space` (or whatever app-launcher keybind exists) opens fuzzel as before; mako produces notifications as before; swayosd appears on volume change as before; `ryoku-menu` opens the existing tofi tree as before. **Nothing existing was disabled.**
12. **Easy soft rollback**: `ryoku-toggle-frame`. Quickshell process is killed, Hyprland drop-in removed, frame-off flag set. Frame plus TopBar plus Dashboard all disappear together. Waybar continues. Re-running `ryoku-toggle-frame` brings everything back.
13. **Hard rollback** (if needed): use the snapshots from Section 10:
    - `pkill -x quickshell`
    - `git reset --hard pre-brainshell-vendor-2026-04-28`
    - `rsync -a --delete ~/.local/share/ryoku.pre-brainshell.<ts>/ ~/.local/share/ryoku/`
    - `[[ -d ~/.config/quickshell/ryoku.pre-brainshell.<ts> ]] && rsync -a --delete ~/.config/quickshell/ryoku.pre-brainshell.<ts>/ ~/.config/quickshell/ryoku/`
    - Log out and back in.
    - System returns to pre-Spec-1 state.

## 14. Out-of-scope confirmations

To keep the implementer focused, this spec does NOT cover:

- Activation of any popup other than Dashboard.
- Activation of Brain_Shell's Border (existing Frame stays).
- Retirement of waybar, mako, swayosd, fuzzel/tofi shim, hyprlock, hypridle.
- Replacement of `ryoku-menu`.
- Removal of Brain_Shell's kanban Dashboard tab (or any other tab).
- Layerrule namespaces or Hyprland animation polish.
- New keybinds; new IPC mechanism.
- New packages (cava, bluetoothctl, wireguard-tools, matugen).
- Renaming `ryoku-toggle-frame` even though it now controls the whole shell.
- In-system "About" credit surface.
- Live-reload of theme JSON (process restart on theme switch is the intended mechanism for now).
- Per-monitor Dashboard scoping (global Popups.dashboardOpen is upstream behavior).
- Any Go or Rust binary.
