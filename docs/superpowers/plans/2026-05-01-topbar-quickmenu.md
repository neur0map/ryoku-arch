# Topbar Quickmenu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `Super+Alt+Space` open a compact, icon-first quickmenu that feels like a right-topbar extension while preserving the existing settings-menu routes and commands.

**Architecture:** Keep behavior in `SettingsMenuPopup.qml` and replace the oversized home/detail delegates with compact inline QML components. Update the existing static regression test first so it rejects the old 456x520 drawer, old 62px quick tiles, translucent background, and non-scrolling detail pages.

**Tech Stack:** Quickshell QML, QtQuick, existing Ryoku `Popups`/`ShellState` singletons, Bash static regression tests.

---

## File Structure

- Modify: `tests/quickshell-topbar-settings-menus.sh`
  - Owns static regression coverage for topbar-attached menus, keybindings, popup contracts, and command wiring.
  - This plan updates only the `SettingsMenuPopup` assertions that currently lock in the old drawer and tile design.
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`
  - Owns the quickmenu popup, quick-control process state, settings route models, action routing, and visual delegates.
  - This pass keeps all new QML components inline in this file: `QuickToggleButton`, `StatusStrip`, `SectionChip`, `ActionChip`, and `ManageSegment`.

No new files are needed for runtime code.

---

### Task 1: Update Static Regression Tests For The New Quickmenu Contract

**Files:**
- Modify: `tests/quickshell-topbar-settings-menus.sh`

- [ ] **Step 1: Replace old settings-menu dimension assertions with compact/page-aware assertions**

In `tests/quickshell-topbar-settings-menus.sh`, replace the block that asserts `menuWidth: 456` and `menuHeight: 520` with:

```bash
grep -Eq 'readonly property int menuWidth:[[:space:]]+344' "$settings_popup" \
  || fail "SettingsMenuPopup should use the compact quickmenu width"
grep -Eq 'readonly property int homeMenuHeight:[[:space:]]+276' "$settings_popup" \
  || fail "SettingsMenuPopup home view should stay compact"
grep -Eq 'readonly property int detailMenuHeight:[[:space:]]+440' "$settings_popup" \
  || fail "SettingsMenuPopup detail views should use a capped height"
grep -q 'readonly property int targetMenuHeight:' "$settings_popup" \
  || fail "SettingsMenuPopup should size height from the active route"
grep -q 'readonly property int fullCardHeight: Theme.notchHeight + root.targetMenuHeight' "$settings_popup" \
  || fail "SettingsMenuPopup should animate from notch height to route target height"
! grep -Eq 'readonly property int menuHeight:[[:space:]]+520' "$settings_popup" \
  || fail "SettingsMenuPopup should no longer use the old full-height drawer"
```

- [ ] **Step 2: Replace old page stack height assertion with the new compact layout assertion**

In the `page_stack_block` assertions, replace:

```bash
grep -q 'height: parent.height - header.height - 10' <<< "$page_stack_block" \
  || fail "SettingsMenuPopup page stack should use stable parent-relative height"
```

with:

```bash
grep -q 'height: parent.height - header.height - 8' <<< "$page_stack_block" \
  || fail "SettingsMenuPopup page stack should use compact parent-relative height"
```

- [ ] **Step 3: Add assertions for topbar background and icon-first quick controls**

After the existing `grep -q 'width: root.fullCardWidth' "$settings_popup"` assertion, add:

```bash
grep -q 'color: Theme.background' "$settings_popup" \
  || fail "SettingsMenuPopup should use the topbar background color directly"
! grep -q 'color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.95)' "$settings_popup" \
  || fail "SettingsMenuPopup should not use the old translucent drawer background"
grep -q 'component QuickToggleButton: Rectangle' "$settings_popup" \
  || fail "SettingsMenuPopup should render icon-first quick toggle buttons"
grep -q 'id: quickToggleRail' "$settings_popup" \
  || fail "SettingsMenuPopup should render a single-row quick toggle rail"
grep -q 'width: 34' "$settings_popup" \
  || fail "SettingsMenuPopup quick toggles should use compact 34px buttons"
grep -q 'activeFocusOnTab: true' "$settings_popup" \
  || fail "SettingsMenuPopup quick toggles should expose keyboard focus"
grep -q 'Keys.onSpacePressed' "$settings_popup" \
  || fail "SettingsMenuPopup quick toggles should activate from keyboard Space"
! grep -q 'height: 62' "$settings_popup" \
  || fail "SettingsMenuPopup should no longer use tall labeled quick tiles"
! grep -q 'text: quickTile.label' "$settings_popup" \
  || fail "SettingsMenuPopup quick toggles should not render full labels in each button"
```

- [ ] **Step 4: Replace quick status assertions**

Replace:

```bash
grep -q 'property string status:' "$settings_popup" \
  || fail "SettingsMenuPopup quick tiles should expose status text"
```

with:

```bash
grep -q 'function quickStatusText(action)' "$settings_popup" \
  || fail "SettingsMenuPopup should expose compact quick-control status text"
grep -q 'function selectedQuickAction()' "$settings_popup" \
  || fail "SettingsMenuPopup should choose status text with deterministic priority"
grep -q 'property string hoveredQuickAction: ""' "$settings_popup" \
  || fail "SettingsMenuPopup should track hovered quick controls"
grep -q 'property string focusedQuickAction: ""' "$settings_popup" \
  || fail "SettingsMenuPopup should track keyboard-focused quick controls"
grep -q 'property string lastQuickAction: ""' "$settings_popup" \
  || fail "SettingsMenuPopup should track recently toggled quick controls"
grep -q 'id: quickStatusReset' "$settings_popup" \
  || fail "SettingsMenuPopup should reset recently toggled status text"
grep -q 'StatusStrip {' "$settings_popup" \
  || fail "SettingsMenuPopup should render a compact status strip"
grep -q 'text: root.quickStatusText(root.selectedQuickAction())' "$settings_popup" \
  || fail "SettingsMenuPopup status strip should describe selected quick control state"
grep -q 'if (root.airplaneOn) return "Airplane Mode: On"' "$settings_popup" \
  || fail "SettingsMenuPopup status priority should make airplane mode explicit"
```

- [ ] **Step 5: Add assertions for compact route delegates and scrolling**

After the route/action assertions, add:

```bash
grep -q 'component SectionChip: Rectangle' "$settings_popup" \
  || fail "SettingsMenuPopup should render compact section chips"
grep -q 'component ActionChip: Rectangle' "$settings_popup" \
  || fail "SettingsMenuPopup should render compact action chips"
grep -q 'component ManageSegment: Rectangle' "$settings_popup" \
  || fail "SettingsMenuPopup should render compact manage segments"
grep -q 'id: detailFlickable' "$settings_popup" \
  || fail "SettingsMenuPopup detail pages should scroll inside the popup"
grep -q 'boundsBehavior: Flickable.StopAtBounds' "$settings_popup" \
  || fail "SettingsMenuPopup detail scrolling should stop at bounds"
grep -q 'height: actionAvailable ? 38 : 0' "$settings_popup" \
  || fail "SettingsMenuPopup action rows should use compact 38px chips"
grep -q 'function quickIconGlyph(icon)' "$settings_popup" \
  || fail "SettingsMenuPopup should map quick semantic icons to glyphs"
grep -q 'function actionIconGlyph(icon)' "$settings_popup" \
  || fail "SettingsMenuPopup should map action semantic icons to glyphs"
grep -q 'function sectionIconGlyph(page)' "$settings_popup" \
  || fail "SettingsMenuPopup should map section pages to glyphs"
```

- [ ] **Step 6: Run the updated static test and verify it fails on the old implementation**

Run:

```bash
tests/quickshell-topbar-settings-menus.sh
```

Expected: FAIL with the first new settings-menu assertion, such as:

```text
FAIL: SettingsMenuPopup should use the compact quickmenu width
```

- [ ] **Step 7: Commit the failing test**

Run:

```bash
git add tests/quickshell-topbar-settings-menus.sh
git commit -m "test: specify compact topbar quickmenu"
```

Expected: commit succeeds and only `tests/quickshell-topbar-settings-menus.sh` is committed.

---

### Task 2: Add Compact Geometry, Status Priority, And Icon Mapping

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`
- Test: `tests/quickshell-topbar-settings-menus.sh`

- [ ] **Step 1: Replace fixed drawer geometry with page-aware quickmenu geometry**

Near the top of `SettingsMenuPopup.qml`, replace:

```qml
  readonly property int menuWidth: 456
  readonly property int menuHeight: 520
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight + root.menuHeight
```

with:

```qml
  readonly property int menuWidth: 344
  readonly property int homeMenuHeight: 276
  readonly property int detailMenuHeight: 440
  readonly property int screenSafeMenuHeight: Math.max(
    root.homeMenuHeight,
    Math.min(root.detailMenuHeight, (root.screen ? root.screen.height : 900) - Theme.notchHeight - 18)
  )
  readonly property int targetMenuHeight: root.currentPage === "home" ? root.homeMenuHeight : root.screenSafeMenuHeight
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight + root.targetMenuHeight
```

- [ ] **Step 2: Add visual-only quick status state**

After `property int savedGapsOut: 10`, add:

```qml
  property string hoveredQuickAction: ""
  property string focusedQuickAction: ""
  property string lastQuickAction: ""
```

After the existing `focusLabelReset` timer, add:

```qml
  Timer {
    id: quickStatusReset
    interval: 2600
    repeat: false
    onTriggered: root.lastQuickAction = ""
  }
```

- [ ] **Step 3: Add quick icon, section icon, and action icon mapping helpers**

Place these functions after `bluetoothStatusText()` and before `quickActive(action)`:

```qml
  function quickIconGlyph(icon) {
    switch (icon) {
    case "wifi": return "󰤨"
    case "bluetooth": return "󰂯"
    case "airplane": return "󰀝"
    case "hotspot": return "󱜠"
    case "night": return "󰖔"
    case "focus": return "󰃟"
    case "dnd": return "󰂛"
    case "filter": return "󰈲"
    default: return "•"
    }
  }

  function sectionIconGlyph(page) {
    switch (page) {
    case "learn": return "󰑴"
    case "share": return "󰒟"
    case "style": return "󰏘"
    case "setup": return "󰒓"
    case "manage": return "󰏗"
    case "about": return "󰋼"
    default: return "•"
    }
  }

  function actionIconGlyph(icon) {
    switch (icon) {
    case "keys": return "󰌌"
    case "docs": return "󰈙"
    case "hypr": return "󱗼"
    case "arch": return "󰣇"
    case "editor": return "󰏫"
    case "terminal": return "󰆍"
    case "clipboard": return "󰅌"
    case "file": return "󰈔"
    case "folder": return "󰉋"
    case "palette": return "󰏘"
    case "type": return "󰬴"
    case "image": return "󰋩"
    case "text": return "󰉿"
    case "info": return "󰋼"
    case "audio": return "󰕾"
    case "wifi": return "󰤨"
    case "bluetooth": return "󰂯"
    case "power": return "󰐥"
    case "sleep": return "⏾"
    case "display": return "󰍹"
    case "dns": return "󰌘"
    case "shield": return "󰒃"
    case "sliders": return "󰒓"
    case "chip": return "󰘚"
    case "fingerprint": return "󰈷"
    case "key": return "󰌋"
    case "folder-cog": return "󱁿"
    case "default": return "󰘳"
    case "osd": return "󰍜"
    case "launcher": return "󰀻"
    case "keyboard": return "󰌌"
    case "gpu": return "󰢮"
    case "touchpad": return "󰟸"
    case "plus": return "+"
    case "minus": return "-"
    case "wrench": return "󰖷"
    case "package": return "󰏗"
    case "web": return "󰖟"
    case "service": return "󰒋"
    case "code": return "󰅩"
    case "ai": return "󰚩"
    case "windows": return "󰖳"
    case "game": return "󰊴"
    case "clean": return "󰃢"
    case "mic": return "󰍬"
    case "update": return "󰚰"
    case "branch": return "󰘬"
    case "refresh": return "󰑐"
    case "process": return "󰒋"
    case "hardware": return "󰘚"
    case "firmware": return "󰁰"
    case "globe": return "󰖟"
    case "clock": return "󰥔"
    case "rollback": return "󰦛"
    default: return "•"
    }
  }
```

- [ ] **Step 4: Add compact status helper functions**

Place these functions after `actionIconGlyph(icon)`:

```qml
  function quickStateText(action) {
    switch (action) {
    case "wifi-toggle": return root.wifiStatusText()
    case "bluetooth-toggle": return root.bluetoothStatusText()
    case "airplane-toggle": return root.airplaneOn ? "On" : "Off"
    case "hotspot-toggle": return root.hotspotLabel !== "" ? root.hotspotLabel : (root.hotspotOn ? "Active" : "Off")
    case "nightlight-toggle": return root.nightLightOn ? "On" : "Off"
    case "focus-toggle": return root.focusLabel !== "" ? root.focusLabel : (ShellState.focusMode ? "On" : "Off")
    case "dnd-toggle": return ShellState.dnd ? "On" : "Off"
    case "filter-open": return root.currentFilter !== "" ? root.currentFilter : "Off"
    default: return ""
    }
  }

  function quickLabel(action) {
    switch (action) {
    case "wifi-toggle": return "Wi-Fi"
    case "bluetooth-toggle": return "Bluetooth"
    case "airplane-toggle": return "Airplane Mode"
    case "hotspot-toggle": return "Hotspot"
    case "nightlight-toggle": return "Night Light"
    case "focus-toggle": return "Focus Mode"
    case "dnd-toggle": return "Do Not Disturb"
    case "filter-open": return "Filter"
    default: return "Quick Control"
    }
  }

  function selectedQuickAction() {
    if (root.hoveredQuickAction !== "") return root.hoveredQuickAction
    if (root.focusedQuickAction !== "") return root.focusedQuickAction
    if (root.lastQuickAction !== "") return root.lastQuickAction
    if (root.hotspotLabel !== "") return "hotspot-toggle"
    if (root.focusLabel !== "") return "focus-toggle"
    if (root.airplaneOn) return "airplane-toggle"
    if (root.currentFilter !== "") return "filter-open"
    if (root.wifiOn && !root.hotspotOn) return "wifi-toggle"
    if (root.btDevice !== "") return "bluetooth-toggle"
    return ""
  }

  function quickStatusText(action) {
    if (root.airplaneOn) return "Airplane Mode: On"
    if (action === "") return "Quick controls ready"

    var state = root.quickStateText(action)
    return root.quickLabel(action) + (state !== "" ? ": " + state : "")
  }
```

- [ ] **Step 5: Update quick action routing to preserve recently toggled status**

At the start of `runQuickAction(action)`, before the `switch`, add:

```qml
    root.lastQuickAction = action
    quickStatusReset.restart()
```

The function should begin:

```qml
  function runQuickAction(action) {
    root.lastQuickAction = action
    quickStatusReset.restart()

    switch (action) {
```

- [ ] **Step 6: Run static test and verify this task still fails on visual delegates**

Run:

```bash
tests/quickshell-topbar-settings-menus.sh
```

Expected: FAIL on a visual assertion that is not implemented yet, such as:

```text
FAIL: SettingsMenuPopup should render icon-first quick toggle buttons
```

- [ ] **Step 7: Commit geometry and helper functions**

Run:

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml
git commit -m "feat: add quickmenu status helpers"
```

Expected: commit succeeds with only `SettingsMenuPopup.qml`.

---

### Task 3: Replace The Home View With Icon Toggles, Status Strip, And Compact Section Chips

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`
- Test: `tests/quickshell-topbar-settings-menus.sh`

- [ ] **Step 1: Change card background and compact content margins**

In the `PopupShape` inside `id: card`, replace:

```qml
      color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.95)
```

with:

```qml
      color: Theme.background
```

In the content `Item` anchors below it, replace:

```qml
        topMargin: Theme.notchHeight + 10
        leftMargin: root.fw + 12
        rightMargin: root.fw + 12
        bottomMargin: 12
```

with:

```qml
        topMargin: Theme.notchHeight + 8
        leftMargin: root.fw + 10
        rightMargin: root.fw + 10
        bottomMargin: 10
```

In the outer content `Column`, replace `spacing: 10` with:

```qml
        spacing: 8
```

In the `header` item, replace `height: 42` with:

```qml
          height: 32
```

In the `pageStack` item, replace:

```qml
          height: parent.height - header.height - 10
```

with:

```qml
          height: parent.height - header.height - 8
```

- [ ] **Step 2: Add inline compact home components**

Add these inline components before the outside-click `MouseArea` near the bottom of the file:

```qml
  component QuickToggleButton: Rectangle {
    id: button

    required property string label
    required property string icon
    required property string action
    required property string glyph
    required property color accent
    property bool active: false

    signal activated(string action)
    signal hoverChanged(string action, bool hovered)
    signal focusChanged(string action, bool focused)

    width: 34
    height: 34
    radius: 8
    activeFocusOnTab: true

    color: toggleMouse.pressed ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, button.active ? 0.28 : 0.18)
                               : button.active ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.18)
                                               : toggleMouse.containsMouse || button.activeFocus ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.11)
                                                                                                  : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.035)
    border.width: 1
    border.color: button.active ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.46)
                                : toggleMouse.containsMouse || button.activeFocus ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.34)
                                                                                  : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.065)

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Rectangle {
      width: 4
      height: 4
      radius: 2
      anchors {
        top: parent.top
        right: parent.right
        topMargin: 5
        rightMargin: 5
      }
      color: button.accent
      opacity: button.active ? 0.95 : 0
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Text {
      anchors.centerIn: parent
      text: button.glyph
      color: button.active ? button.accent : Theme.text
      opacity: button.active ? 1 : 0.74
      font.pixelSize: 17
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
      id: toggleMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: button.hoverChanged(button.action, true)
      onExited: button.hoverChanged(button.action, false)
      onClicked: {
        button.forceActiveFocus()
        button.activated(button.action)
      }
    }

    onActiveFocusChanged: button.focusChanged(button.action, activeFocus)
    Keys.onReturnPressed: button.activated(button.action)
    Keys.onEnterPressed: button.activated(button.action)
    Keys.onSpacePressed: button.activated(button.action)
  }

  component StatusStrip: Rectangle {
    required property string text

    width: parent ? parent.width : 0
    height: 28
    radius: 7
    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.035)
    border.width: 1
    border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

    Text {
      anchors {
        left: parent.left
        right: parent.right
        verticalCenter: parent.verticalCenter
        leftMargin: 10
        rightMargin: 10
      }
      text: parent.text
      color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.68)
      font.pixelSize: 10
      elide: Text.ElideRight
      verticalAlignment: Text.AlignVCenter
    }
  }

  component SectionChip: Rectangle {
    id: chip

    required property string label
    required property string hint
    required property string page
    required property string glyph
    required property color accent

    signal opened(string page)

    width: 0
    height: 38
    radius: 7
    color: sectionMouse.pressed ? Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.17)
                                : sectionMouse.containsMouse ? Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.11)
                                                             : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.035)
    border.width: 1
    border.color: sectionMouse.containsMouse ? Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.33)
                                             : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

    Text {
      width: 22
      anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
        leftMargin: 8
      }
      text: chip.glyph
      color: chip.accent
      opacity: 0.86
      font.pixelSize: 14
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    Column {
      anchors {
        left: parent.left
        right: parent.right
        verticalCenter: parent.verticalCenter
        leftMargin: 34
        rightMargin: 8
      }
      spacing: 0

      Text {
        width: parent.width
        text: chip.label
        color: Theme.text
        font.pixelSize: 10
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        text: chip.hint
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
        font.pixelSize: 8
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: sectionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.opened(chip.page)
    }
  }
```

- [ ] **Step 3: Replace the old home quick grid and section grid**

Inside `Column { id: homePage ... }`, remove the `Text { text: "Control center" }`, the old `Grid { id: quickGrid ... }`, and the old `Grid { id: sectionGrid ... }`.

Replace them with:

```qml
            Row {
              id: quickToggleRail
              width: parent.width
              height: 34
              spacing: 7

              Repeater {
                model: quickControlsModel

                delegate: QuickToggleButton {
                  active: root.quickActive(action)
                  glyph: root.quickIconGlyph(icon)
                  accent: accent

                  onActivated: function(action) {
                    root.runQuickAction(action)
                  }
                  onHoverChanged: function(action, hovered) {
                    root.hoveredQuickAction = hovered ? action : (root.hoveredQuickAction === action ? "" : root.hoveredQuickAction)
                  }
                  onFocusChanged: function(action, focused) {
                    root.focusedQuickAction = focused ? action : (root.focusedQuickAction === action ? "" : root.focusedQuickAction)
                  }
                }
              }
            }

            StatusStrip {
              id: quickStatusStrip
              width: parent.width
              text: root.quickStatusText(root.selectedQuickAction())
            }

            Grid {
              id: sectionGrid
              width: parent.width
              columns: 2
              rowSpacing: 6
              columnSpacing: 6

              Repeater {
                model: nativeSectionsModel

                delegate: SectionChip {
                  width: (sectionGrid.width - sectionGrid.columnSpacing) / 2
                  glyph: root.sectionIconGlyph(page)
                  accent: accent
                  onOpened: function(page) {
                    root.openPage(page, "")
                  }
                }
              }
            }
```

- [ ] **Step 4: Run the static test and verify remaining failure is on detail components**

Run:

```bash
tests/quickshell-topbar-settings-menus.sh
```

Expected: FAIL on a detail-page assertion, such as:

```text
FAIL: SettingsMenuPopup should render compact action chips
```

- [ ] **Step 5: Commit the compact home view**

Run:

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml
git commit -m "feat: compact quickmenu home view"
```

Expected: commit succeeds with only `SettingsMenuPopup.qml`.

---

### Task 4: Replace Detail Pages With Scrolling Compact Chips And Segments

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`
- Test: `tests/quickshell-topbar-settings-menus.sh`

- [ ] **Step 1: Add compact detail components**

Add these inline components after `SectionChip`:

```qml
  component ManageSegment: Rectangle {
    id: segment

    required property string label
    required property string action
    required property color accent
    property bool selected: false

    signal activated(string action)

    width: 0
    height: 28
    radius: 7
    color: segmentMouse.pressed ? Qt.rgba(segment.accent.r, segment.accent.g, segment.accent.b, 0.20)
                                : segment.selected ? Qt.rgba(segment.accent.r, segment.accent.g, segment.accent.b, 0.15)
                                                   : segmentMouse.containsMouse ? Qt.rgba(segment.accent.r, segment.accent.g, segment.accent.b, 0.10)
                                                                                : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.035)
    border.width: 1
    border.color: segment.selected ? Qt.rgba(segment.accent.r, segment.accent.g, segment.accent.b, 0.42)
                                   : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

    Text {
      anchors.centerIn: parent
      text: segment.label
      color: segment.selected ? segment.accent : Theme.text
      font.pixelSize: 10
      font.bold: true
      elide: Text.ElideRight
    }

    MouseArea {
      id: segmentMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: segment.activated(segment.action)
    }
  }

  component ActionChip: Rectangle {
    id: chip

    required property string label
    required property string hint
    required property string icon
    required property string action
    required property string glyph
    required property color accent
    property bool actionAvailable: true

    signal activated(string action)

    width: 0
    height: actionAvailable ? 38 : 0
    visible: actionAvailable
    radius: 7
    color: actionMouse.pressed ? Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.18)
                               : actionMouse.containsMouse ? Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.11)
                                                           : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.035)
    border.width: 1
    border.color: actionMouse.containsMouse ? Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.34)
                                            : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

    Text {
      width: 22
      anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
        leftMargin: 8
      }
      text: chip.glyph
      color: chip.accent
      opacity: 0.86
      font.pixelSize: 14
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    Column {
      anchors {
        left: parent.left
        right: parent.right
        verticalCenter: parent.verticalCenter
        leftMargin: 34
        rightMargin: 8
      }
      spacing: 0

      Text {
        width: parent.width
        text: chip.label
        color: Theme.text
        font.pixelSize: 10
        font.bold: true
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        text: chip.hint
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
        font.pixelSize: 8
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: actionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: chip.activated(chip.action)
    }
  }
```

- [ ] **Step 2: Replace the old detail page column with segment tabs and a Flickable grid**

Replace the existing `Column { id: detailPage ... }` block with:

```qml
          Item {
            id: detailPage
            width: parent.width
            height: parent.height
            visible: root.currentPage !== "home"

            Row {
              id: manageTabs
              width: parent.width
              height: root.currentPage === "manage" && root.currentSubpage === "" ? 28 : 0
              spacing: 6
              visible: height > 0

              Repeater {
                model: manageTabsModel

                delegate: ManageSegment {
                  width: (manageTabs.width - manageTabs.spacing * 2) / 3
                  accent: accent
                  selected: root.manageTab === action.replace("manage-", "")
                  onActivated: function(action) {
                    root.runAction(action)
                  }
                }
              }
            }

            Flickable {
              id: detailFlickable
              anchors {
                left: parent.left
                right: parent.right
                top: manageTabs.visible ? manageTabs.bottom : parent.top
                bottom: parent.bottom
                topMargin: manageTabs.visible ? 7 : 0
              }
              contentWidth: width
              contentHeight: actionGrid.implicitHeight
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              Grid {
                id: actionGrid
                width: detailFlickable.width
                columns: 2
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                  model: root.pageModel()

                  delegate: ActionChip {
                    width: (actionGrid.width - actionGrid.columnSpacing) / 2
                    glyph: root.actionIconGlyph(icon)
                    accent: accent
                    actionAvailable: action === "maintain-rollback" ? root.rollbackAvailable : true
                    onActivated: function(action) {
                      root.runAction(action)
                    }
                  }
                }
              }
            }
          }
```

- [ ] **Step 3: Keep the filter picker overlay after the detail page**

Confirm `Rectangle { id: filterPicker ... }` remains a sibling inside `pageStack`, after `detailPage`, so filter selection still overlays both home and detail content.

The block should still start:

```qml
          Rectangle {
            id: filterPicker
            visible: root.filterPickerOpen
            z: 20
```

- [ ] **Step 4: Run the static test**

Run:

```bash
tests/quickshell-topbar-settings-menus.sh
```

Expected: PASS.

- [ ] **Step 5: Run QML lint when available**

Run:

```bash
qmllint -I config/quickshell/ryoku/vendor/brain-shell/src config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml
```

Expected: PASS, or command not found on systems without `qmllint`. If `qmllint` is missing, record that in the final task summary.

- [ ] **Step 6: Commit compact detail pages**

Run:

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml
git commit -m "feat: compact quickmenu detail pages"
```

Expected: commit succeeds with only `SettingsMenuPopup.qml`.

---

### Task 5: Verify Runtime Behavior And Refresh The Shell

**Files:**
- Modify: none expected
- Test: `tests/quickshell-topbar-settings-menus.sh`
- Test: `config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml`

- [ ] **Step 1: Run the focused static regression test**

Run:

```bash
tests/quickshell-topbar-settings-menus.sh
```

Expected:

```text
PASS: quickshell topbar settings menus
```

- [ ] **Step 2: Run the broader quickshell static checks that can catch popup regressions**

Run:

```bash
tests/brain-shell-spec1.sh
```

Expected:

```text
PASS: brain shell spec1
```

- [ ] **Step 3: Run QML lint**

Run:

```bash
qmllint -I config/quickshell/ryoku/vendor/brain-shell/src config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml
```

Expected: PASS, or command not found on systems without `qmllint`. If the command is missing, do not install packages in this task; note the skipped lint in the final summary.

- [ ] **Step 4: Refresh Quickshell from this checkout**

Run:

```bash
env RYOKU_PATH=/home/omi/prowl/ryoku-arch bin/ryoku-refresh-quickshell
```

Expected: command exits 0.

- [ ] **Step 5: Restart the shell**

Run:

```bash
bin/ryoku-restart-shell
```

Expected: command exits 0 and starts a new `quickshell` process.

- [ ] **Step 6: Open the quickmenu manually**

Run:

```bash
ryoku-ipc shell toggle settings-menu
```

Expected: the quickmenu opens from the right topbar notch. The home view shows one row of eight icon toggles, one compact status strip, and compact section chips. The background matches the topbar fill.

- [ ] **Step 7: Capture a screenshot for local visual inspection**

Run:

```bash
grim /tmp/ryoku-topbar-quickmenu.png
```

Expected: `/tmp/ryoku-topbar-quickmenu.png` exists and shows the compact quickmenu attached to the topbar.

- [ ] **Step 8: Exercise the main routes**

Run these one at a time:

```bash
ryoku-ipc shell settings-menu home
ryoku-ipc shell settings-menu share
ryoku-ipc shell settings-menu setup
ryoku-ipc shell settings-menu manage
ryoku-ipc shell settings-menu about
```

Expected: each route opens inside the same topbar-attached surface. Long route content scrolls inside the popup.

- [ ] **Step 9: Commit verification-only changes if any were generated intentionally**

If no tracked files changed during verification, do not commit. If a tracked file changed because of a necessary verification fix, commit only that file:

```bash
git add config/quickshell/ryoku/vendor/brain-shell/src/popups/SettingsMenuPopup.qml tests/quickshell-topbar-settings-menus.sh
git commit -m "fix: verify compact quickmenu"
```

Expected: commit only exists when a code or test fix was needed after verification.

---

## Self-Review Checklist

- Spec coverage:
  - Compact right-topbar attachment: Tasks 1, 2, 3, and 5.
  - Icon-first quick toggles: Tasks 1 and 3.
  - Compact status strip with deterministic priority: Tasks 1, 2, and 3.
  - Airplane Mode explicit status: Tasks 1 and 2.
  - Deeper menus matching compact topbar style: Tasks 1 and 4.
  - Internal scrolling for long routes: Tasks 1 and 4.
  - Existing IPC, keybindings, and action routing preserved: Tasks 1, 2, 4, and 5.
  - Static and runtime verification: Tasks 1, 4, and 5.
- Placeholder scan:
  - No vague implementation steps.
  - Every code-changing step includes the concrete code or exact replacement.
- Type consistency:
  - `QuickToggleButton`, `StatusStrip`, `SectionChip`, `ActionChip`, and `ManageSegment` are defined before use.
  - `quickIconGlyph`, `sectionIconGlyph`, `actionIconGlyph`, `quickStateText`, `quickLabel`, `selectedQuickAction`, and `quickStatusText` are defined before delegate usage.
  - Test assertions match the property and component names used in the QML snippets.
