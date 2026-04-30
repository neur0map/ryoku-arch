# Top Right Control Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current top-right `SettingsMenuPopup` shortcut grid with a native Ryoku control center for `SUPER+ALT+SPACE`, including old-menu sections that belong there and excluding surfaces already owned by the launcher, dashboard, toolbox, telemetry rail, and system menu.

**Architecture:** Keep the popup topbar-attached and driven by Quickshell state. Add explicit page routing to `Popups.qml`/`shell.qml`/`ryoku-ipc`, then rebuild `SettingsMenuPopup.qml` as a multi-page control surface with native quick toggles and command-backed leaf actions. Update Hyprland bindings so old direct `ryoku-menu` submenu keys open the matching native control center route.

**Tech Stack:** Quickshell QML, QtQuick, Quickshell.Io `Process`, Hyprland bindings, Bash 5, static shell regression tests.

---

## Common-Sense Check Results

These findings are already fixed in `docs/superpowers/specs/2026-04-30-top-right-control-center-design.md` and must drive implementation:

- Old `Apps` maps to the active `SUPER+SPACE` app launcher. Do not add Apps to the control center.
- Old direct submenu bindings for Toggle, Hardware, and Share must stop calling `ryoku-menu` and instead open native control center routes.
- Dotfiles access must survive under `Setup -> Config -> Dotfiles Hub`.
- The left system menu keeps its one-shot `Update`; the control center uses `Manage -> Maintain` for detailed update/maintenance workflows.
- Setup entries for Audio, Wi-Fi, and Bluetooth are detailed external launchers, while the home quick controls are inline toggles/status tiles.

## File Structure

- Modify `bin/ryoku-ipc`: add `shell settings-menu home|share|hardware` and printable command targets for direct routes.
- Modify `default/hypr/bindings/utilities.conf`: replace old `ryoku-menu toggle`, `ryoku-menu hardware`, and `ryoku-menu share` bindings with native control-center routes.
- Modify `config/quickshell/ryoku/shell.qml`: add IPC-callable `openSettingsMenuHome`, `openSettingsMenuShare`, and `openSettingsMenuHardware` route functions, and make `toggleSettingsMenu()` reset to home when opening.
- Modify `config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml`: add requested settings page/subpage state.
- Replace most of `config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`: keep the topbar-attached window pattern, but add native pages, quick controls, page routing, command execution, and visual polish.
- Modify `tests/ryoku-ipc.sh`: cover new IPC route commands and argument validation.
- Modify `tests/quickshell-topbar-settings-menus.sh`: cover routing, ownership boundaries, quick controls, native sections, Dotfiles preservation, and old binding removal.
- After verification, copy changed files to `/home/omi/.local/share/ryoku` and `/home/omi/.config/quickshell/ryoku`, then restart Quickshell.

## Task 1: Add Routed IPC And Binding Coverage

**Files:**
- Modify: `tests/ryoku-ipc.sh`
- Modify: `tests/quickshell-topbar-settings-menus.sh`
- Modify: `bin/ryoku-ipc`
- Modify: `config/quickshell/ryoku/shell.qml`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml`
- Modify: `default/hypr/bindings/utilities.conf`

- [ ] **Step 1: Add failing IPC tests**

In `tests/ryoku-ipc.sh`, add these assertions after the existing settings-menu help assertion:

```bash
"$ipc" --help | grep -q "ryoku-ipc shell settings-menu home" \
  || fail "help should document settings-menu home route"
"$ipc" --help | grep -q "ryoku-ipc shell settings-menu share" \
  || fail "help should document settings-menu share route"
"$ipc" --help | grep -q "ryoku-ipc shell settings-menu hardware" \
  || fail "help should document settings-menu hardware route"
```

Add these assertions after the existing `shell command settings-menu` check:

```bash
RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command settings-menu-home \
  | grep -q 'qs -c ryoku ipc call popups openSettingsMenuHome' \
  || fail "shell command settings-menu-home should print the home route IPC command"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command settings-menu-share \
  | grep -q 'qs -c ryoku ipc call popups openSettingsMenuShare' \
  || fail "shell command settings-menu-share should print the share route IPC command"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command settings-menu-hardware \
  | grep -q 'qs -c ryoku ipc call popups openSettingsMenuHardware' \
  || fail "shell command settings-menu-hardware should print the hardware route IPC command"
```

Add these trailing-argument checks after the current `shell command settings-menu` trailing-argument assertion:

```bash
rejects_trailing_args "shell command settings-menu-home" shell command settings-menu-home extra
rejects_trailing_args "shell command settings-menu-share" shell command settings-menu-share extra
rejects_trailing_args "shell command settings-menu-hardware" shell command settings-menu-hardware extra
rejects_trailing_args "shell settings-menu home" shell settings-menu home extra
rejects_trailing_args "shell settings-menu share" shell settings-menu share extra
rejects_trailing_args "shell settings-menu hardware" shell settings-menu hardware extra
```

- [ ] **Step 2: Add failing binding and shell-route tests**

In `tests/quickshell-topbar-settings-menus.sh`, add these assertions after the `toggleSettingsMenu` shell IPC assertion:

```bash
grep -q 'function openSettingsMenuHome(): void' "$shell" \
  || fail "shell IPC should expose the settings home route"
grep -q 'function openSettingsMenuShare(): void' "$shell" \
  || fail "shell IPC should expose the settings share route"
grep -q 'function openSettingsMenuHardware(): void' "$shell" \
  || fail "shell IPC should expose the settings hardware route"
grep -q 'BS.Popups.requestSettingsMenuPage("home", "")' "$shell" \
  || fail "settings home route should request the home page"
grep -q 'BS.Popups.requestSettingsMenuPage("share", "")' "$shell" \
  || fail "settings share route should request the share page"
grep -q 'BS.Popups.requestSettingsMenuPage("setup", "hardware")' "$shell" \
  || fail "settings hardware route should request the setup hardware page"
```

Add these assertions after the existing `settingsMenuOpen` state check:

```bash
grep -q 'property string settingsMenuRequestedPage' "$popups" \
  || fail "Popups should track the requested settings page"
grep -q 'property string settingsMenuRequestedSubpage' "$popups" \
  || fail "Popups should track the requested settings subpage"
grep -q 'function requestSettingsMenuPage(page, subpage)' "$popups" \
  || fail "Popups should expose settings page routing"
```

Replace the old binding assertions for `SUPER CTRL, O`, `SUPER CTRL, H`, and `SUPER CTRL, S` with:

```bash
grep -q 'bindd = SUPER CTRL, O, Toggle menu, exec, ryoku-ipc shell settings-menu home' "$bindings" \
  || fail "SUPER+CTRL+O should open the native control center home route"
grep -q 'bindd = SUPER CTRL, H, Hardware menu, exec, ryoku-ipc shell settings-menu hardware' "$bindings" \
  || fail "SUPER+CTRL+H should open the native hardware route"
grep -q 'bindd = SUPER CTRL, S, Share, exec, ryoku-ipc shell settings-menu share' "$bindings" \
  || fail "SUPER+CTRL+S should open the native share route"
! grep -q 'ryoku-menu toggle' "$bindings" \
  || fail "Toggle binding should not launch the old ryoku-menu submenu"
! grep -q 'ryoku-menu hardware' "$bindings" \
  || fail "Hardware binding should not launch the old ryoku-menu submenu"
! grep -q 'ryoku-menu share' "$bindings" \
  || fail "Share binding should not launch the old ryoku-menu submenu"
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
tests/ryoku-ipc.sh
tests/quickshell-topbar-settings-menus.sh
```

Expected: both tests fail on missing routed settings-menu commands, missing routed QML IPC, and old bindings.

- [ ] **Step 4: Implement `ryoku-ipc` settings-menu routes**

In `bin/ryoku-ipc`, add these usage lines:

```bash
  ryoku-ipc shell command settings-menu-home
  ryoku-ipc shell command settings-menu-share
  ryoku-ipc shell command settings-menu-hardware
  ryoku-ipc shell settings-menu home
  ryoku-ipc shell settings-menu share
  ryoku-ipc shell settings-menu hardware
```

In `shell_command()`, update the argument-count error string to include:

```bash
settings-menu-home|settings-menu-share|settings-menu-hardware
```

Add these cases after `settings-menu)`:

```bash
    settings-menu-home)
      printf '%s\n' "qs -c ryoku ipc call popups openSettingsMenuHome"
      ;;
    settings-menu-share)
      printf '%s\n' "qs -c ryoku ipc call popups openSettingsMenuShare"
      ;;
    settings-menu-hardware)
      printf '%s\n' "qs -c ryoku ipc call popups openSettingsMenuHardware"
      ;;
```

Add this function after `shell_toggle()`:

```bash
shell_settings_menu() {
  local route="${1:-}"

  if (( $# != 1 )); then
    echo "ryoku-ipc: expected shell settings-menu home|share|hardware" >&2
    return 2
  fi

  case "$route" in
    home|quick|quick-controls)
      exec qs -c ryoku ipc call popups openSettingsMenuHome
      ;;
    share)
      exec qs -c ryoku ipc call popups openSettingsMenuShare
      ;;
    hardware)
      exec qs -c ryoku ipc call popups openSettingsMenuHardware
      ;;
    *)
      echo "ryoku-ipc: unknown settings-menu route: $route" >&2
      return 2
      ;;
  esac
}
```

In `main()`, add this shell action case before `preview)`:

```bash
        settings-menu)
          shift
          shell_settings_menu "$@"
          ;;
```

- [ ] **Step 5: Implement popup route state**

In `config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml`, add these properties next to `settingsMenuOpen`:

```qml
    property string settingsMenuRequestedPage:    "home"
    property string settingsMenuRequestedSubpage: ""
```

Add this function near the other request helpers:

```qml
    function requestSettingsMenuPage(page, subpage) {
        settingsMenuRequestedPage = page && page !== "" ? page : "home"
        settingsMenuRequestedSubpage = subpage && subpage !== "" ? subpage : ""
    }
```

Do not reset these properties in `closeAll()`. The next open should use the last requested route unless the caller sets a new route.

- [ ] **Step 6: Implement shell IPC route entry point**

In `config/quickshell/ryoku/shell.qml`, update `toggleSettingsMenu()` to reset the requested page before opening:

```qml
        function toggleSettingsMenu(): void {
            const opening = !BS.Popups.settingsMenuOpen
            BS.Popups.closeAll()
            if (opening) {
                BS.Popups.requestSettingsMenuPage("home", "")
            }
            BS.Popups.settingsMenuOpen = opening
        }
```

Add these IPC-callable wrappers after `toggleSettingsMenu()`. The no-argument wrappers are used because Quickshell IPC call dispatch does not reliably call parameterized QML helper functions:

```qml
        function openSettingsMenuHome(): void {
            BS.Popups.closeAll()
            BS.Popups.requestSettingsMenuPage("home", "")
            BS.Popups.settingsMenuOpen = true
        }

        function openSettingsMenuShare(): void {
            BS.Popups.closeAll()
            BS.Popups.requestSettingsMenuPage("share", "")
            BS.Popups.settingsMenuOpen = true
        }

        function openSettingsMenuHardware(): void {
            BS.Popups.closeAll()
            BS.Popups.requestSettingsMenuPage("setup", "hardware")
            BS.Popups.settingsMenuOpen = true
        }
```

- [ ] **Step 7: Update direct bindings**

In `default/hypr/bindings/utilities.conf`, replace:

```text
bindd = SUPER CTRL, O, Toggle menu, exec, ryoku-menu toggle
bindd = SUPER CTRL, H, Hardware menu, exec, ryoku-menu hardware
bindd = SUPER CTRL, S, Share, exec, ryoku-menu share
```

with:

```text
bindd = SUPER CTRL, O, Toggle menu, exec, ryoku-ipc shell settings-menu home
bindd = SUPER CTRL, H, Hardware menu, exec, ryoku-ipc shell settings-menu hardware
bindd = SUPER CTRL, S, Share, exec, ryoku-ipc shell settings-menu share
```

- [ ] **Step 8: Run tests and commit**

Run:

```bash
tests/ryoku-ipc.sh
tests/quickshell-topbar-settings-menus.sh
```

Expected: route, IPC, and binding assertions pass. Existing settings-popup content assertions may still fail until Task 2 if they were updated beyond routing in Step 2; do not leave a mixed red state at commit time.

Commit only files touched for this task:

```bash
git add bin/ryoku-ipc config/quickshell/ryoku/shell.qml config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml default/hypr/bindings/utilities.conf tests/ryoku-ipc.sh tests/quickshell-topbar-settings-menus.sh
git commit -m "feat: route settings menu pages through ipc"
```

## Task 2: Rebuild The Popup Shell And Home View

**Files:**
- Modify: `tests/quickshell-topbar-settings-menus.sh`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`

- [ ] **Step 1: Add failing control-center structure tests**

In `tests/quickshell-topbar-settings-menus.sh`, replace the current `SettingsMenuPopup` assertions from:

```bash
grep -q 'ListModel {' "$settings_popup" \
```

through:

```bash
! grep -q 'modelData && modelData.label' "$settings_popup" \
```

with this block:

```bash
grep -q 'Binding { target: Popups; property: "settingsMenuVisible"' "$settings_popup" \
  || fail "SettingsMenuPopup should expose visual presence"
grep -Eq 'readonly property int menuWidth:[[:space:]]+456' "$settings_popup" \
  || fail "SettingsMenuPopup should use the larger control-center width"
grep -Eq 'readonly property int menuHeight:[[:space:]]+520' "$settings_popup" \
  || fail "SettingsMenuPopup should use the larger control-center height"
grep -q 'anchors.right: parent.right' "$settings_popup" \
  || fail "SettingsMenuPopup should open from the right topbar pill"
grep -q 'attachedEdge: "top"' "$settings_popup" \
  || fail "SettingsMenuPopup should attach to the topbar"
grep -q 'property string currentPage: "home"' "$settings_popup" \
  || fail "SettingsMenuPopup should track the current page"
grep -q 'property string currentSubpage: ""' "$settings_popup" \
  || fail "SettingsMenuPopup should track the current subpage"
grep -q 'function openPage(page, subpage)' "$settings_popup" \
  || fail "SettingsMenuPopup should expose internal page navigation"
grep -q 'function openRequestedRoute()' "$settings_popup" \
  || fail "SettingsMenuPopup should consume requested routes from Popups"
grep -q 'id: quickControlsModel' "$settings_popup" \
  || fail "SettingsMenuPopup should define quick controls"
grep -q 'id: nativeSectionsModel' "$settings_popup" \
  || fail "SettingsMenuPopup should define native sections"
grep -q 'id: pageStack' "$settings_popup" \
  || fail "SettingsMenuPopup should render a page stack"
grep -q 'text: "Control center"' "$settings_popup" \
  || fail "SettingsMenuPopup should use a control-center header"

for label in "Wi-Fi" "Bluetooth" "Airplane Mode" "Hotspot" "Night Light" "Focus Mode" "Do Not Disturb" "Filter"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose quick control $label"
done

for label in "Learn" "Share" "Style" "Setup" "Manage" "About"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "SettingsMenuPopup should expose native section $label"
done

grep -q 'label: "Maintain"' "$settings_popup" \
  || fail "Manage should use Maintain instead of a top-level Update tab"
grep -q 'label: "Dotfiles Hub"' "$settings_popup" \
  || fail "Setup Config should preserve Dotfiles Hub access"

! grep -q 'label: "Apps"' "$settings_popup" \
  || fail "SettingsMenuPopup should not expose an Apps page"
! grep -q 'label: "Activity"' "$settings_popup" \
  || fail "SettingsMenuPopup should not duplicate dashboard activity"
! grep -q 'label: "Caffeine"' "$settings_popup" \
  || fail "SettingsMenuPopup should not duplicate toolbox Caffeine"
! grep -q 'label: "Screen Capture"' "$settings_popup" \
  || fail "SettingsMenuPopup should not duplicate toolbox capture tools"
! grep -q 'label: "Volume"' "$settings_popup" \
  || fail "SettingsMenuPopup should not duplicate dashboard volume"
! grep -q 'label: "Brightness"' "$settings_popup" \
  || fail "SettingsMenuPopup should not duplicate dashboard brightness"
! grep -q 'label: "Shutdown"' "$settings_popup" \
  || fail "SettingsMenuPopup should not duplicate system power actions"
! grep -q 'label: "Restart"' "$settings_popup" \
  || fail "SettingsMenuPopup should not duplicate system power actions"
! grep -q 'label: "Log Out"' "$settings_popup" \
  || fail "SettingsMenuPopup should not duplicate system session actions"
! grep -q 'label: "Suspend";.*action: "suspend"' "$settings_popup" \
  || fail "SettingsMenuPopup should not expose immediate suspend"
! grep -q 'modelData && modelData.label' "$settings_popup" \
  || fail "SettingsMenuPopup should not render blank modelData fallbacks"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
tests/quickshell-topbar-settings-menus.sh
```

Expected: FAIL on missing larger geometry, current page state, quick controls, native sections, Maintain, and Dotfiles Hub.

- [ ] **Step 3: Replace popup structure**

In `config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`, keep the existing imports and `PanelWindow` wrapper pattern. Replace the old small `settingsActions` model and grid with this structure:

```qml
  readonly property int menuWidth: 456
  readonly property int menuHeight: 520
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight + root.menuHeight
  readonly property int initialCardHeight: Theme.notchHeight

  property bool windowVisible: false
  property real openProgress: Popups.settingsMenuOpen ? 1 : 0
  property string currentPage: "home"
  property string currentSubpage: ""
  property string pageTitle: "Ryoku"
  property string pageKicker: "Control center"
```

Add route handling before the timers:

```qml
  function openRequestedRoute() {
    root.openPage(Popups.settingsMenuRequestedPage, Popups.settingsMenuRequestedSubpage)
  }

  function openPage(page, subpage) {
    root.currentPage = page && page !== "" ? page : "home"
    root.currentSubpage = subpage && subpage !== "" ? subpage : ""
    if (root.currentPage === "home") {
      root.pageTitle = "Ryoku"
      root.pageKicker = "Control center"
    } else if (root.currentSubpage !== "") {
      root.pageTitle = root.pageLabel(root.currentSubpage)
      root.pageKicker = root.pageLabel(root.currentPage)
    } else {
      root.pageTitle = root.pageLabel(root.currentPage)
      root.pageKicker = "Control center"
    }
  }

  function back() {
    if (root.currentSubpage !== "") {
      root.openPage(root.currentPage, "")
    } else {
      root.openPage("home", "")
    }
  }

  function pageLabel(page) {
    switch (page) {
    case "learn": return "Learn"
    case "share": return "Share"
    case "style": return "Style"
    case "setup": return "Setup"
    case "security": return "Security"
    case "config": return "Config"
    case "hardware": return "Hardware"
    case "manage": return "Manage"
    case "about": return "About"
    default: return "Ryoku"
    }
  }
```

Update the existing `Connections { target: Popups }` handler:

```qml
    function onSettingsMenuOpenChanged() {
      if (Popups.settingsMenuOpen) {
        closeTimer.stop()
        root.openRequestedRoute()
        root.windowVisible = true
      } else {
        closeTimer.restart()
      }
    }
```

Add the home models:

```qml
  ListModel {
    id: quickControlsModel
    ListElement { label: "Wi-Fi"; icon: "wifi"; action: "wifi-toggle"; accent: "#7dc4e4" }
    ListElement { label: "Bluetooth"; icon: "bluetooth"; action: "bluetooth-toggle"; accent: "#8aadf4" }
    ListElement { label: "Airplane Mode"; icon: "airplane"; action: "airplane-toggle"; accent: "#f5a97f" }
    ListElement { label: "Hotspot"; icon: "hotspot"; action: "hotspot-toggle"; accent: "#91d7e3" }
    ListElement { label: "Night Light"; icon: "night"; action: "nightlight-toggle"; accent: "#eed49f" }
    ListElement { label: "Focus Mode"; icon: "focus"; action: "focus-toggle"; accent: "#a6da95" }
    ListElement { label: "Do Not Disturb"; icon: "dnd"; action: "dnd-toggle"; accent: "#ed8796" }
    ListElement { label: "Filter"; icon: "filter"; action: "filter-open"; accent: "#c6a0f6" }
  }

  ListModel {
    id: nativeSectionsModel
    ListElement { label: "Learn"; hint: "Docs and keys"; page: "learn"; accent: "#8aadf4" }
    ListElement { label: "Share"; hint: "Clipboard and files"; page: "share"; accent: "#91d7e3" }
    ListElement { label: "Style"; hint: "Theme and text"; page: "style"; accent: "#c6a0f6" }
    ListElement { label: "Setup"; hint: "Controls and config"; page: "setup"; accent: "#a6da95" }
    ListElement { label: "Manage"; hint: "Install, remove, maintain"; page: "manage"; accent: "#eed49f" }
    ListElement { label: "About"; hint: "Ryoku details"; page: "about"; accent: "#f5a97f" }
  }
```

The page stack must use stable item dimensions:

```qml
        Item {
          id: pageStack
          width: parent.width
          height: parent.height - header.height - 10
          clip: true
        }
```

Inside `pageStack`, implement:

- a home page visible when `root.currentPage === "home"`
- a detail page visible when `root.currentPage !== "home"`
- a back icon/text button visible only away from home
- `MouseArea { anchors.fill: parent; onClicked: mouse.accepted = true }` on the card
- `Keys.onEscapePressed: Popups.closeAll()` at the existing focus item

Use the existing `SystemMenuPopup.qml` color pattern: dark translucent `PopupShape`, 1px accent stroke, 3px accent rails, 6px to 8px tile radius, and `HoverHandler`/`MouseArea` per tile.

- [ ] **Step 4: Run tests and commit**

Run:

```bash
tests/quickshell-topbar-settings-menus.sh
```

Expected: PASS for shell route, ownership, geometry, and home model assertions. Quick toggle actions may still be non-functional until Task 3, but the labels and ownership boundaries must pass.

Commit:

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml tests/quickshell-topbar-settings-menus.sh
git commit -m "feat: rebuild top right control center home"
```

## Task 3: Implement Inline Quick Controls Without Duplicates

**Files:**
- Modify: `tests/quickshell-topbar-settings-menus.sh`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`

- [ ] **Step 1: Add failing quick-control behavior tests**

In `tests/quickshell-topbar-settings-menus.sh`, add these assertions after the quick-control label loop:

```bash
grep -q 'function wifiStatusText()' "$settings_popup" \
  || fail "SettingsMenuPopup should expose Wi-Fi status text"
grep -q 'function bluetoothStatusText()' "$settings_popup" \
  || fail "SettingsMenuPopup should expose Bluetooth status text"
grep -q 'function quickActive(action)' "$settings_popup" \
  || fail "SettingsMenuPopup should calculate quick control active states"
grep -q 'function runQuickAction(action)' "$settings_popup" \
  || fail "SettingsMenuPopup should route quick control actions"
grep -q 'nmcli radio wifi' "$settings_popup" \
  || fail "Wi-Fi quick control should use nmcli radio"
grep -q 'bluetoothctl power' "$settings_popup" \
  || fail "Bluetooth quick control should use bluetoothctl power"
grep -q 'rfkill block all' "$settings_popup" \
  || fail "Airplane Mode should use rfkill block all"
grep -q 'rfkill unblock all' "$settings_popup" \
  || fail "Airplane Mode should use rfkill unblock all"
grep -q 'hyprsunset' "$settings_popup" \
  || fail "Night Light should use hyprsunset"
grep -q 'hyprctl keyword general:gaps_in' "$settings_popup" \
  || fail "Focus Mode should adjust Hyprland gaps"
grep -q 'ShellState.dnd = !ShellState.dnd' "$settings_popup" \
  || fail "Do Not Disturb should update ShellState.dnd"
grep -q 'hyprshade", "ls"' "$settings_popup" \
  || fail "Filter should list hyprshade filters"
grep -q 'hyprshade", "on"' "$settings_popup" \
  || fail "Filter should enable selected hyprshade filter"
grep -q 'hyprshade", "off"' "$settings_popup" \
  || fail "Filter should disable the active hyprshade filter"
! grep -q 'brightnessctl' "$settings_popup" \
  || fail "SettingsMenuPopup should not own brightness"
! grep -q 'CaffeineService' "$settings_popup" \
  || fail "SettingsMenuPopup should not own Caffeine"
! grep -q 'ScreenRecService' "$settings_popup" \
  || fail "SettingsMenuPopup should not own screen capture"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
tests/quickshell-topbar-settings-menus.sh
```

Expected: FAIL on missing quick-control process logic.

- [ ] **Step 3: Add quick-control state and process logic**

Port only the relevant logic from `config/quickshell/ryoku/vendor/brain-shell/src/services/home/QuickSettings.qml`. Do not copy brightness, Caffeine, or Screen Capture code.

Add these properties and functions near the top of `SettingsMenuPopup.qml`:

```qml
  property bool wifiOn: false
  property string wifiSSID: ""
  property bool btOn: false
  property string btDevice: ""
  property bool airplaneOn: false
  property bool hotspotOn: false
  property bool hotspotBusy: false
  property string hotspotLabel: ""
  property bool nightLightOn: false
  property string currentFilter: ""
  property var filterList: []
  property bool filterPickerOpen: false
  property int savedGapsIn: 5
  property int savedGapsOut: 10
```

Add these status helpers:

```qml
  function wifiStatusText() {
    if (root.hotspotOn) return "Used by Hotspot"
    if (!root.wifiOn) return "Off"
    return root.wifiSSID !== "" ? root.wifiSSID : "On"
  }

  function bluetoothStatusText() {
    if (!root.btOn) return "Off"
    return root.btDevice !== "" ? root.btDevice : "On"
  }

  function quickActive(action) {
    switch (action) {
    case "wifi-toggle": return root.wifiOn && !root.hotspotOn
    case "bluetooth-toggle": return root.btOn
    case "airplane-toggle": return root.airplaneOn
    case "hotspot-toggle": return root.hotspotOn || root.hotspotBusy
    case "nightlight-toggle": return root.nightLightOn
    case "focus-toggle": return ShellState.focusMode
    case "dnd-toggle": return ShellState.dnd
    case "filter-open": return root.currentFilter !== ""
    default: return false
    }
  }
```

Add `Process` blocks for:

- Wi-Fi read/toggle: `nmcli radio wifi` and `nmcli radio wifi on|off`
- Wi-Fi SSID read: `nmcli -t -f ACTIVE,SSID dev wifi`
- Bluetooth read/toggle: `bluetoothctl show`, `bluetoothctl devices Connected`, `bluetoothctl power on|off`
- Airplane read/toggle: `rfkill list all`, `rfkill block all`, `rfkill unblock all`
- Night Light read/toggle: `pgrep -x hyprsunset`, `hyprsunset -t 5600`, `pkill hyprsunset`
- Hotspot read/toggle: the existing `QuickSettings.qml` `nmcli` hotspot start/stop flow, with `BrainShellHotspot` kept as the connection name for compatibility
- Focus Mode: read `hyprctl getoption general:gaps_in -j`, read `general:gaps_out`, then set/restore `general:gaps_in` and `general:gaps_out`
- Filter: `hyprctl getoption decoration:screen_shader -j`, `hyprshade ls`, `hyprshade on`, `hyprshade off`

Add the quick action router:

```qml
  function runQuickAction(action) {
    switch (action) {
    case "wifi-toggle":
      root.toggleWifi()
      return
    case "bluetooth-toggle":
      root.toggleBluetooth()
      return
    case "airplane-toggle":
      root.toggleAirplane()
      return
    case "hotspot-toggle":
      root.toggleHotspot()
      return
    case "nightlight-toggle":
      root.toggleNightLight()
      return
    case "focus-toggle":
      root.toggleFocus()
      return
    case "dnd-toggle":
      ShellState.dnd = !ShellState.dnd
      return
    case "filter-open":
      root.openFilterPicker()
      return
    default:
      return
    }
  }
```

Add a polling timer that runs only while the popup is visible:

```qml
  Timer {
    interval: 5000
    running: root.windowVisible
    repeat: true
    onTriggered: root.pollQuickControls()
  }
```

Call `root.pollQuickControls()` inside `onSettingsMenuOpenChanged()` when the popup opens.

- [ ] **Step 4: Wire quick tiles to active state and status**

In the quick-control delegate, use:

```qml
property bool active: root.quickActive(action)
property string status: {
  switch (action) {
  case "wifi-toggle": return root.wifiStatusText()
  case "bluetooth-toggle": return root.bluetoothStatusText()
  case "hotspot-toggle": return root.hotspotLabel !== "" ? root.hotspotLabel : (root.hotspotOn ? "Active" : "Off")
  case "filter-open": return root.currentFilter !== "" ? root.currentFilter : "Off"
  default: return active ? "On" : "Off"
  }
}
```

The tile click must call:

```qml
onClicked: root.runQuickAction(action)
```

- [ ] **Step 5: Run tests and commit**

Run:

```bash
tests/quickshell-topbar-settings-menus.sh
```

Expected: PASS for quick-control ownership and behavior assertions.

Commit:

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml tests/quickshell-topbar-settings-menus.sh
git commit -m "feat: add control center quick toggles"
```

## Task 4: Add Native Pages And Leaf Actions

**Files:**
- Modify: `tests/quickshell-topbar-settings-menus.sh`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`

- [ ] **Step 1: Add failing page/action tests**

In `tests/quickshell-topbar-settings-menus.sh`, add this block after the native section assertions:

```bash
for label in "Keybindings" "Omarchy Manual" "Hyprland" "Arch" "Helix" "Bash"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "Learn page should expose $label"
done

for label in "Clipboard" "File" "Folder"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "Share page should expose $label"
done

for label in "Theme" "Font" "Background" "Hyprland look and feel" "Screensaver text" "About text"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "Style page should expose $label"
done

for label in "Audio" "Wi-Fi setup" "Bluetooth setup" "Power Profile" "System Sleep" "Monitors" "DNS" "Security" "Config" "Hardware"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "Setup page should expose $label"
done

for label in "Fingerprint" "Fido2" "Defaults" "Hyprland config" "Hypridle" "Hyprlock" "Hyprsunset" "Swayosd" "Launcher" "Waybar" "XCompose" "Laptop Display"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "Setup child pages should expose $label"
done

for label in "Package" "AUR" "Web App" "TUI" "Service" "Style pack" "Development" "Editor" "Terminal" "AI" "Windows" "Gaming"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "Manage Install should expose $label"
done

for label in "Preinstalls" "Dictation" "Theme removal" "Fingerprint removal" "Fido2 removal"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "Manage Remove should expose $label"
done

for label in "Ryoku" "Channel" "Config refresh" "Extra Themes" "Process" "Hardware restart" "Firmware" "Password" "Timezone" "Time"; do
  grep -q "label: \"$label\"" "$settings_popup" \
    || fail "Manage Maintain should expose $label"
done

grep -q 'function pageModel()' "$settings_popup" \
  || fail "SettingsMenuPopup should select page models natively"
grep -q 'function runAction(action)' "$settings_popup" \
  || fail "SettingsMenuPopup should run leaf actions"
grep -q 'function openAppearance(mode)' "$settings_popup" \
  || fail "Style actions should open the native appearance popup"
grep -q 'Popups.dotfilesOpen = true' "$settings_popup" \
  || fail "Dotfiles Hub action should open the native dotfiles hub"
grep -q 'ryoku-menu-keybindings' "$settings_popup" \
  || fail "Learn Keybindings should use ryoku-menu-keybindings"
grep -q 'ryoku-cmd-share", "clipboard"' "$settings_popup" \
  || fail "Share Clipboard should use ryoku-cmd-share clipboard"
grep -q 'ryoku-launch-audio' "$settings_popup" \
  || fail "Setup Audio should launch audio controls"
grep -q 'ryoku-launch-wifi' "$settings_popup" \
  || fail "Setup Wi-Fi should launch Wi-Fi controls"
grep -q 'ryoku-launch-bluetooth' "$settings_popup" \
  || fail "Setup Bluetooth should launch Bluetooth controls"
grep -q 'ryoku-launch-editor' "$settings_popup" \
  || fail "Editor-backed leaves should use ryoku-launch-editor"
grep -q 'ryoku-launch-floating-terminal-with-presentation' "$settings_popup" \
  || fail "Terminal-backed leaves should use the Ryoku presentation terminal"
! grep -q 'ryoku-menu learn' "$settings_popup" \
  || fail "Learn navigation should not call legacy ryoku-menu"
! grep -q 'ryoku-menu share' "$settings_popup" \
  || fail "Share navigation should not call legacy ryoku-menu"
! grep -q 'ryoku-menu setup' "$settings_popup" \
  || fail "Setup navigation should not call legacy ryoku-menu"
! grep -q 'ryoku-menu install' "$settings_popup" \
  || fail "Manage navigation should not call legacy ryoku-menu"
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
tests/quickshell-topbar-settings-menus.sh
```

Expected: FAIL on missing page models and action mappings.

- [ ] **Step 3: Add native page models**

In `SettingsMenuPopup.qml`, add `ListModel`s for:

- `learnActions`
- `shareActions`
- `styleActions`
- `setupActions`
- `setupSecurityActions`
- `setupConfigActions`
- `setupHardwareActions`
- `manageInstallActions`
- `manageRemoveActions`
- `manageMaintainActions`
- `aboutActions`

Use these required labels and action ids:

```qml
  ListModel {
    id: learnActions
    ListElement { label: "Keybindings"; hint: "Keyboard map"; action: "learn-keybindings"; accent: "#8aadf4" }
    ListElement { label: "Omarchy Manual"; hint: "Upstream manual"; action: "learn-omarchy"; accent: "#c6a0f6" }
    ListElement { label: "Hyprland"; hint: "Window manager"; action: "learn-hyprland"; accent: "#91d7e3" }
    ListElement { label: "Arch"; hint: "Arch Wiki"; action: "learn-arch"; accent: "#eed49f" }
    ListElement { label: "Helix"; hint: "Editor docs"; action: "learn-helix"; accent: "#a6da95" }
    ListElement { label: "Bash"; hint: "Shell reference"; action: "learn-bash"; accent: "#f5a97f" }
  }
```

```qml
  ListModel {
    id: shareActions
    ListElement { label: "Clipboard"; hint: "Share clipboard"; action: "share-clipboard"; accent: "#91d7e3" }
    ListElement { label: "File"; hint: "Share a file"; action: "share-file"; accent: "#8aadf4" }
    ListElement { label: "Folder"; hint: "Share a folder"; action: "share-folder"; accent: "#a6da95" }
  }
```

```qml
  ListModel {
    id: styleActions
    ListElement { label: "Theme"; hint: "Theme selector"; action: "style-theme"; accent: "#c6a0f6" }
    ListElement { label: "Font"; hint: "Font selector"; action: "style-font"; accent: "#eed49f" }
    ListElement { label: "Background"; hint: "Wallpaper selector"; action: "style-background"; accent: "#91d7e3" }
    ListElement { label: "Hyprland look and feel"; hint: "Edit looknfeel.conf"; action: "edit-hypr-look"; accent: "#8aadf4" }
    ListElement { label: "Screensaver text"; hint: "Edit screensaver text"; action: "edit-screensaver-text"; accent: "#a6da95" }
    ListElement { label: "About text"; hint: "Edit about text"; action: "edit-about-text"; accent: "#f5a97f" }
  }
```

```qml
  ListModel {
    id: setupActions
    ListElement { label: "Audio"; hint: "External controls"; action: "setup-audio"; accent: "#eed49f" }
    ListElement { label: "Wi-Fi setup"; hint: "External controls"; action: "setup-wifi"; accent: "#7dc4e4" }
    ListElement { label: "Bluetooth setup"; hint: "External controls"; action: "setup-bluetooth"; accent: "#8aadf4" }
    ListElement { label: "Power Profile"; hint: "Choose profile"; action: "setup-power-profile"; accent: "#a6da95" }
    ListElement { label: "System Sleep"; hint: "Suspend and hibernate config"; action: "setup-system-sleep"; accent: "#f5a97f" }
    ListElement { label: "Monitors"; hint: "Edit monitors.conf"; action: "edit-monitors"; accent: "#91d7e3" }
    ListElement { label: "DNS"; hint: "Setup DNS"; action: "setup-dns"; accent: "#c6a0f6" }
    ListElement { label: "Security"; hint: "Fingerprint and Fido2"; action: "page-security"; accent: "#ed8796" }
    ListElement { label: "Config"; hint: "Edit config files"; action: "page-config"; accent: "#8bd5ca" }
    ListElement { label: "Hardware"; hint: "Device toggles"; action: "page-hardware"; accent: "#f5a97f" }
  }
```

Add setup child models with these entries:

```qml
  ListModel {
    id: setupSecurityActions
    ListElement { label: "Fingerprint"; hint: "Setup fingerprint auth"; action: "setup-fingerprint"; accent: "#ed8796" }
    ListElement { label: "Fido2"; hint: "Setup Fido2 auth"; action: "setup-fido2"; accent: "#c6a0f6" }
  }

  ListModel {
    id: setupConfigActions
    ListElement { label: "Dotfiles Hub"; hint: "Native config hub"; action: "config-dotfiles"; accent: "#f5bde6" }
    ListElement { label: "Defaults"; hint: "Edit uwsm defaults"; action: "edit-uwsm-default"; accent: "#8bd5ca" }
    ListElement { label: "Hyprland config"; hint: "Edit hyprland.conf"; action: "edit-hyprland"; accent: "#8aadf4" }
    ListElement { label: "Hypridle"; hint: "Edit hypridle.conf"; action: "edit-hypridle"; accent: "#91d7e3" }
    ListElement { label: "Hyprlock"; hint: "Edit hyprlock.conf"; action: "edit-hyprlock"; accent: "#eed49f" }
    ListElement { label: "Hyprsunset"; hint: "Edit hyprsunset.conf"; action: "edit-hyprsunset"; accent: "#f5a97f" }
    ListElement { label: "Swayosd"; hint: "Edit OSD config"; action: "edit-swayosd"; accent: "#a6da95" }
    ListElement { label: "Launcher"; hint: "Edit tofi config"; action: "edit-launcher"; accent: "#c6a0f6" }
    ListElement { label: "Waybar"; hint: "Edit waybar config"; action: "edit-waybar"; accent: "#8bd5ca" }
    ListElement { label: "XCompose"; hint: "Edit compose map"; action: "edit-xcompose"; accent: "#f5a97f" }
  }

  ListModel {
    id: setupHardwareActions
    ListElement { label: "Laptop Display"; hint: "Toggle internal panel"; action: "hardware-laptop-display"; requires: ""; accent: "#91d7e3" }
    ListElement { label: "Hybrid GPU"; hint: "Switch GPU mode"; action: "hardware-hybrid-gpu"; requires: "hybrid-gpu"; accent: "#f5a97f" }
    ListElement { label: "Touchpad"; hint: "Toggle touchpad"; action: "hardware-touchpad"; requires: "touchpad"; accent: "#a6da95" }
  }
```

Add availability checks for hardware-only rows:

```qml
  property bool hybridGpuAvailable: false
  property bool touchpadAvailable: false

  Process {
    id: hybridGpuCheck
    command: ["ryoku-hw-hybrid-gpu"]
    running: false
    onExited: function(code, status) { root.hybridGpuAvailable = code === 0 }
  }

  Process {
    id: touchpadCheck
    command: ["ryoku-hw-touchpad"]
    running: false
    onExited: function(code, status) { root.touchpadAvailable = code === 0 }
  }

  function requirementMet(requirement) {
    if (requirement === "" || requirement === undefined) return true
    if (requirement === "hybrid-gpu") return root.hybridGpuAvailable
    if (requirement === "touchpad") return root.touchpadAvailable
    return true
  }
```

Start both checks in `Component.onCompleted`. In the detail-page delegate, bind `visible` and `height` from `root.requirementMet(requires)` so unsupported hardware rows do not occupy space.

The Manage models must use top-level segmented tabs named exactly:

```qml
property string manageTab: "install"
```

and labels:

```qml
Install
Remove
Maintain
```

- [ ] **Step 4: Add page model selection**

Add:

```qml
  function pageModel() {
    if (root.currentPage === "learn") return learnActions
    if (root.currentPage === "share") return shareActions
    if (root.currentPage === "style") return styleActions
    if (root.currentPage === "setup" && root.currentSubpage === "security") return setupSecurityActions
    if (root.currentPage === "setup" && root.currentSubpage === "config") return setupConfigActions
    if (root.currentPage === "setup" && root.currentSubpage === "hardware") return setupHardwareActions
    if (root.currentPage === "setup") return setupActions
    if (root.currentPage === "manage" && root.manageTab === "remove") return manageRemoveActions
    if (root.currentPage === "manage" && root.manageTab === "maintain") return manageMaintainActions
    if (root.currentPage === "manage") return manageInstallActions
    if (root.currentPage === "about") return aboutActions
    return nativeSectionsModel
  }
```

The detail page repeater must use `model: root.pageModel()` and call `root.runAction(action)`.

- [ ] **Step 5: Add command helpers**

Add these helpers:

```qml
  function runCommand(command) {
    actionRunner.command = command
    actionRunner.running = true
    Popups.closeAll()
  }

  function runTerminal(command) {
    actionRunner.command = ["ryoku-launch-floating-terminal-with-presentation", command]
    actionRunner.running = true
    Popups.closeAll()
  }

  function editFile(path) {
    root.runCommand(["ryoku-launch-editor", path])
  }

  function openAppearance(mode) {
    Popups.closeAll()
    Popups.wallpaperMode = mode
    Popups.wallpaperOpen = true
  }
```

Implement `runAction(action)` with explicit cases. Required mappings:

```qml
    case "learn-keybindings": root.runCommand(["ryoku-menu-keybindings"]); return
    case "learn-omarchy": root.runCommand(["ryoku-launch-webapp", "https://learn.omacom.io/2/the-omarchy-manual"]); return
    case "learn-hyprland": root.runCommand(["ryoku-launch-webapp", "https://wiki.hypr.land/"]); return
    case "learn-arch": root.runCommand(["ryoku-launch-webapp", "https://wiki.archlinux.org/title/Main_page"]); return
    case "learn-helix": root.runCommand(["ryoku-launch-webapp", "https://docs.helix-editor.com/"]); return
    case "learn-bash": root.runCommand(["ryoku-launch-webapp", "https://devhints.io/bash"]); return
    case "share-clipboard": root.runCommand(["ryoku-cmd-share", "clipboard"]); return
    case "share-file": root.runTerminal("ryoku-cmd-share file"); return
    case "share-folder": root.runTerminal("ryoku-cmd-share folder"); return
    case "style-theme": root.openAppearance("theme"); return
    case "style-font": root.openAppearance("font"); return
    case "style-background": root.openAppearance("wallpaper"); return
    case "edit-hypr-look": root.editFile(Quickshell.env("HOME") + "/.config/hypr/looknfeel.conf"); return
    case "edit-screensaver-text": root.editFile(Quickshell.env("RYOKU_CONFIG_PATH") + "/branding/screensaver.txt"); return
    case "edit-about-text": root.editFile(Quickshell.env("RYOKU_CONFIG_PATH") + "/branding/about.txt"); return
    case "setup-audio": root.runCommand(["ryoku-launch-audio"]); return
    case "setup-wifi": root.runCommand(["ryoku-launch-wifi"]); return
    case "setup-bluetooth": root.runCommand(["ryoku-launch-bluetooth"]); return
    case "setup-dns": root.runTerminal("ryoku-setup-dns"); return
    case "page-security": root.openPage("setup", "security"); return
    case "page-config": root.openPage("setup", "config"); return
    case "page-hardware": root.openPage("setup", "hardware"); return
    case "config-dotfiles": Popups.closeAll(); Popups.dotfilesOpen = true; return
    case "setup-fingerprint": root.runTerminal("ryoku-setup-fingerprint"); return
    case "setup-fido2": root.runTerminal("ryoku-setup-fido2"); return
    case "hardware-laptop-display": root.runCommand(["ryoku-hyprland-monitor-internal", "toggle"]); return
    case "hardware-hybrid-gpu": root.runTerminal("ryoku-toggle-hybrid-gpu"); return
    case "hardware-touchpad": root.runCommand(["ryoku-toggle-touchpad"]); return
    case "about-launch": root.runCommand(["ryoku-launch-about"]); return
```

For editor-backed config actions, use `root.editFile()` with these literal paths:

```qml
Quickshell.env("HOME") + "/.config/uwsm/default"
Quickshell.env("HOME") + "/.config/hypr/hyprland.conf"
Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"
Quickshell.env("HOME") + "/.config/hypr/hyprlock.conf"
Quickshell.env("HOME") + "/.config/hypr/hyprsunset.conf"
Quickshell.env("HOME") + "/.config/swayosd/config.toml"
Quickshell.env("RYOKU_CONFIG_PATH") + "/tofi/config"
Quickshell.env("HOME") + "/.config/waybar/config.jsonc"
Quickshell.env("HOME") + "/.XCompose"
Quickshell.env("RYOKU_CONFIG_PATH") + "/branding/about.txt"
```

For Manage leaf actions, map categories and children to command strings that match `bin/ryoku-menu`. Use these direct mappings:

```qml
case "install-package": root.runTerminal("ryoku-pkg-install"); return
case "install-aur": root.runTerminal("ryoku-pkg-aur-install"); return
case "install-webapp": root.runTerminal("ryoku-webapp-install"); return
case "install-tui": root.runTerminal("ryoku-tui-install"); return
case "install-windows": root.runTerminal("ryoku-windows-vm install"); return
case "remove-package": root.runTerminal("ryoku-pkg-remove"); return
case "remove-webapp": root.runTerminal("ryoku-webapp-remove"); return
case "remove-tui": root.runTerminal("ryoku-tui-remove"); return
case "remove-preinstalls": root.runTerminal("ryoku-remove-preinstalls"); return
case "remove-dictation": root.runTerminal("ryoku-voxtype-remove"); return
case "remove-theme": root.runTerminal("ryoku-theme-remove"); return
case "remove-windows": root.runTerminal("ryoku-windows-vm remove"); return
case "remove-fingerprint": root.runTerminal("ryoku-setup-fingerprint --remove"); return
case "remove-fido2": root.runTerminal("ryoku-setup-fido2 --remove"); return
case "maintain-ryoku": root.runTerminal("ryoku-update"); return
case "maintain-extra-themes": root.runTerminal("ryoku-theme-update"); return
case "maintain-firmware": root.runTerminal("ryoku-update-firmware"); return
case "maintain-timezone": root.runTerminal("ryoku-tz-select"); return
case "maintain-time": root.runTerminal("ryoku-update-time"); return
case "maintain-rollback": root.runTerminal("ryoku-rollback"); return
```

Add native child pages and action cases for Manage entries with these exact labels and commands:

```qml
case "page-install-service": root.openPage("manage", "install-service"); return
case "install-dropbox": root.runTerminal("ryoku-install-dropbox"); return
case "install-tailscale": root.runTerminal("ryoku-install-tailscale"); return
case "install-nordvpn": root.runTerminal("ryoku-install-nordvpn"); return
case "install-once": root.runTerminal("ryoku-install-once"); return
case "install-bitwarden": root.runTerminal("echo 'Installing Bitwarden...'; ryoku-pkg-add bitwarden bitwarden-cli && setsid gtk-launch bitwarden"); return
case "install-chromium-account": root.runTerminal("ryoku-install-chromium-google-account"); return

case "page-install-style": root.openPage("manage", "install-style"); return
case "install-theme": root.runTerminal("ryoku-theme-install"); return
case "install-background": root.runCommand(["ryoku-theme-bg-install"]); return
case "page-install-font": root.openPage("manage", "install-font"); return
case "install-font-cascadia": root.runTerminal("echo 'Installing Cascadia Mono...'; ryoku-pkg-add ttf-cascadia-mono-nerd && sleep 2 && ryoku-font-set 'CaskaydiaMono Nerd Font'"); return
case "install-font-meslo": root.runTerminal("echo 'Installing Meslo LG Mono...'; ryoku-pkg-add ttf-meslo-nerd && sleep 2 && ryoku-font-set 'MesloLGL Nerd Font'"); return
case "install-font-fira": root.runTerminal("echo 'Installing Fira Code...'; ryoku-pkg-add ttf-firacode-nerd && sleep 2 && ryoku-font-set 'FiraCode Nerd Font'"); return
case "install-font-victor": root.runTerminal("echo 'Installing Victor Code...'; ryoku-pkg-add ttf-victor-mono-nerd && sleep 2 && ryoku-font-set 'VictorMono Nerd Font'"); return
case "install-font-bitstream": root.runTerminal("echo 'Installing Bitstream Vera Code...'; ryoku-pkg-add ttf-bitstream-vera-mono-nerd && sleep 2 && ryoku-font-set 'BitstromWera Nerd Font'"); return
case "install-font-iosevka": root.runTerminal("echo 'Installing Iosevka...'; ryoku-pkg-add ttf-iosevka-nerd && sleep 2 && ryoku-font-set 'Iosevka Nerd Font Mono'"); return

case "page-install-development": root.openPage("manage", "install-development"); return
case "install-dev-rails": root.runTerminal("ryoku-install-dev-env ruby"); return
case "install-dev-docker-db": root.runTerminal("ryoku-install-docker-dbs"); return
case "page-install-javascript": root.openPage("manage", "install-javascript"); return
case "install-dev-node": root.runTerminal("ryoku-install-dev-env node"); return
case "install-dev-bun": root.runTerminal("ryoku-install-dev-env bun"); return
case "install-dev-deno": root.runTerminal("ryoku-install-dev-env deno"); return
case "install-dev-go": root.runTerminal("ryoku-install-dev-env go"); return
case "page-install-php": root.openPage("manage", "install-php"); return
case "install-dev-php": root.runTerminal("ryoku-install-dev-env php"); return
case "install-dev-laravel": root.runTerminal("ryoku-install-dev-env laravel"); return
case "install-dev-symfony": root.runTerminal("ryoku-install-dev-env symfony"); return
case "install-dev-python": root.runTerminal("ryoku-install-dev-env python"); return
case "page-install-elixir": root.openPage("manage", "install-elixir"); return
case "install-dev-elixir": root.runTerminal("ryoku-install-dev-env elixir"); return
case "install-dev-phoenix": root.runTerminal("ryoku-install-dev-env phoenix"); return
case "install-dev-zig": root.runTerminal("ryoku-install-dev-env zig"); return
case "install-dev-rust": root.runTerminal("ryoku-install-dev-env rust"); return
case "install-dev-java": root.runTerminal("ryoku-install-dev-env java"); return
case "install-dev-dotnet": root.runTerminal("ryoku-install-dev-env dotnet"); return
case "install-dev-ocaml": root.runTerminal("ryoku-install-dev-env ocaml"); return
case "install-dev-clojure": root.runTerminal("ryoku-install-dev-env clojure"); return
case "install-dev-scala": root.runTerminal("ryoku-install-dev-env scala"); return

case "page-install-editor": root.openPage("manage", "install-editor"); return
case "install-vscode": root.runTerminal("ryoku-install-vscode"); return
case "install-cursor": root.runTerminal("echo 'Installing Cursor...'; ryoku-pkg-add cursor-bin && setsid gtk-launch cursor"); return
case "install-zed": root.runTerminal("echo 'Installing Zed...'; ryoku-pkg-add zed && setsid gtk-launch dev.zed.Zed"); return
case "install-sublime": root.runTerminal("echo 'Installing Sublime Text...'; ryoku-pkg-add sublime-text-4 && setsid gtk-launch sublime_text"); return
case "install-helix": root.runTerminal("echo 'Installing Helix...'; ryoku-pkg-add helix"); return
case "install-emacs": root.runTerminal("echo 'Installing Emacs...'; ryoku-pkg-add emacs-wayland && systemctl --user enable --now emacs.service"); return

case "page-install-terminal": root.openPage("manage", "install-terminal"); return
case "install-terminal-alacritty": root.runTerminal("ryoku-install-terminal alacritty"); return
case "install-terminal-ghostty": root.runTerminal("ryoku-install-terminal ghostty"); return
case "install-terminal-kitty": root.runTerminal("ryoku-install-terminal kitty"); return

case "page-install-ai": root.openPage("manage", "install-ai"); return
case "install-dictation": root.runTerminal("ryoku-voxtype-install"); return
case "install-lm-studio": root.runTerminal("echo 'Installing LM Studio...'; ryoku-pkg-add lmstudio-bin"); return
case "install-ollama": root.runTerminal("if command -v nvidia-smi >/dev/null 2>&1; then ryoku-pkg-add ollama-cuda; elif command -v rocminfo >/dev/null 2>&1; then ryoku-pkg-add ollama-rocm; else ryoku-pkg-add ollama; fi"); return
case "install-crush": root.runTerminal("echo 'Installing Crush...'; ryoku-pkg-add crush-bin"); return

case "page-install-gaming": root.openPage("manage", "install-gaming"); return
case "install-steam": root.runTerminal("ryoku-install-steam"); return
case "install-geforce-now": root.runTerminal("ryoku-install-geforce-now"); return
case "install-retroarch": root.runTerminal("echo 'Installing RetroArch from AUR...'; ryoku-pkg-aur-add retroarch retroarch-assets libretro libretro-fbneo && setsid gtk-launch com.libretro.RetroArch.desktop"); return
case "install-minecraft": root.runTerminal("echo 'Installing Minecraft...'; ryoku-pkg-add minecraft-launcher && setsid gtk-launch minecraft-launcher"); return
case "install-xbox-controller": root.runTerminal("ryoku-install-xbox-controllers"); return

case "page-remove-development": root.openPage("manage", "remove-development"); return
case "remove-dev-rails": root.runTerminal("ryoku-remove-dev-env ruby"); return
case "page-remove-javascript": root.openPage("manage", "remove-javascript"); return
case "remove-dev-node": root.runTerminal("ryoku-remove-dev-env node"); return
case "remove-dev-bun": root.runTerminal("ryoku-remove-dev-env bun"); return
case "remove-dev-deno": root.runTerminal("ryoku-remove-dev-env deno"); return
case "remove-dev-go": root.runTerminal("ryoku-remove-dev-env go"); return
case "page-remove-php": root.openPage("manage", "remove-php"); return
case "remove-dev-php": root.runTerminal("ryoku-remove-dev-env php"); return
case "remove-dev-laravel": root.runTerminal("ryoku-remove-dev-env laravel"); return
case "remove-dev-symfony": root.runTerminal("ryoku-remove-dev-env symfony"); return
case "remove-dev-python": root.runTerminal("ryoku-remove-dev-env python"); return
case "page-remove-elixir": root.openPage("manage", "remove-elixir"); return
case "remove-dev-elixir": root.runTerminal("ryoku-remove-dev-env elixir"); return
case "remove-dev-phoenix": root.runTerminal("ryoku-remove-dev-env phoenix"); return
case "remove-dev-zig": root.runTerminal("ryoku-remove-dev-env zig"); return
case "remove-dev-rust": root.runTerminal("ryoku-remove-dev-env rust"); return
case "remove-dev-java": root.runTerminal("ryoku-remove-dev-env java"); return
case "remove-dev-dotnet": root.runTerminal("ryoku-remove-dev-env dotnet"); return
case "remove-dev-ocaml": root.runTerminal("ryoku-remove-dev-env ocaml"); return
case "remove-dev-clojure": root.runTerminal("ryoku-remove-dev-env clojure"); return
case "remove-dev-scala": root.runTerminal("ryoku-remove-dev-env scala"); return

case "page-maintain-channel": root.openPage("manage", "maintain-channel"); return
case "maintain-channel-stable": root.runTerminal("ryoku-channel-set stable"); return
case "maintain-channel-rc": root.runTerminal("ryoku-channel-set rc"); return
case "maintain-channel-edge": root.runTerminal("ryoku-channel-set edge"); return
case "maintain-channel-dev": root.runTerminal("ryoku-channel-set dev"); return
case "page-maintain-config": root.openPage("manage", "maintain-config"); return
case "maintain-config-hyprland": root.runTerminal("ryoku-refresh-hyprland"); return
case "maintain-config-hypridle": root.runTerminal("ryoku-refresh-hypridle"); return
case "maintain-config-hyprlock": root.runTerminal("ryoku-refresh-hyprlock"); return
case "maintain-config-hyprsunset": root.runTerminal("ryoku-refresh-hyprsunset"); return
case "maintain-config-plymouth": root.runTerminal("ryoku-refresh-plymouth"); return
case "maintain-config-swayosd": root.runTerminal("ryoku-refresh-swayosd"); return
case "maintain-config-tmux": root.runTerminal("ryoku-refresh-tmux"); return
case "maintain-config-launcher": root.runTerminal("mkdir -p \"$RYOKU_CONFIG_PATH/tofi\" && cp \"$RYOKU_PATH/default/tofi/config\" \"$RYOKU_CONFIG_PATH/tofi/config\""); return
case "maintain-config-waybar": root.runTerminal("ryoku-refresh-waybar"); return
case "page-maintain-process": root.openPage("manage", "maintain-process"); return
case "maintain-process-hypridle": root.runCommand(["ryoku-restart-hypridle"]); return
case "maintain-process-hyprsunset": root.runCommand(["ryoku-restart-hyprsunset"]); return
case "maintain-process-mako": root.runCommand(["ryoku-restart-mako"]); return
case "maintain-process-swayosd": root.runCommand(["ryoku-restart-swayosd"]); return
case "maintain-process-launcher": root.runCommand(["notify-send", "Launcher", "Tofi has no daemon; nothing to restart."]); return
case "maintain-process-waybar": root.runCommand(["ryoku-restart-waybar"]); return
case "page-maintain-hardware": root.openPage("manage", "maintain-hardware"); return
case "maintain-hardware-audio": root.runTerminal("ryoku-restart-pipewire"); return
case "maintain-hardware-wifi": root.runTerminal("ryoku-restart-wifi"); return
case "maintain-hardware-bluetooth": root.runTerminal("ryoku-restart-bluetooth"); return
case "maintain-hardware-trackpad": root.runTerminal("ryoku-restart-trackpad"); return
case "page-maintain-password": root.openPage("manage", "maintain-password"); return
case "maintain-password-drive": root.runTerminal("ryoku-drive-set-password"); return
case "maintain-password-user": root.runTerminal("passwd"); return
```

The child-page models must expose these exact labels:

```text
Service: Dropbox, Tailscale, NordVPN, ONCE, Bitwarden, Chromium Account
Style pack: Theme, Background, Font
Font: Cascadia Mono, Meslo LG Mono, Fira Code, Victor Code, Bitstream Vera Mono, Iosevka
Development: Ruby on Rails, Docker DB, JavaScript, Go, PHP, Python, Elixir, Zig, Rust, Java, .NET, OCaml, Clojure, Scala
JavaScript: Node.js, Bun, Deno
PHP: PHP, Laravel, Symfony
Elixir: Elixir, Phoenix
Editor: VSCode, Cursor, Zed, Sublime Text, Helix, Emacs
Terminal: Alacritty, Ghostty, Kitty
AI: Dictation, LM Studio, Ollama, Crush
Gaming: Steam, NVIDIA GeForce NOW, RetroArch, Minecraft, Xbox Controller
Remove Development: Ruby on Rails, JavaScript, Go, PHP, Python, Elixir, Zig, Rust, Java, .NET, OCaml, Clojure, Scala
Channel: Stable, RC, Edge, Dev
Config refresh: Hyprland, Hypridle, Hyprlock, Hyprsunset, Plymouth, Swayosd, Tmux, Launcher, Waybar
Process: Hypridle, Hyprsunset, Mako, Swayosd, Launcher, Waybar
Hardware restart: Audio, Wi-Fi, Bluetooth, Trackpad
Password: Drive Encryption, User
```

- [ ] **Step 6: Run tests and commit**

Run:

```bash
tests/quickshell-topbar-settings-menus.sh
```

Expected: PASS for page labels, action helpers, no old `ryoku-menu <section>` navigation, and Dotfiles preservation.

Commit:

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml tests/quickshell-topbar-settings-menus.sh
git commit -m "feat: add control center pages"
```

## Task 5: Verify, Deploy To Live Copies, And Restart Shell

**Files:**
- Read/verify: all files touched in Tasks 1-4
- Copy to: `/home/omi/.local/share/ryoku`
- Copy to: `/home/omi/.config/quickshell/ryoku`

- [ ] **Step 1: Run static test suite for affected surfaces**

Run:

```bash
tests/ryoku-ipc.sh
tests/quickshell-topbar-settings-menus.sh
tests/quickshell-app-launcher.sh
tests/quickshell-toolbox.sh
tests/quickshell-wallpaper-switcher.sh
```

Expected: all selected tests pass. `tests/quickshell-app-launcher.sh` verifies `SUPER+SPACE` still owns Apps. `tests/quickshell-toolbox.sh` verifies toolbox-owned capture utilities remain outside the control center. `tests/quickshell-wallpaper-switcher.sh` verifies appearance popup entry points still work.

- [ ] **Step 2: Validate no forbidden duplicate labels landed**

Run:

```bash
rg -n 'label: "(Apps|Activity|Caffeine|Screen Capture|Volume|Brightness|Shutdown|Restart|Log Out)"' config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml
```

Expected: no output.

Run:

```bash
rg -n 'ryoku-menu (toggle|hardware|share|learn|setup|install|remove|update)' config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml default/hypr/bindings/utilities.conf
```

Expected: no output.

- [ ] **Step 3: Copy dev changes into installed share**

Run these after tests pass:

```bash
install -m 0755 bin/ryoku-ipc /home/omi/.local/share/ryoku/bin/ryoku-ipc
install -m 0644 default/hypr/bindings/utilities.conf /home/omi/.local/share/ryoku/default/hypr/bindings/utilities.conf
install -m 0644 config/quickshell/ryoku/shell.qml /home/omi/.local/share/ryoku/config/quickshell/ryoku/shell.qml
install -m 0644 config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml /home/omi/.local/share/ryoku/config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml
install -m 0644 config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml /home/omi/.local/share/ryoku/config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml
```

Expected: commands complete with no output.

- [ ] **Step 4: Copy QML changes into live Quickshell config**

Run:

```bash
install -m 0644 config/quickshell/ryoku/shell.qml /home/omi/.config/quickshell/ryoku/shell.qml
install -m 0644 config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml /home/omi/.config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml
install -m 0644 config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml /home/omi/.config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml
```

Expected: commands complete with no output.

- [ ] **Step 5: Restart Quickshell**

Run:

```bash
bin/ryoku-restart-shell
```

Expected: Quickshell restarts and a new `quickshell -c ryoku` process is present.

Verify:

```bash
pgrep -a quickshell
```

Expected: one active `quickshell -c ryoku` process.

- [ ] **Step 6: Verify dev/share/live copies match**

Run:

```bash
diff -u config/quickshell/ryoku/shell.qml /home/omi/.local/share/ryoku/config/quickshell/ryoku/shell.qml
diff -u config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml /home/omi/.local/share/ryoku/config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml
diff -u config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml /home/omi/.local/share/ryoku/config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml
diff -u config/quickshell/ryoku/shell.qml /home/omi/.config/quickshell/ryoku/shell.qml
diff -u config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml /home/omi/.config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml
diff -u config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml /home/omi/.config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml
```

Expected: no diff output.

- [ ] **Step 7: Manual smoke test**

Run:

```bash
ryoku-ipc shell settings-menu home
```

Expected: control center opens at the home route.

Run:

```bash
ryoku-ipc shell settings-menu share
```

Expected: control center opens at the Share page.

Run:

```bash
ryoku-ipc shell settings-menu hardware
```

Expected: control center opens at `Setup -> Hardware`.

Press `SUPER+ALT+SPACE`, `SUPER+CTRL+O`, `SUPER+CTRL+H`, and `SUPER+CTRL+S`.

Expected: each opens the native top-right control center route. No tofi `ryoku-menu` appears.

- [ ] **Step 8: Commit deployment-ready implementation**

Commit only repo files, not live copies:

```bash
git add bin/ryoku-ipc config/quickshell/ryoku/shell.qml config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml default/hypr/bindings/utilities.conf tests/ryoku-ipc.sh tests/quickshell-topbar-settings-menus.sh docs/superpowers/specs/2026-04-30-top-right-control-center-design.md docs/superpowers/plans/2026-04-30-top-right-control-center-implementation.md
git commit -m "feat: add top right control center"
```

## Self-Review

- Spec coverage: Task 1 covers routed IPC and direct binding replacement. Task 2 covers topbar-attached control-center structure, Apps exclusion, Dotfiles preservation, and ownership tests. Task 3 covers in-scope quick toggles while excluding brightness, Caffeine, and capture tools. Task 4 covers native pages, Manage/Maintain, leaf actions, and old-menu section replacement. Task 5 covers live/share deployment and restart.
- Type consistency: routed page names are `home`, `share`, and `setup hardware`; popup route properties are `settingsMenuRequestedPage` and `settingsMenuRequestedSubpage`; IPC-callable QML entry points are `openSettingsMenuHome`, `openSettingsMenuShare`, and `openSettingsMenuHardware`.
- Command consistency: top-level toggle remains `ryoku-ipc shell toggle settings-menu`; direct old submenu replacements use `ryoku-ipc shell settings-menu home|share|hardware`; app launching remains `SUPER+SPACE`.
