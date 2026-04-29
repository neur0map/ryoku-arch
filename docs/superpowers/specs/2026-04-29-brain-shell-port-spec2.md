# Brain_Shell Port: Spec 2 (TopBar Visual Rework + Dashboard Sizing)

**Status:** Draft for implementation
**Date:** 2026-04-29
**Scope:** Second spec of the Brain_Shell port. Address four user-reported visual issues with the default TopBar and Dashboard from Spec 1: replace the Arch logo glyph with the Ryoku monogram, fix the placeholder-text layout indicators (`><`, `M`), shrink the bar's overall size, and shrink the Dashboard so it does not occupy more than half the screen on a 14-inch laptop. All four are small patches to the vendored Brain_Shell tree, recorded as Patches 8-11 in `UPSTREAM.md`.

**Spec 1 reference:** `docs/superpowers/specs/2026-04-28-brain-shell-port-spec1.md` shipped at commits `a1360a0f`...`c68dd438` (19 commits). Spec 2 builds on that vendored tree.

---

## 1. Problem statement

After Spec 1 shipped (TopBar plus Dashboard active, waybar retired), the user reported four visible issues with the default Brain_Shell visuals:

1. The left-corner icon shows the Arch Linux logo (Brain_Shell's default), not Ryoku branding. The icon is the trigger for the ArchMenu popup (which is dormant in Spec 1, so the icon currently does nothing on click).
2. A button beside the workspace indicator displays the literal text `><`. It is the active-Hyprland-layout indicator, but upstream's `LayoutDisplayer.qml` ships placeholder-text returns (`><`, `M`) instead of the Nerd Font glyphs documented in its own comment block. Functional but ugly.
3. The bar feels too tall and too padded for a 14-inch laptop screen. Default `notchHeight: 40`, `notchPadding: 16`, `exclusionGap: 34` reserve more vertical real estate than necessary.
4. The Dashboard, when opened by clicking the center notch, expands to `dashboardWidth: 900` x `dashboardHeight: 520`. On a 1280x800 screen that is 70% wide and 65% tall, dominating the screen. Per-tab widths in `Dashboard.qml _pageWidths` are also hardcoded to 900.

Spec 2 patches the vendored Brain_Shell to address each, with no changes to Ryoku's own code (existing `config/quickshell/ryoku/shell.qml`, `Theme.qml`, `Config.qml`, `modules/frame/`, etc. all stay).

## 2. Scope

### In scope (Spec 2)

- **Patch 8**: Replace the Arch logo glyph in `vendor/brain-shell/src/modules/Left/ControlPanel.qml` with the Ryoku monogram (kanji 力, "chikara/ryoku") rendered from `logo-mark.svg` via QML `Image`. Tinted to `Theme.accent` via `MultiEffect` color-overlay. PNG fallback at `logo-mark.png` if SVG renders poorly.
- **Patch 9**: Comment out the `LayoutDisplayer {}` instantiation in `vendor/brain-shell/src/modules/Left/LeftContent.qml`. The display-only layout indicator (with its placeholder-text quirks) is removed from the bar entirely. The `LayoutDisplayer.qml` file itself stays vendored (untouched) for future re-introduction as part of a clickable layout-switcher widget (queued in `docs/TODO.md` as Spec 2.5).
- **Patch 10**: Shrink the bar in `vendor/brain-shell/src/theme/Theme.qml`:
  - `notchHeight: 40` → `28`
  - `notchPadding: 16` → `10`
  - `notchHorizontalPadding: 20` → `14`
  - `notchVerticalPadding: 10` → `6`
  - `exclusionGap: 34` → `22`
  - `dashboardWidth: 900` → `720`
  - `dashboardHeight: 520` → `420`
- **Patch 11**: Update per-tab `_pageWidths` in `vendor/brain-shell/src/popups/Dashboard.qml` from 900 to 720 (so the center-notch expand-on-click width matches Patch 10's reduced `dashboardWidth`).
- **UPSTREAM.md update**: Add Patches 8-11 to the modifications list and bump the cherry-pick procedure note count.
- **Smoke test addition**: Extend `tests/brain-shell-spec1.sh` (or add `tests/brain-shell-spec2.sh`) to verify the patches landed: grep for the `// Ryoku:` markers added by each patch.

### Out of scope (deferred)

- Activating any popup other than Dashboard (still Spec 3-8).
- Activating Brain_Shell's Border (still Spec 8).
- Cybersecurity-specific TopBar widgets (firewall status, VPN indicator, etc.). Considered for a future Spec 2.5 once we see how the bar reads after sizing fixes.
- Restructuring which modules go in which notch. Default Brain_Shell layout (Workspaces / LayoutDisplayer / ControlPanel on left, DashStats in center, Audio / Battery / Clock / Network / Notifications / SysTray on right) stays.
- Switching Dashboard sizing to a percentage-of-screen formula. Fixed `720x420` is acceptable for 14-inch laptop screens; revisit if multi-monitor or very different resolutions surface.
- Replacing the kanji 力 with a different brand mark. The existing `logo-mark.svg` is canonical Ryoku branding; Spec 2 just wires it in.

### Existing surfaces NOT modified

- All Spec 1 vendored patches (Patches 1-7) stay untouched.
- All Ryoku-side files: `config/quickshell/ryoku/shell.qml`, `Theme.qml`, `config/Config.qml`, `modules/frame/`, `bin/ryoku-launch-shell`, `bin/ryoku-restart-shell`, `bin/ryoku-refresh-quickshell`, `bin/ryoku-toggle-frame`.
- All existing Ryoku stack: mako, swayosd, fuzzel via tofi shim, hyprlock, hypridle.

## 3. Patch 8: Ryoku monogram in ControlPanel

`vendor/brain-shell/src/modules/Left/ControlPanel.qml` is a 14-line file that currently reads:

```qml
import QtQuick
import "../../components"
import "../../"

IconBtn {
    text: ""
    textColor: "#1793d1"
    onClicked: {
        var next = !Popups.archMenuOpen
        Popups.closeAll()
        Popups.archMenuOpen = next
    }
}
```

Replace the glyph + Arch teal color with an Image element loading `logo-mark.svg`. The `IconBtn` component (in `vendor/brain-shell/src/components/IconBtn.qml`) is built around a Text element; we either replace it with a custom button that wraps Image, or keep IconBtn and override its content via composition.

Cleanest approach: keep using IconBtn for click-handling consistency, but replace its text with a child Image element. If IconBtn does not support child elements, write a parallel `IconImageBtn` component or rewrite ControlPanel as a `MouseArea { Image { ... } }` directly.

Implementer pattern: prefer the smallest change. If IconBtn.qml accepts a child `Item`, use it. Otherwise rewrite ControlPanel as a self-contained MouseArea + Image.

The Image:

```qml
Image {
    source: Qt.resolvedUrl("file:///path/to/Ryoku/logo-mark.svg")
    sourceSize: Qt.size(20, 20)
    fillMode: Image.PreserveAspectFit
    anchors.centerIn: parent
}
```

Tint to `Theme.accent`:

```qml
layer.enabled: true
layer.effect: MultiEffect {
    colorization: 1.0
    colorizationColor: Theme.accent
}
```

Path resolution: `logo-mark.svg` lives at the Ryoku repo root, which after `ryoku-refresh-config` becomes `~/.local/share/ryoku/logo-mark.svg`. Use `Quickshell.env("HOME") + "/.local/share/ryoku/logo-mark.svg"` for portability across users.

PNG fallback: if SVG renders poorly (Qt SVG is sometimes flaky with text-element SVGs), switch to `logo-mark.png`. Same loading code, different extension. Note: `noto-fonts-cjk` is in `install/ryoku-base.packages` so the SVG's font dependency is met on Ryoku systems.

The Ryoku-prefixed comment for cherry-pick re-application:

```qml
// Ryoku: replace Arch logo glyph with Ryoku monogram (kanji 力 from
// logo-mark.svg). Tints to Theme.accent. ArchMenu trigger behavior
// stays for when ArchMenu is activated in Spec 8.
```

## 4. Patch 9: Remove LayoutDisplayer from the bar

`vendor/brain-shell/src/modules/Left/LeftContent.qml` currently mounts three modules in the left notch:

```qml
Row {
    spacing: 5
    // 1. Arch Icon (Power Menu Trigger)
    ControlPanel{}

    // 2. Workspaces
    Workspaces {}

    //3. LayoutDisplay
    LayoutDisplayer {}
}
```

The `LayoutDisplayer` is a display-only indicator (polls `hyprctl -j activeworkspace` periodically; no click handling). Upstream ships placeholder-text returns (`><` for dwindle, `M` for master, bracketed window counts for monocle and scrolling), making the indicator both ugly and confusing (looks like a broken button). Per user direction, the indicator is removed from the bar in Spec 2.

Comment out the instantiation. Keep the `LayoutDisplayer.qml` file unchanged in `vendor/brain-shell/src/modules/Left/` for re-introduction as part of a future clickable layout-switcher widget (Spec 2.5, queued in `docs/TODO.md`).

The Ryoku-prefixed change:

```qml
Row {
    spacing: 5
    // 1. Arch Icon (Power Menu Trigger) - Ryoku Patch 8: now Ryoku monogram
    ControlPanel{}

    // 2. Workspaces
    Workspaces {}

    // Ryoku Patch 9: LayoutDisplayer removed from the bar.
    // Upstream's display-only indicator shipped placeholder-text returns
    // (><, M, bracketed counts) that look like a broken button. The
    // LayoutDisplayer.qml file stays vendored for future re-introduction
    // as a clickable layout-switcher widget (see docs/TODO.md Spec 2.5).
    // LayoutDisplayer {}
}
```

The file `LayoutDisplayer.qml` itself is NOT modified.

## 5. Patch 10: Smaller bar via Theme.qml constants

`vendor/brain-shell/src/theme/Theme.qml` is the singleton. Apply the value changes listed in Section 2. Each is a one-line change.

The Ryoku-prefixed comment block at the top of the changed section:

```qml
// Ryoku: shrink bar dimensions for 14-inch laptop screens. Originals
// were notchHeight 40, notchPadding 16, notchHorizontalPadding 20,
// notchVerticalPadding 10, exclusionGap 34. Dashboard original
// dimensions were 900x520; reduced to 720x420 (matched in Patch 11
// in Dashboard.qml _pageWidths).
```

Then the changed properties.

If the implementer believes the proportions read poorly after restart (e.g., notchHeight 28 makes content overflow the notch vertically), tune values within +/-4 of the proposed numbers and document the final landed values in the commit message.

## 6. Patch 11: Per-tab Dashboard widths

`vendor/brain-shell/src/popups/Dashboard.qml` lines 28-34 currently:

```javascript
readonly property var _pageWidths: ({
    "home":     900,
    "stats":    900,
    "kanban":   900,
    "launcher": 560,
    "config":   900
})
```

Reduce all 900 values to 720. Keep launcher at 560 (it was already tuned smaller). The center-notch expand-on-click width tracks this map, so reducing here ensures the notch does not overshoot Patch 10's `dashboardWidth: 720`.

The Ryoku-prefixed comment:

```qml
// Ryoku: reduce per-tab dashboard widths from 900 to 720 to match
// Patch 10's reduced Theme.dashboardWidth. Launcher tab was already
// 560 and stays.
```

## 7. UPSTREAM.md update

Append Patches 8-11 to the modifications list under the existing 1-7. New entries:

```
8. Branding: ControlPanel.qml. Replace Arch logo glyph and Arch teal
   color with Ryoku monogram (kanji 力) loaded from logo-mark.svg
   and tinted to Theme.accent.
9. Activation: LeftContent.qml. Comment out LayoutDisplayer
   instantiation. Upstream's display-only indicator shipped
   placeholder-text returns that looked like a broken button. The
   LayoutDisplayer.qml file stays vendored for future re-introduction
   as a clickable layout-switcher widget (Spec 2.5, see docs/TODO.md).
10. Branding: Theme.qml. Reduce notchHeight, notchPadding,
    notchHorizontalPadding, notchVerticalPadding, exclusionGap, and
    dashboard dimensions for 14-inch laptop screens. Original values
    documented in the comment alongside the change.
11. Branding: Dashboard.qml. Reduce per-tab _pageWidths from 900 to
    720 to match Patch 10's reduced Theme.dashboardWidth.
```

The cherry-pick procedure section stays as-is; future cherry-picks just re-apply 11 patches instead of 7.

## 8. Snapshot prerequisite

Spec 2 changes are small (4 vendored-file patches), but the repo snapshot model from Spec 1 still applies. Before the implementer starts:

```bash
cd /home/omi/prowl/ryoku-arch
git tag pre-brainshell-spec2-2026-04-29 HEAD

tstamp=$(date +%Y%m%d-%H%M%S)
cp -aL ~/.config/quickshell/ryoku ~/.config/quickshell/ryoku.pre-spec2.$tstamp
```

Filesystem-level snapshot is optional (the changes are bounded to QML files inside the vendored tree; rollback recipe is `git reset --hard pre-brainshell-spec2-2026-04-29 && ryoku-refresh-quickshell && ryoku-restart-shell`).

## 9. Acceptance criteria

### Static smoke test additions

Extend `tests/brain-shell-spec1.sh` (or add a new `tests/brain-shell-spec2.sh`) with:

```bash
grep -q "Ryoku: replace Arch logo glyph" \
  config/quickshell/ryoku/vendor/brain-shell/src/modules/Left/ControlPanel.qml \
  || fail "Patch 8 missing"
grep -q "Ryoku Patch 9: LayoutDisplayer removed" \
  config/quickshell/ryoku/vendor/brain-shell/src/modules/Left/LeftContent.qml \
  || fail "Patch 9 missing"
grep -q "^\s*//\s*LayoutDisplayer\s*{}" \
  config/quickshell/ryoku/vendor/brain-shell/src/modules/Left/LeftContent.qml \
  || fail "LayoutDisplayer instantiation not commented out"
[[ -f config/quickshell/ryoku/vendor/brain-shell/src/modules/Left/LayoutDisplayer.qml ]] \
  || fail "LayoutDisplayer.qml file should stay vendored for future re-use"
grep -q "Ryoku: shrink bar dimensions" \
  config/quickshell/ryoku/vendor/brain-shell/src/theme/Theme.qml \
  || fail "Patch 10 missing"
grep -q 'notchHeight:\s*28' \
  config/quickshell/ryoku/vendor/brain-shell/src/theme/Theme.qml \
  || fail "Patch 10 notchHeight not 28"
grep -q 'dashboardWidth:\s*720' \
  config/quickshell/ryoku/vendor/brain-shell/src/theme/Theme.qml \
  || fail "Patch 10 dashboardWidth not 720"
grep -q "Ryoku: reduce per-tab dashboard widths" \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Patch 11 missing"
```

### Manual runtime checks (visible-outcome)

After applying patches, mirroring dev to live config, and restarting Quickshell:

1. **Bar visibly shorter**: TopBar height feels around 28px (down from 40px).
2. **Bar visibly less padded**: notch internal padding feels tighter.
3. **Left-corner icon is the kanji 力 in accent color**: not the Arch teal logo.
4. **Layout indicator gone from the bar**: the `><`/`M` placeholder text is no longer visible. The left notch contains only the Ryoku monogram and the Workspaces module.
5. **Dashboard opens to a smaller size**: ~720x420, occupies less than 60% of a 1280x800 screen.
6. **Center-notch animation still tracks Dashboard width**: opening Dashboard expands the center notch from its closed width to 720, smoothly.
7. **No regressions**: Frame still around screen edges, theme colors still flow correctly, no QML errors in stderr.

If any check fails, identify which patch is responsible and iterate.

### Easy rollback

Soft: `ryoku-toggle-frame` (kills the Quickshell process; restores the pre-Spec-1 surface for the duration of the toggle).

Hard: `git reset --hard pre-brainshell-spec2-2026-04-29 && ryoku-refresh-quickshell && ryoku-restart-shell`.

## 10. Out-of-scope confirmations

- No changes to which Brain_Shell popups are active (Dashboard only, others dormant; same as Spec 1).
- No changes to Ryoku-side files outside the vendored tree.
- No new packages.
- No new keybinds.
- No retirement of mako, swayosd, fuzzel, hyprlock, hypridle.
- No restructuring of TopBar modules layout.
- No cybersec-specific widgets in the bar (deferred to Spec 2.5).
- No switch from fixed Dashboard size to percentage-of-screen formula.
- No replacement of the kanji 力 brand mark.
