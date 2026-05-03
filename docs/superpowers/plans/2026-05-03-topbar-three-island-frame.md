# Topbar Three-Island Frame Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Ryoku/iNiR topbar render as three rounded islands with transparent gaps while keeping left/right edge interactions and preserving sidebar-owned controls.

**Architecture:** Add static coverage to the existing Ryoku shell branding test, then update the Ryoku config overlay and branding patch script. The config overlay disables the continuous topbar background and noisy modules; the branding script applies an idempotent QML patch to source and runtime `BarContent.qml` using `readonly property bool ryokuThreeIslandFrame: true` as the sentinel.

**Tech Stack:** Bash 5, Perl one-shot QML patching, JSON config overlay, Quickshell QML, existing Ryoku static shell-branding tests.

---

## File Structure

- Modify: `tests/ryoku-shell-branding.sh`
  - Adds static regression coverage for the topbar frame contract.
  - Keeps this coverage with the existing shell overlay tests rather than creating a new test file.
- Modify: `default/ryoku-shell/config-overrides.json`
  - Owns fresh-install and branding-merge defaults for the clean topbar.
  - Sets `bar.showBackground=false`, `bar.borderless=false`, hides noisy topbar modules, and keeps the requested modules visible.
- Modify: `install/config/ryoku-shell-branding.sh`
  - Owns runtime/source QML patching.
  - Adds `apply_topbar_three_island_frame_to_file()` and `apply_topbar_three_island_frame()`.
  - Patches only `modules/bar/BarContent.qml`, not `modules/screenCorners/ScreenCorners.qml`.

No QML files are added to this repository. The live source and runtime QML trees are patched through the existing branding overlay.

---

### Task 1: Add Static Contract Tests

**Files:**
- Modify: `tests/ryoku-shell-branding.sh`
- Test: `tests/ryoku-shell-branding.sh`

- [ ] **Step 1: Add topbar frame assertions**

In `tests/ryoku-shell-branding.sh`, add this function after `assert_shell_overlay()`:

```bash
assert_topbar_frame_overlay() {
  assert_contains "install/config/ryoku-shell-branding.sh" 'apply_topbar_three_island_frame_to_file\(\)' \
    "Ryoku shell overlay should define the topbar three-island patch"
  assert_contains "install/config/ryoku-shell-branding.sh" 'readonly property bool ryokuThreeIslandFrame: true' \
    "Topbar frame patch should use an explicit idempotency marker"
  assert_contains "install/config/ryoku-shell-branding.sh" 'apply_topbar_three_island_frame_to_file "\$SHELL_PATH/modules/bar/BarContent.qml"' \
    "Topbar frame patch should apply to the source BarContent.qml"
  assert_contains "install/config/ryoku-shell-branding.sh" 'apply_topbar_three_island_frame_to_file "\$RUNTIME_SHELL_PATH/modules/bar/BarContent.qml"' \
    "Topbar frame patch should apply to the runtime BarContent.qml"
  assert_not_contains "install/config/ryoku-shell-branding.sh" 'apply_topbar_three_island_frame_to_file "\$SHELL_PATH/modules/screenCorners/ScreenCorners.qml"' \
    "Topbar frame patch should not patch screen corner behavior"
  assert_contains "install/config/ryoku-shell-branding.sh" 'id: leftIslandBackground' \
    "Topbar frame patch should add a left island background"
  assert_contains "install/config/ryoku-shell-branding.sh" 'id: rightIslandBackground' \
    "Topbar frame patch should add a right island background"
  assert_contains "install/config/ryoku-shell-branding.sh" 'opacity: root.ryokuThreeIslandFrame \? 0 : 1' \
    "Topbar frame patch should keep center spacers laid out but visually hidden"
  assert_contains "install/config/ryoku-shell-branding.sh" 'TimerIndicator' \
    "Topbar frame patch should still target the timer indicator block"
  assert_contains "install/config/ryoku-shell-branding.sh" 'ShellUpdateIndicator' \
    "Topbar frame patch should still target the shell update indicator block"
  assert_contains "install/config/ryoku-shell-branding.sh" 'visible: !root\.ryokuThreeIslandFrame' \
    "Topbar frame patch should hide the timer indicator from the bar"
  assert_contains "default/ryoku-shell/config-overrides.json" '"showBackground": false' \
    "Ryoku shell config overlay should hide the continuous bar background"
  assert_contains "default/ryoku-shell/config-overrides.json" '"borderless": false' \
    "Ryoku shell config overlay should allow BarGroup island backgrounds"
  assert_contains "default/ryoku-shell/config-overrides.json" '"resources": false' \
    "Ryoku shell config overlay should hide resource/system monitor modules"
  assert_contains "default/ryoku-shell/config-overrides.json" '"media": false' \
    "Ryoku shell config overlay should hide the media/player module"
  assert_contains "default/ryoku-shell/config-overrides.json" '"utilButtons": false' \
    "Ryoku shell config overlay should hide quick action buttons"
  assert_contains "default/ryoku-shell/config-overrides.json" '"clock": false' \
    "Ryoku shell config overlay should hide time and date"
  assert_contains "default/ryoku-shell/config-overrides.json" '"battery": false' \
    "Ryoku shell config overlay should hide battery from the topbar"
  assert_contains "default/ryoku-shell/config-overrides.json" '"sysTray": false' \
    "Ryoku shell config overlay should hide the tray from the topbar"
  assert_contains "default/ryoku-shell/config-overrides.json" '"activeWindow": true' \
    "Ryoku shell config overlay should keep active window text"
  assert_contains "default/ryoku-shell/config-overrides.json" '"workspaces": true' \
    "Ryoku shell config overlay should keep workspace numbers"
  assert_contains "default/ryoku-shell/config-overrides.json" '"rightSidebarButton": true' \
    "Ryoku shell config overlay should keep the combined right status button"
  assert_contains "default/ryoku-shell/config-overrides.json" '"weather": true' \
    "Ryoku shell config overlay should keep weather in the right island"
}
```

- [ ] **Step 2: Call the new assertion function**

Near the bottom of `tests/ryoku-shell-branding.sh`, change:

```bash
assert_shell_overlay
assert_install_wiring
```

to:

```bash
assert_shell_overlay
assert_topbar_frame_overlay
assert_install_wiring
```

- [ ] **Step 3: Run the test and verify it fails**

Run:

```bash
tests/ryoku-shell-branding.sh
```

Expected result:

```text
FAIL: Ryoku shell overlay should define the topbar three-island patch
```

- [ ] **Step 4: Commit the failing test**

Run:

```bash
git add tests/ryoku-shell-branding.sh
git commit -m "test: specify three-island topbar frame"
```

Expected result: commit succeeds with only `tests/ryoku-shell-branding.sh` staged.

---

### Task 2: Add Topbar Defaults To The Config Overlay

**Files:**
- Modify: `default/ryoku-shell/config-overrides.json`
- Test: `tests/ryoku-shell-branding.sh`

- [ ] **Step 1: Add a `bar` override block**

In `default/ryoku-shell/config-overrides.json`, add this block after the existing `"dock"` block and before `"enabledPanels"`:

```json
  "bar": {
    "borderless": false,
    "showBackground": false,
    "modules": {
      "activeWindow": true,
      "battery": false,
      "clock": false,
      "leftSidebarButton": true,
      "media": false,
      "resources": false,
      "rightSidebarButton": true,
      "sysTray": false,
      "utilButtons": false,
      "weather": true,
      "workspaces": true
    },
    "weather": {
      "enable": true
    }
  },
```

The surrounding JSON should look like this:

```json
  "dock": {
    "position": "bottom",
    "hoverToReveal": true,
    "hoverRegionHeight": 20,
    "showOnDesktop": false,
    "pinnedOnStartup": false
  },
  "bar": {
    "borderless": false,
    "showBackground": false,
    "modules": {
      "activeWindow": true,
      "battery": false,
      "clock": false,
      "leftSidebarButton": true,
      "media": false,
      "resources": false,
      "rightSidebarButton": true,
      "sysTray": false,
      "utilButtons": false,
      "weather": true,
      "workspaces": true
    },
    "weather": {
      "enable": true
    }
  },
  "enabledPanels": [
```

- [ ] **Step 2: Validate JSON**

Run:

```bash
jq empty default/ryoku-shell/config-overrides.json
```

Expected result: command exits 0 with no output.

- [ ] **Step 3: Run the static test and verify partial progress**

Run:

```bash
tests/ryoku-shell-branding.sh
```

Expected result: the config assertions now pass, but the test still fails at:

```text
FAIL: Ryoku shell overlay should define the topbar three-island patch
```

- [ ] **Step 4: Commit the config defaults**

Run:

```bash
git add default/ryoku-shell/config-overrides.json
git commit -m "config: default to three-island topbar"
```

Expected result: commit succeeds with only `default/ryoku-shell/config-overrides.json` staged.

---

### Task 3: Add The Idempotent BarContent Patch

**Files:**
- Modify: `install/config/ryoku-shell-branding.sh`
- Test: `tests/ryoku-shell-branding.sh`

- [ ] **Step 1: Add the topbar patch functions**

In `install/config/ryoku-shell-branding.sh`, add these functions after `apply_sidebar_right_keep_mapped_workaround()` and before `apply_installed_labels()`:

```bash
apply_topbar_three_island_frame_to_file() {
  local file="$1"

  [[ -f $file ]] || return 0
  grep -q 'readonly property bool ryokuThreeIslandFrame: true' "$file" && return 0
  grep -q 'property alias backgroundItem: barBackground' "$file" || return 0
  grep -q 'id: leftSectionRowLayout' "$file" || return 0
  grep -q 'id: rightSectionRowLayout' "$file" || return 0
  grep -q 'id: leftCenterGroup' "$file" || return 0
  grep -q 'id: rightCenterGroupContent' "$file" || return 0

  perl -0pi -e '
    s/(    property alias backgroundItem: barBackground\n)/$1    readonly property bool ryokuThreeIslandFrame: true\n    readonly property int ryokuIslandVerticalMargin: 4\n    readonly property int ryokuIslandHorizontalPadding: 10\n/s;

    s/visible: \(Config\.options\?\.bar\?\.showBackground \?\? true\) && !gameModeMinimal/visible: (Config.options?.bar?.showBackground ?? true) && !gameModeMinimal && !root.ryokuThreeIslandFrame/;

    s/(        RowLayout \{\n            id: leftSectionRowLayout)/        Rectangle {\n            id: leftIslandBackground\n            anchors {\n                left: parent.left\n                leftMargin: Appearance.rounding.screenRounding\n                verticalCenter: parent.verticalCenter\n            }\n            width: Math.min(leftSectionRowLayout.implicitWidth + root.ryokuIslandHorizontalPadding * 2,\n                Math.max(260, (root.screen?.width ?? 1920) * 0.32))\n            height: Appearance.sizes.baseBarHeight - root.ryokuIslandVerticalMargin * 2\n            radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall\n                : Appearance.inirEverywhere ? Appearance.inir.roundingNormal\n                : Appearance.rounding.small\n            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard\n                : Appearance.inirEverywhere ? Appearance.inir.colLayer1\n                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface\n                : Appearance.colors.colLayer1\n            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth\n                : Appearance.inirEverywhere ? 1 : 0\n            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder\n                : Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border\n            visible: root.ryokuThreeIslandFrame\n            z: -1\n        }\n\n$1/s;

    s/(                Layout\.fillWidth: )!root\.taskbarEnabled/$1!root.ryokuThreeIslandFrame \&\& !root.taskbarEnabled/;
    s/(                Layout\.fillHeight: true\n            \})/                Layout.preferredWidth: root.ryokuThreeIslandFrame ? Math.min(360, Math.max(180, (root.screen?.width ?? 1920) * 0.22)) : -1\n$1/s;

    s/(                    Layout\.fillWidth: )true/$1!root.ryokuThreeIslandFrame/;
    s/(                    Layout\.fillHeight: true\n                \})/                    Layout.preferredWidth: root.ryokuThreeIslandFrame ? Math.min(360, Math.max(180, (root.screen?.width ?? 1920) * 0.22)) : -1\n$1/s;

    s/(        BarGroup \{\n            id: leftCenterGroup\n)/$1            opacity: root.ryokuThreeIslandFrame ? 0 : 1\n/s;
    s/(            Loader \{\n                active: )Config\.options\?\.bar\?\.modules\?\.resources \?\? true/$1!root.ryokuThreeIslandFrame \&\& (Config.options?.bar?.modules?.resources ?? true)/;
    s/(            Loader \{\n                active: )\(Config\.options\?\.bar\?\.modules\?\.media \?\? true\) && root\.useShortenedForm < 2/$1!root.ryokuThreeIslandFrame \&\& (Config.options?.bar?.modules?.media ?? true) \&\& root.useShortenedForm < 2/;

    s/(            BarGroup \{\n                id: rightCenterGroupContent\n)/$1                opacity: root.ryokuThreeIslandFrame ? 0 : 1\n/s;
    s/visible: Config\.options\?\.bar\?\.modules\?\.clock \?\? true/visible: !root.ryokuThreeIslandFrame \&\& (Config.options?.bar?.modules?.clock ?? true)/;
    s/visible: \(Config\.options\?\.bar\?\.modules\?\.utilButtons \?\? true\) && \(\(Config\.options\?\.bar\?\.verbose \?\? true\) && root\.useShortenedForm === 0\)/visible: !root.ryokuThreeIslandFrame \&\& (Config.options?.bar?.modules?.utilButtons ?? true) \&\& ((Config.options?.bar?.verbose ?? true) \&\& root.useShortenedForm === 0)/;
    s/visible: \(Config\.options\?\.bar\?\.modules\?\.battery \?\? true\) && \(root\.useShortenedForm < 2 && Battery\.available\)/visible: !root.ryokuThreeIslandFrame \&\& (Config.options?.bar?.modules?.battery ?? true) \&\& (root.useShortenedForm < 2 \&\& Battery.available)/;

    s/(        RowLayout \{\n            id: rightSectionRowLayout)/        Rectangle {\n            id: rightIslandBackground\n            anchors {\n                right: parent.right\n                rightMargin: Appearance.rounding.screenRounding\n                verticalCenter: parent.verticalCenter\n            }\n            width: rightSectionRowLayout.implicitWidth + root.ryokuIslandHorizontalPadding * 2\n            height: Appearance.sizes.baseBarHeight - root.ryokuIslandVerticalMargin * 2\n            radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall\n                : Appearance.inirEverywhere ? Appearance.inir.roundingNormal\n                : Appearance.rounding.small\n            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard\n                : Appearance.inirEverywhere ? Appearance.inir.colLayer1\n                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface\n                : Appearance.colors.colLayer1\n            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth\n                : Appearance.inirEverywhere ? 1 : 0\n            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder\n                : Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border\n            visible: root.ryokuThreeIslandFrame\n            z: -1\n        }\n\n$1/s;

    s/visible: \(Config\.options\?\.bar\?\.modules\?\.sysTray \?\? true\) && root\.useShortenedForm === 0/visible: !root.ryokuThreeIslandFrame \&\& (Config.options?.bar?.modules?.sysTray ?? true) \&\& root.useShortenedForm === 0/;
    s/(            TimerIndicator \{\n)/$1                visible: !root.ryokuThreeIslandFrame\n/s;
    s/(            ShellUpdateIndicator \{\n)/$1                visible: !root.ryokuThreeIslandFrame\n/s;
    s/(            Item \{\n                Layout\.fillWidth: )true/$1!root.ryokuThreeIslandFrame/;
    s/(                Layout\.fillHeight: )true/$1!root.ryokuThreeIslandFrame/;
  ' "$file"
}

apply_topbar_three_island_frame() {
  apply_topbar_three_island_frame_to_file "$SHELL_PATH/modules/bar/BarContent.qml"
  apply_topbar_three_island_frame_to_file "$RUNTIME_SHELL_PATH/modules/bar/BarContent.qml"
}
```

- [ ] **Step 2: Wire the patch into `main()`**

In `main()`, change:

```bash
  apply_wallpaper_resolution_patch
  apply_sidebar_right_keep_mapped_workaround
  apply_replacements_to_tree "$SHELL_PATH"
```

to:

```bash
  apply_wallpaper_resolution_patch
  apply_sidebar_right_keep_mapped_workaround
  apply_topbar_three_island_frame
  apply_replacements_to_tree "$SHELL_PATH"
```

- [ ] **Step 3: Run the static test**

Run:

```bash
tests/ryoku-shell-branding.sh
```

Expected result:

```text
PASS: ryoku shell branding
```

- [ ] **Step 4: Commit the branding patch**

Run:

```bash
git add install/config/ryoku-shell-branding.sh
git commit -m "feat: patch topbar three-island frame"
```

Expected result: commit succeeds with only `install/config/ryoku-shell-branding.sh` staged.

---

### Task 4: Apply And Verify On The Live Shell

**Files:**
- Runtime source affected by script: `$HOME/.local/share/inir/modules/bar/BarContent.qml`
- Runtime config affected by script: `$HOME/.config/quickshell/inir/modules/bar/BarContent.qml`
- Runtime user config affected by script: `$HOME/.config/inir/config.json`
- Test: `tests/ryoku-shell-branding.sh`

- [ ] **Step 1: Run the full static test again**

Run:

```bash
tests/ryoku-shell-branding.sh
```

Expected result:

```text
PASS: ryoku shell branding
```

- [ ] **Step 2: Apply the branding overlay to source and runtime shell trees**

Run:

```bash
env RYOKU_PATH="$PWD" /usr/bin/bash "$PWD/install/config/ryoku-shell-branding.sh"
```

Expected result:

```text
Ryoku shell branding: applied
```

- [ ] **Step 3: Verify the QML patch landed in both shell trees**

Run:

```bash
rg -n 'ryokuThreeIslandFrame|leftIslandBackground|rightIslandBackground|TimerIndicator|ShellUpdateIndicator' \
  "$HOME/.local/share/inir/modules/bar/BarContent.qml" \
  "$HOME/.config/quickshell/inir/modules/bar/BarContent.qml"
```

Expected result:

```text
$HOME/.local/share/inir/modules/bar/BarContent.qml:...:    readonly property bool ryokuThreeIslandFrame: true
$HOME/.local/share/inir/modules/bar/BarContent.qml:...:            id: leftIslandBackground
$HOME/.local/share/inir/modules/bar/BarContent.qml:...:            id: rightIslandBackground
$HOME/.config/quickshell/inir/modules/bar/BarContent.qml:...:    readonly property bool ryokuThreeIslandFrame: true
$HOME/.config/quickshell/inir/modules/bar/BarContent.qml:...:            id: leftIslandBackground
$HOME/.config/quickshell/inir/modules/bar/BarContent.qml:...:            id: rightIslandBackground
```

- [ ] **Step 4: Verify the merged user config contains the topbar defaults**

Run:

```bash
jq '.bar.showBackground, .bar.borderless, .bar.modules.resources, .bar.modules.media, .bar.modules.utilButtons, .bar.modules.clock, .bar.modules.battery, .bar.modules.sysTray, .bar.modules.workspaces, .bar.modules.rightSidebarButton, .bar.modules.weather' \
  "$HOME/.config/inir/config.json"
```

Expected result:

```text
false
false
false
false
false
false
false
false
true
true
true
```

- [ ] **Step 5: Restart the live shell**

Run:

```bash
env RYOKU_PATH="$HOME/.local/share/ryoku" /usr/bin/bash -lc 'export PATH="$RYOKU_PATH/bin:$PATH"; source "$RYOKU_PATH/lib/runtime-env.sh"; ryoku-restart-ui --quiet'
```

Expected result: command exits 0. If the shell reports QML parse errors, inspect the service logs before continuing.

- [ ] **Step 6: Check service health**

Run:

```bash
systemctl --user status inir.service --no-pager
```

Expected result includes:

```text
Active: active (running)
```

- [ ] **Step 7: Inspect recent shell logs for QML errors**

Run:

```bash
journalctl --user -u inir.service -n 160 --no-pager
```

Expected result: no new `BarContent.qml` parser errors, binding-loop floods, or fatal QML load errors after the restart.

- [ ] **Step 8: Manual visual and interaction check**

Inspect the topbar and verify:

- Left, center, and right rounded islands are visible.
- Transparent gaps appear between islands.
- The left island shows the Ryoku logo and active window title/status, or the taskbar if taskbar mode is enabled.
- The center island shows workspace numbers only.
- The right island shows the combined right status button plus weather.
- Time/date, resources/system monitor, media/player, util buttons, battery, tray, timer, and shell update indicators are not visible on the topbar.
- Hovering or pressing the configured top-left hot corner still toggles the left sidebar.
- Scrolling the left bar side still changes brightness.
- Scrolling the right bar side still changes volume.
- Left/right bar-side right-click context behavior still works.

- [ ] **Step 9: Commit live-verification follow-up only if code changed**

If no repository files changed during manual verification, do not commit.

If you had to refine repo code after live verification, run:

```bash
tests/ryoku-shell-branding.sh
git status --short
git add tests/ryoku-shell-branding.sh default/ryoku-shell/config-overrides.json install/config/ryoku-shell-branding.sh
git commit -m "fix: verify topbar three-island frame"
```

Expected result: commit includes only files owned by this plan.

---

## Completion Checklist

- `tests/ryoku-shell-branding.sh` passes.
- `default/ryoku-shell/config-overrides.json` is valid JSON.
- `install/config/ryoku-shell-branding.sh` patches only `BarContent.qml` for the frame.
- `ScreenCorners.qml` remains unpatched by the topbar frame function.
- Runtime source and config `BarContent.qml` contain `ryokuThreeIslandFrame`.
- The live shell is running after restart.
- The topbar visually has three islands with transparent gaps.
- The requested retained features and interactions still work.
