# Dynamic Island Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static topbar center island with a state-driven Dynamic Island (idle / recording / music / timer / screenshot toast / voice search) and add a Mod+S full-bar Tools Mode hosting Ryoku's existing quicktools plus Lens, music recognition, and caffeine.

**Architecture:** A new `RyokuDynamicIsland.qml` orchestrator computes `activeState` from existing service singletons (`RecorderStatus`, `MprisController`, `VoiceSearch`, `TimerService`) using strict precedence; a `Loader` swaps the corresponding pill component. The existing `Behavior on centerNotchWidth` `OutBack` animation drives the morph for free. Mod+S routes through `ryoku-shell` to flip a new `GlobalStates.toolsModeOpen` flag, which animates the three islands closed and grows a wide tools pill.

**Tech Stack:** QML / Quickshell / Qt6, niri keybinds, bash IPC scripts, cava CLI for waveform.

---

## File structure

**New (under `shell/modules/bar/threeIsland/dynamicIsland/`):**
- `RyokuDynamicIsland.qml` - orchestrator + state machine
- `pills/IdleStatePill.qml` - wraps current clock + weather + date stack
- `pills/RecordingStatePill.qml`
- `pills/MusicStatePill.qml`
- `pills/TimerStatePill.qml`
- `pills/ScreenshotToastPill.qml`
- `pills/VoiceSearchPill.qml`
- `tools/RyokuToolsMode.qml` - the wide Mod+S pill
- `tools/ToolButton.qml` - circular tool button
- `tools/ToolRegistry.qml` - QML singleton mapping tool ids to action lambdas + icon + label
- `CavaWaveform.qml` - reusable visualizer

**New (under `shell/services/`):**
- `Cava.qml` - cava CLI wrapper singleton
- `ScreenshotEvents.qml` - emits `toastVisible` + IpcHandler

**Modified:**
- `shell/GlobalStates.qml` - add `toolsModeOpen` flag
- `shell/modules/common/Config.qml` - add `bar.dynamicIsland` JsonObject
- `shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml` - swap CenterIsland for DynamicIsland; add tools-mode logic
- `shell/modules/bar/Media.qml` - continuous-expansion popup positioning
- `shell/modules/mediaControls/BarMediaPopup.qml` - flatten top corners in continuous mode
- `shell/modules/bar/UtilButtons.qml` - read from `ToolRegistry.qml`
- `shell/modules/settings/BarConfig.qml` - new "Dynamic Island" section
- `shell/scripts/ryoku-shell` - new `tools-mode` subcommand
- `config/niri/config.d/70-binds.kdl` - Mod+S bind
- `tests/` - one new bash test file per phase to smoke-check the IPC + schema

**Singleton registration:** Quickshell auto-discovers `pragma Singleton` files in their parent qmldir-scoped folders. New singletons under `shell/services/` are picked up by the existing `qs.services` import (verified by listing existing singletons - they need only the `pragma Singleton` line and being in the imported path).

---

## Conventions used in this plan

- All commits use simple titles, no `Co-Authored-By` trailers, no em-dashes anywhere in committed content (pre-commit hook enforces both).
- All file paths in committed content use `$HOME` / `$RYOKU_PATH` / runtime discovery, never `/home/<user>` literal.
- Live-reload after a QML change: run `bin/ryoku-refresh-quickshell` (it execs `ryoku-shell repair`).
- Syntax-check after a QML edit: `/usr/bin/qmllint <path>` and expect zero output.
- Visual smoke check: run `bin/ryoku-refresh-quickshell`, then look at the bar.

---

## Phase 1: Plumbing

Goal: orchestrator wired up rendering only the existing idle content. No visible change.

### Task 1.1: Add `toolsModeOpen` to GlobalStates

**Files:**
- Modify: `shell/GlobalStates.qml`

- [ ] **Step 1: Read the file to find a good insertion point**

```bash
grep -n "mediaControlsOpen\|sidebarRightOpen" shell/GlobalStates.qml
```
Expected: shows the existing flag block.

- [ ] **Step 2: Add the flag**

In `shell/GlobalStates.qml`, after the line `property bool mediaControlsOpen: false`, add:

```qml
    property bool toolsModeOpen: false
```

- [ ] **Step 3: Verify**

```bash
/usr/bin/qmllint shell/GlobalStates.qml
grep -n "toolsModeOpen" shell/GlobalStates.qml
```
Expected: zero qmllint output, grep shows the new line.

- [ ] **Step 4: Commit**

```bash
git add shell/GlobalStates.qml
git commit -m "feat(GlobalStates): toolsModeOpen flag for Dynamic Island tools mode"
```

---

### Task 1.2: Add `bar.dynamicIsland` Config schema

**Files:**
- Modify: `shell/modules/common/Config.qml`

- [ ] **Step 1: Find insertion point**

```bash
grep -n "property JsonObject utilButtons:" shell/modules/common/Config.qml
```
Expected: shows the line. We will insert directly before it (so `dynamicIsland` sits next to `utilButtons` in the schema).

- [ ] **Step 2: Insert the schema**

In `shell/modules/common/Config.qml`, immediately before `property JsonObject utilButtons: JsonObject {`, paste:

```qml
                property JsonObject dynamicIsland: JsonObject {
                    property bool enabled: true

                    property JsonObject states: JsonObject {
                        property bool voiceSearch: true
                        property bool recording: true
                        property bool timer: true
                        property bool screenshotToast: true
                        property bool music: true
                    }

                    // Highest to lowest. Empty = built-in default.
                    property list<string> statePrecedence: [
                        "voiceSearch", "recording", "timer", "screenshotToast", "music"
                    ]

                    property JsonObject tools: JsonObject {
                        property bool enabled: true
                        property string keybind: "Mod+S"  // documentation only
                        property list<string> order: [
                            "screenshot", "record", "lens", "colorPicker", "musicRecognize",
                            "micToggle", "osk",
                            "DIVIDER",
                            "caffeine", "notepad", "screenCast", "darkMode", "powerProfile"
                        ]
                        property JsonObject buttons: JsonObject {
                            property bool screenshot: true
                            property bool record: true
                            property bool lens: true
                            property bool colorPicker: true
                            property bool musicRecognize: true
                            property bool micToggle: true
                            property bool osk: true
                            property bool caffeine: true
                            property bool notepad: true
                            property bool screenCast: false
                            property bool darkMode: true
                            property bool powerProfile: false
                        }
                        property bool autoCloseAfterAction: true
                        property bool closeOnEsc: true
                    }

                    property bool musicPopupContinuous: true
                }
```

- [ ] **Step 3: Verify**

```bash
/usr/bin/qmllint shell/modules/common/Config.qml
grep -c "dynamicIsland" shell/modules/common/Config.qml
```
Expected: zero qmllint output, grep shows count >= 2.

- [ ] **Step 4: Live-reload and confirm no errors**

```bash
bin/ryoku-refresh-quickshell
```
Expected: shell restarts cleanly, bar still renders.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/common/Config.qml
git commit -m "feat(Config): bar.dynamicIsland schema (states, precedence, tools)"
```

---

### Task 1.3: Create `IdleStatePill.qml`

**Files:**
- Create: `shell/modules/bar/threeIsland/dynamicIsland/pills/IdleStatePill.qml`

- [ ] **Step 1: Create the dir**

```bash
mkdir -p shell/modules/bar/threeIsland/dynamicIsland/pills
mkdir -p shell/modules/bar/threeIsland/dynamicIsland/tools
```

- [ ] **Step 2: Write the file**

Path: `shell/modules/bar/threeIsland/dynamicIsland/pills/IdleStatePill.qml`

```qml
import qs.modules.bar.threeIsland
import QtQuick

// Idle state of the Dynamic Island. Wraps the existing center island
// content (kanji clock + weather + date stack) so behavior is unchanged.
Item {
    id: root
    implicitWidth: inner.implicitWidth
    implicitHeight: inner.implicitHeight

    RyokuCenterIsland {
        id: inner
        anchors.fill: parent
    }
}
```

- [ ] **Step 3: Lint**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/pills/IdleStatePill.qml
```
Expected: zero output.

- [ ] **Step 4: Commit**

```bash
git add shell/modules/bar/threeIsland/dynamicIsland/pills/IdleStatePill.qml
git commit -m "feat(bar/dynamicIsland): IdleStatePill wraps RyokuCenterIsland"
```

---

### Task 1.4: Create `RyokuDynamicIsland.qml` orchestrator (idle-only)

**Files:**
- Create: `shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml`

- [ ] **Step 1: Write the file**

Path: `shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml`

```qml
import qs
import qs.services
import qs.modules.common
import qs.modules.bar.threeIsland.dynamicIsland.pills
import QtQuick

// Computes activeState from service singletons + Config flags. Loads the
// matching pill component. Phase 1: only "idle" is wired up; later phases
// add the others.
Item {
    id: root
    implicitWidth: pillLoader.item ? pillLoader.item.implicitWidth : 0
    implicitHeight: Appearance.sizes.barHeight

    readonly property bool islandEnabled: Config.options?.bar?.dynamicIsland?.enabled ?? true

    // Phase 1: only idle. Future phases extend this.
    readonly property string activeState: "idle"

    Loader {
        id: pillLoader
        anchors.fill: parent
        active: root.islandEnabled
        sourceComponent: root.activeState === "idle" ? idleComponent : null
    }

    Component { id: idleComponent; IdleStatePill {} }
}
```

- [ ] **Step 2: Lint**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml
```
Expected: zero output.

- [ ] **Step 3: Commit**

```bash
git add shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml
git commit -m "feat(bar/dynamicIsland): RyokuDynamicIsland orchestrator (idle-only)"
```

---

### Task 1.5: Wire `RyokuDynamicIsland` into `RyokuThreeIslandContent`

**Files:**
- Modify: `shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml`

- [ ] **Step 1: Read current state**

```bash
grep -n "RyokuCenterIsland" shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml
```
Expected: 3 hits (`centerSizer`, mounted `RyokuCenterIsland` inside `centerNotch`, and the `import` if present).

- [ ] **Step 2: Replace `RyokuCenterIsland` mounts with `RyokuDynamicIsland`**

In `shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml`:

Add the import block near the top (alphabetically next to `import qs.modules.bar`):

```qml
import qs.modules.bar.threeIsland.dynamicIsland
```

Replace the `centerSizer` block:

```qml
    RyokuCenterIsland {
        id: centerSizer
        visible: false
    }
```

with:

```qml
    RyokuDynamicIsland {
        id: centerSizer
        visible: false
    }
```

Replace the mounted `RyokuCenterIsland` inside `centerNotch`:

```qml
        RyokuCenterIsland {
            anchors.fill: parent
        }
```

with:

```qml
        RyokuDynamicIsland {
            anchors.fill: parent
        }
```

- [ ] **Step 3: Lint**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml
```
Expected: zero output.

- [ ] **Step 4: Live-reload and confirm idle bar still renders identically**

```bash
bin/ryoku-refresh-quickshell
```
Expected: clock + weather + date appear unchanged in the center island.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml
git commit -m "feat(bar/threeIsland): mount RyokuDynamicIsland in centerNotch"
```

---

## Phase 2: Recording state

Goal: when wf-recorder runs, the center morphs into a red pill with elapsed time. Click stops recording.

### Task 2.1: Create `RecordingStatePill.qml`

**Files:**
- Create: `shell/modules/bar/threeIsland/dynamicIsland/pills/RecordingStatePill.qml`

- [ ] **Step 1: Write the file**

Path: `shell/modules/bar/threeIsland/dynamicIsland/pills/RecordingStatePill.qml`

```qml
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

// Red gradient pill with pulsing dot and elapsed time. Click stops recording,
// right-click opens the Recorder overlay.
Item {
    id: root
    implicitWidth: row.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight

    readonly property color colError: Appearance.ryokuEverywhere
        ? Appearance.ryoku.colError ?? Appearance.colors.colError
        : Appearance.colors.colError

    Rectangle {
        id: pill
        anchors.fill: parent
        anchors.margins: 4
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(root.colError.r, root.colError.g, root.colError.b, 0.10) }
            GradientStop { position: 1.0; color: Qt.rgba(root.colError.r, root.colError.g, root.colError.b, 0.20) }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Rectangle {
            id: dot
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 8
            implicitHeight: 8
            radius: 4
            color: root.colError

            SequentialAnimation on opacity {
                running: RecorderStatus.isRecording && Appearance.animationsEnabled
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 500 }
                NumberAnimation { to: 1.0; duration: 500 }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: "REC"
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            color: root.colError
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: {
                const s = RecorderStatus.elapsedSeconds
                const mm = String(Math.floor(s / 60)).padStart(2, "0")
                const ss = String(s % 60).padStart(2, "0")
                return mm + ":" + ss
            }
            font.pixelSize: Appearance.font.pixelSize.small
            font.family: "monospace"
            color: Appearance.colors.colOnLayer1
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                Quickshell.execDetached(["/usr/bin/pkill", "-SIGINT", "wf-recorder"])
            } else if (event.button === Qt.RightButton) {
                GlobalStates.overlayOpen = true
            }
        }

        StyledToolTip { text: Translation.tr("Recording - click to stop, right-click for options") }
    }
}
```

- [ ] **Step 2: Lint**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/pills/RecordingStatePill.qml
```
Expected: zero output.

- [ ] **Step 3: Commit**

```bash
git add shell/modules/bar/threeIsland/dynamicIsland/pills/RecordingStatePill.qml
git commit -m "feat(bar/dynamicIsland): RecordingStatePill (red pill, elapsed time)"
```

---

### Task 2.2: Wire recording state into orchestrator

**Files:**
- Modify: `shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml`

- [ ] **Step 1: Replace the activeState computation**

Replace the line:

```qml
    readonly property string activeState: "idle"
```

with:

```qml
    readonly property string activeState: {
        const di = Config.options?.bar?.dynamicIsland;
        if (!di?.enabled) return "idle";
        if ((di?.states?.recording ?? true) && RecorderStatus.isRecording) return "recording";
        return "idle";
    }
```

- [ ] **Step 2: Add a `_componentFor` function and the recording component**

Inside `RyokuDynamicIsland`, immediately after the `activeState` property, add the lookup function:

```qml
    function _componentFor(state) {
        switch (state) {
            case "recording": return recordingComponent;
            case "idle":
            default:          return idleComponent;
        }
    }
```

After the existing `Component { id: idleComponent; ... }` line, add:

```qml
    Component { id: recordingComponent; RecordingStatePill {} }
```

Replace the existing `pillLoader.sourceComponent` line:

```qml
        sourceComponent: root.activeState === "idle" ? idleComponent : null
```

with:

```qml
        sourceComponent: root._componentFor(root.activeState)
```

- [ ] **Step 3: Lint and live-reload**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml
bin/ryoku-refresh-quickshell
```
Expected: zero qmllint output, shell restarts cleanly.

- [ ] **Step 4: Smoke test**

```bash
ryoku-shell region recordWithSound
```
After the region selector, start a recording. The center island should morph red within ~320ms. Click the pill - the recording should stop and the island should morph back.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml
git commit -m "feat(bar/dynamicIsland): wire recording state into orchestrator"
```

---

## Phase 3: Music + CAVA

Goal: when MPRIS reports playing, morph into a blue pill with CAVA waveform + scrolling title. Click toggles play/pause; click while playing opens BarMediaPopup that visually expands DOWN from the island.

### Task 3.1: Create `Cava.qml` singleton

**Files:**
- Create: `shell/services/Cava.qml`

- [ ] **Step 1: Write the file**

Path: `shell/services/Cava.qml`

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Wraps the cava CLI in raw output mode. Exposes `bars` (7 floats 0-1).
// Started/stopped on demand to avoid CPU cost when idle.
Singleton {
    id: root

    property int barCount: 7
    property var bars: Array(barCount).fill(0)
    property bool active: cavaProc.running
    property bool unavailable: false  // true if cava binary missing

    function start() {
        if (root.unavailable) return;
        if (!cavaProc.running) cavaProc.running = true;
    }

    function stop() {
        if (cavaProc.running) cavaProc.running = false;
        bars = Array(barCount).fill(0);
    }

    Process {
        id: probeProc
        command: ["/usr/bin/sh", "-c", "command -v cava >/dev/null 2>&1"]
        onExited: (exitCode) => { root.unavailable = (exitCode !== 0) }
    }

    Component.onCompleted: probeProc.running = true

    Process {
        id: cavaProc
        running: false
        // Raw 8-bit output, capped at 60fps, 7 bars. cava reads its config from
        // a file generated at startup.
        command: ["/usr/bin/sh", "-c", `
            cfg=$(mktemp)
            cat > "$cfg" <<EOF
[general]
bars = ${root.barCount}
framerate = 30

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
EOF
            exec cava -p "$cfg"
        `]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const parts = line.split(";").filter(s => s.length > 0);
                if (parts.length !== root.barCount) return;
                const next = [];
                for (let i = 0; i < parts.length; i++) {
                    const v = parseInt(parts[i], 10);
                    next.push(Number.isFinite(v) ? Math.max(0, Math.min(1, v / 100.0)) : 0);
                }
                root.bars = next;
            }
        }
    }
}
```

- [ ] **Step 2: Lint**

```bash
/usr/bin/qmllint shell/services/Cava.qml
```
Expected: zero output.

- [ ] **Step 3: Commit**

```bash
git add shell/services/Cava.qml
git commit -m "feat(services/Cava): cava CLI singleton with on-demand start/stop"
```

---

### Task 3.2: Create `CavaWaveform.qml` reusable widget

**Files:**
- Create: `shell/modules/bar/threeIsland/dynamicIsland/CavaWaveform.qml`

- [ ] **Step 1: Write the file**

Path: `shell/modules/bar/threeIsland/dynamicIsland/CavaWaveform.qml`

```qml
import qs.services
import QtQuick

// Renders Cava.bars as N rounded vertical bars. Tweens height changes for
// smoothness even when cava emits at variable rate.
Row {
    id: root
    spacing: 2

    property real maxBarHeight: 18
    property real minBarHeight: 2
    property real barWidth: 3
    property color barColor: "#7ac"

    implicitWidth: (root.barWidth + root.spacing) * Cava.barCount - root.spacing
    implicitHeight: root.maxBarHeight

    Repeater {
        model: Cava.barCount
        delegate: Rectangle {
            required property int index
            anchors.bottom: parent.bottom
            width: root.barWidth
            height: Math.max(root.minBarHeight, (Cava.bars[index] ?? 0) * root.maxBarHeight)
            radius: width / 2
            color: root.barColor

            Behavior on height {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
            }
        }
    }
}
```

- [ ] **Step 2: Lint and commit**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/CavaWaveform.qml
git add shell/modules/bar/threeIsland/dynamicIsland/CavaWaveform.qml
git commit -m "feat(bar/dynamicIsland): CavaWaveform widget"
```

---

### Task 3.3: Create `MusicStatePill.qml`

**Files:**
- Create: `shell/modules/bar/threeIsland/dynamicIsland/pills/MusicStatePill.qml`

- [ ] **Step 1: Write the file**

Path: `shell/modules/bar/threeIsland/dynamicIsland/pills/MusicStatePill.qml`

```qml
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar.threeIsland.dynamicIsland
import QtQuick
import QtQuick.Layouts

// Blue pill with CAVA waveform + scrolling track title. Click toggles play/pause.
// Right-click opens BarMediaPopup (handled by Media.qml separately).
Item {
    id: root
    implicitWidth: row.implicitWidth + 28
    implicitHeight: Appearance.sizes.barHeight

    readonly property color colPrimary: Appearance.ryokuEverywhere
        ? (Appearance.ryoku.colPrimary ?? Appearance.colors.colPrimary)
        : Appearance.colors.colPrimary

    Component.onCompleted: Cava.start()
    Component.onDestruction: Cava.stop()

    Rectangle {
        id: pill
        anchors.fill: parent
        anchors.margins: 4
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.12) }
            GradientStop { position: 1.0; color: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.20) }
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10

        CavaWaveform {
            Layout.alignment: Qt.AlignVCenter
            barColor: root.colPrimary
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 160
            elide: Text.ElideRight
            text: {
                const t = MprisController.activeTrack?.title ?? ""
                const a = MprisController.activeTrack?.artist ?? ""
                return a.length > 0 ? (t + " - " + a) : t
            }
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                MprisController.togglePlaying()
            }
            // right-click handled by parent Media.qml (popup)
        }

        StyledToolTip {
            text: {
                const t = MprisController.activeTrack;
                if (!t) return "";
                return (t.title || "") + (t.artist ? "\n" + t.artist : "") + (t.album ? "\n" + t.album : "");
            }
        }
    }
}
```

- [ ] **Step 2: Lint and commit**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/pills/MusicStatePill.qml
git add shell/modules/bar/threeIsland/dynamicIsland/pills/MusicStatePill.qml
git commit -m "feat(bar/dynamicIsland): MusicStatePill (CAVA + scrolling title)"
```

---

### Task 3.4: Wire music state into orchestrator + add precedence

**Files:**
- Modify: `shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml`

- [ ] **Step 1: Update activeState to include music**

Replace the `activeState` property with:

```qml
    readonly property string activeState: {
        const di = Config.options?.bar?.dynamicIsland;
        if (!di?.enabled) return "idle";
        if ((di?.states?.recording ?? true) && RecorderStatus.isRecording) return "recording";
        if ((di?.states?.music ?? true) && MprisController.isPlaying) return "music";
        return "idle";
    }
```

- [ ] **Step 2: Add the music component and route**

Add after the `recordingComponent`:

```qml
    Component { id: musicComponent; MusicStatePill {} }
```

Update `_componentFor`:

```qml
    function _componentFor(state) {
        switch (state) {
            case "recording": return recordingComponent;
            case "music":     return musicComponent;
            case "idle":
            default:          return idleComponent;
        }
    }
```

- [ ] **Step 3: Add the import**

At the top of the file, add:

```qml
import qs.modules.bar.threeIsland.dynamicIsland.pills
```

(if not already present from earlier tasks)

- [ ] **Step 4: Lint, live-reload, smoke test**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml
bin/ryoku-refresh-quickshell
```

Play music in Spotify or `mpv some-track.mp3`. The center island should morph blue, show CAVA bars, and the title.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml
git commit -m "feat(bar/dynamicIsland): wire music state with recording precedence"
```

---

### Task 3.5: Continuous-expansion popup for music

**Files:**
- Modify: `shell/modules/bar/Media.qml`
- Modify: `shell/modules/mediaControls/BarMediaPopup.qml`

- [ ] **Step 1: Update `Media.qml` popup anchoring**

Find the existing `barMediaPopupLoader` block (search for `id: barMediaPopupLoader`). The internal `PopupWindow` already uses `edges: Edges.Bottom` when bar is at top. Add a binding for `gap = 0` and pass `continuous = true` down to BarMediaPopup.

Locate the `BarMediaPopup` instantiation inside `Media.qml`:

```qml
            BarMediaPopup {
                id: mediaPopupContent
                anchors.centerIn: parent
                onCloseRequested: root.barMediaPopupVisible = false
                ...
            }
```

Replace with:

```qml
            BarMediaPopup {
                id: mediaPopupContent
                anchors.centerIn: parent
                onCloseRequested: root.barMediaPopupVisible = false
                continuous: Config.options?.bar?.dynamicIsland?.musicPopupContinuous ?? true
                barAtBottom: Config.options?.bar?.bottom ?? false
                ...
            }
```

For the surrounding `PopupWindow`, ensure no margin between popup and bar. Find the `implicitWidth` / `implicitHeight` lines and just below them add:

```qml
                margins {
                    top: 0
                    bottom: 0
                }
```

If `margins` already exists, ensure both `top` and `bottom` are 0 when `continuous` is true.

- [ ] **Step 2: Update `BarMediaPopup.qml` to accept the props and flatten corners**

Open `shell/modules/mediaControls/BarMediaPopup.qml`. Near the top of the root item add:

```qml
    property bool continuous: false
    property bool barAtBottom: false
```

Find the outermost rounded `Rectangle` (the popup background). It will have a `radius` property. Replace it with corner-specific radii. Example pattern:

```qml
        topLeftRadius: continuous && !barAtBottom ? 0 : Appearance.rounding.normal
        topRightRadius: continuous && !barAtBottom ? 0 : Appearance.rounding.normal
        bottomLeftRadius: continuous && barAtBottom ? 0 : Appearance.rounding.normal
        bottomRightRadius: continuous && barAtBottom ? 0 : Appearance.rounding.normal
```

(If the existing rectangle uses just `radius`, replace it with the four-corner properties. Qt 6.7+ supports them on `Rectangle`.)

- [ ] **Step 3: Lint and live-reload**

```bash
/usr/bin/qmllint shell/modules/bar/Media.qml
/usr/bin/qmllint shell/modules/mediaControls/BarMediaPopup.qml
bin/ryoku-refresh-quickshell
```

- [ ] **Step 4: Smoke test**

Click the music pill while playing. The popup should appear directly attached to the bar with zero gap, and its top corners flat (so it visually merges with the island).

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/Media.qml shell/modules/mediaControls/BarMediaPopup.qml
git commit -m "feat(media): continuous-expansion popup attached to Dynamic Island"
```

---

## Phase 4: Timer + Screenshot toast + Voice search

### Task 4.1: Create `TimerStatePill.qml`

**Files:**
- Create: `shell/modules/bar/threeIsland/dynamicIsland/pills/TimerStatePill.qml`

- [ ] **Step 1: Write the file**

```qml
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: row.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight

    readonly property color colAmber: "#ffa500"

    readonly property int secondsLeft: {
        if (TimerService.pomodoroRunning)  return TimerService.pomodoroSecondsLeft;
        if (TimerService.countdownRunning) return TimerService.countdownSecondsLeft;
        if (TimerService.stopwatchRunning) return TimerService.stopwatchSecondsLeft ?? 0;
        return 0;
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: height / 2
        color: Qt.rgba(1, 0.65, 0, 0.14)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 18
            implicitHeight: 18
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                border.width: 2
                border.color: root.colAmber
                color: "transparent"
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: {
                const s = root.secondsLeft;
                const mm = String(Math.floor(s / 60)).padStart(2, "0")
                const ss = String(s % 60).padStart(2, "0")
                return mm + ":" + ss
            }
            font.pixelSize: Appearance.font.pixelSize.small
            font.family: "monospace"
            color: Appearance.colors.colOnLayer1
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: {
            // Open existing Timer popup pattern - reuse TimerIndicator's click
            GlobalStates.sidebarRightOpen = true
            Persistent.states.sidebar.bottomGroup.collapsed = false
            Persistent.states.sidebar.bottomGroup.tab = 3
        }
        StyledToolTip { text: Translation.tr("Timer running - click for controls") }
    }
}
```

- [ ] **Step 2: Lint and commit**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/pills/TimerStatePill.qml
git add shell/modules/bar/threeIsland/dynamicIsland/pills/TimerStatePill.qml
git commit -m "feat(bar/dynamicIsland): TimerStatePill (amber ring + remaining)"
```

---

### Task 4.2: Create `ScreenshotEvents.qml` singleton + IpcHandler

**Files:**
- Create: `shell/services/ScreenshotEvents.qml`

- [ ] **Step 1: Write the file**

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool toastVisible: false
    property string toastText: ""
    property string lastFilePath: ""

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: root.toastVisible = false
    }

    function show(text: string, path: string): void {
        root.toastText = text;
        root.lastFilePath = path;
        root.toastVisible = true;
        hideTimer.restart();
    }

    IpcHandler {
        target: "screenshotEvents"
        function captured(text: string, path: string): void {
            root.show(text, path);
        }
    }
}
```

- [ ] **Step 2: Lint and commit**

```bash
/usr/bin/qmllint shell/services/ScreenshotEvents.qml
git add shell/services/ScreenshotEvents.qml
git commit -m "feat(services/ScreenshotEvents): toast singleton + IpcHandler"
```

---

### Task 4.3: Create `ScreenshotToastPill.qml`

**Files:**
- Create: `shell/modules/bar/threeIsland/dynamicIsland/pills/ScreenshotToastPill.qml`

- [ ] **Step 1: Write the file**

```qml
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: row.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight

    readonly property color colSuccess: "#7fcc7f"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: height / 2
        color: Qt.rgba(0.5, 0.8, 0.5, 0.16)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: "✓"
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.DemiBold
            color: root.colSuccess
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: ScreenshotEvents.toastText
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: event => {
            const path = ScreenshotEvents.lastFilePath
            if (!path) return;
            if (event.button === Qt.LeftButton) {
                Qt.openUrlExternally("file://" + path)
            } else if (event.button === Qt.RightButton) {
                const dir = path.substring(0, path.lastIndexOf("/"))
                Qt.openUrlExternally("file://" + dir)
            }
        }
    }
}
```

- [ ] **Step 2: Lint and commit**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/pills/ScreenshotToastPill.qml
git add shell/modules/bar/threeIsland/dynamicIsland/pills/ScreenshotToastPill.qml
git commit -m "feat(bar/dynamicIsland): ScreenshotToastPill (auto-fade success toast)"
```

---

### Task 4.4: Hook the screenshot pipeline to fire the IPC

**Files:**
- Modify: `shell/scripts/ryoku-shell` (find the screenshot handler) OR
- Modify: the region-selector `grim` invocation in `RegionSelection.qml`

- [ ] **Step 1: Find the screenshot completion site**

```bash
grep -rn "wl-copy\|grim.*-\|screenshot" shell/scripts/ryoku-shell shell/modules/regionSelector/ 2>/dev/null | head -10
```

- [ ] **Step 2: Add IPC fire after a successful capture**

Wherever `grim ... | wl-copy` runs (likely a `Process` in `RegionSelection.qml`), in the `onExited` handler add:

```qml
onExited: (exitCode) => {
    if (exitCode === 0) {
        Quickshell.execDetached(["/usr/bin/sh", "-c",
            "command -v quickshell >/dev/null && quickshell ipc call screenshotEvents captured 'Copied to clipboard' '' || true"])
    }
}
```

For grim runs that save to file (with a path arg), pass that path as the second IPC arg.

- [ ] **Step 3: Smoke test**

Trigger a region screenshot (Mod+Shift+S). After the capture, the center island should briefly morph green with "✓ Copied to clipboard" for 2s.

- [ ] **Step 4: Commit**

```bash
git add shell/modules/regionSelector/RegionSelection.qml
git commit -m "feat(regionSelector): fire screenshotEvents IPC after capture"
```

---

### Task 4.5: Create `VoiceSearchPill.qml`

**Files:**
- Create: `shell/modules/bar/threeIsland/dynamicIsland/pills/VoiceSearchPill.qml`

- [ ] **Step 1: Write the file**

```qml
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar.threeIsland.dynamicIsland
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitWidth: row.implicitWidth + 24
    implicitHeight: Appearance.sizes.barHeight

    readonly property color colVoice: Appearance.ryokuEverywhere
        ? (Appearance.ryoku.colSecondary ?? "#c090e0")
        : (Appearance.colors.colSecondary ?? "#c090e0")

    Component.onCompleted: Cava.start()
    Component.onDestruction: Cava.stop()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: height / 2
        color: Qt.rgba(root.colVoice.r, root.colVoice.g, root.colVoice.b, 0.16)
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: "🎤"
            font.pixelSize: Appearance.font.pixelSize.normal
        }

        CavaWaveform {
            Layout.alignment: Qt.AlignVCenter
            barColor: root.colVoice
            barWidth: 2
            maxBarHeight: 14
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: Translation.tr("Listening")
            font.pixelSize: Appearance.font.pixelSize.smaller
            opacity: 0.7
            color: Appearance.colors.colOnLayer1
        }
    }

    MouseArea {
        anchors.fill: parent
        onPressed: VoiceSearch.stop()
        StyledToolTip { text: Translation.tr("Listening - click to cancel") }
    }
}
```

- [ ] **Step 2: Lint and commit**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/pills/VoiceSearchPill.qml
git add shell/modules/bar/threeIsland/dynamicIsland/pills/VoiceSearchPill.qml
git commit -m "feat(bar/dynamicIsland): VoiceSearchPill (purple listening waveform)"
```

---

### Task 4.6: Wire all three states into orchestrator with full precedence

**Files:**
- Modify: `shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml`

- [ ] **Step 1: Replace activeState with full precedence**

```qml
    readonly property string activeState: {
        const di = Config.options?.bar?.dynamicIsland;
        if (!di?.enabled) return "idle";
        if (GlobalStates.toolsModeOpen) return "tools";  // wired in Phase 5
        if ((di?.states?.voiceSearch ?? true)     && VoiceSearch.running)            return "voiceSearch";
        if ((di?.states?.recording ?? true)       && RecorderStatus.isRecording)     return "recording";
        if ((di?.states?.timer ?? true)           && _anyTimerRunning())             return "timer";
        if ((di?.states?.screenshotToast ?? true) && ScreenshotEvents.toastVisible)  return "screenshotToast";
        if ((di?.states?.music ?? true)           && MprisController.isPlaying)      return "music";
        return "idle";
    }

    function _anyTimerRunning() {
        return TimerService.pomodoroRunning
            || TimerService.countdownRunning
            || TimerService.stopwatchRunning;
    }
```

- [ ] **Step 2: Add components for the new states**

```qml
    Component { id: timerComponent;          TimerStatePill {} }
    Component { id: screenshotToastComponent; ScreenshotToastPill {} }
    Component { id: voiceSearchComponent;     VoiceSearchPill {} }
```

Update `_componentFor`:

```qml
    function _componentFor(state) {
        switch (state) {
            case "voiceSearch":     return voiceSearchComponent;
            case "recording":       return recordingComponent;
            case "timer":           return timerComponent;
            case "screenshotToast": return screenshotToastComponent;
            case "music":           return musicComponent;
            case "idle":
            default:                return idleComponent;
        }
    }
```

- [ ] **Step 3: Add 250ms debounce to activeState**

Add a separate property and a debounced computation:

```qml
    property string _rawState: root.activeState
    property string _debouncedState: _rawState

    Timer {
        id: debounceTimer
        interval: 250
        repeat: false
        onTriggered: root._debouncedState = root._rawState
    }

    on_RawStateChanged: debounceTimer.restart()
```

Then update the `Loader.sourceComponent`:

```qml
        sourceComponent: root._componentFor(root._debouncedState)
```

- [ ] **Step 4: Lint, live-reload, smoke test all four new states**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml
bin/ryoku-refresh-quickshell
```

Test each:
1. Start a timer (`ryoku-shell timer start 5m`) - amber pill appears.
2. Take a screenshot - green ✓ pill for 2s.
3. Trigger voice search - purple listening pill.
4. Start recording AND music - recording wins, music hidden until recording stops.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml
git commit -m "feat(bar/dynamicIsland): full state precedence + debounce"
```

---

## Phase 5: Mod+S Tools Mode

### Task 5.1: Create `ToolRegistry.qml` singleton

**Files:**
- Create: `shell/modules/bar/threeIsland/dynamicIsland/tools/ToolRegistry.qml`

- [ ] **Step 1: Write the file**

```qml
pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell

// Single source of truth for tool buttons. Used by RyokuToolsMode (Mod+S
// pill) and the legacy UtilButtons.qml. Each entry: id -> { icon, label,
// kind ("action" | "toggle"), action(), activeWhen() }.
Singleton {
    id: root

    readonly property var tools: ({
        screenshot: {
            icon: "screenshot_region",
            label: "Screenshot region",
            kind: "action",
            action: () => Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "region", "screenshot"])
        },
        record: {
            icon: "videocam",
            label: "Screen record",
            kind: "action",
            action: () => Quickshell.execDetached([Directories.recordScriptPath, "--fullscreen", "--sound"]),
            activeWhen: () => RecorderStatus.isRecording
        },
        lens: {
            icon: "search",
            label: "Google Lens",
            kind: "action",
            action: () => Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "region", "search"])
        },
        colorPicker: {
            icon: "colorize",
            label: "Color picker",
            kind: "action",
            action: () => Quickshell.execDetached(["/usr/bin/hyprpicker", "-a"])
        },
        musicRecognize: {
            icon: "graphic_eq",
            label: "Recognize music",
            kind: "action",
            action: () => SongRec.toggleRunning(true),
            activeWhen: () => SongRec.running
        },
        micToggle: {
            icon: "mic",
            label: "Mic toggle",
            kind: "toggle",
            action: () => Audio.toggleMicMute(),
            activeWhen: () => !Audio.micMuted && (Privacy.micActive ?? false)
        },
        osk: {
            icon: "keyboard",
            label: "On-screen keyboard",
            kind: "toggle",
            action: () => GlobalStates.oskOpen = !GlobalStates.oskOpen,
            activeWhen: () => GlobalStates.oskOpen
        },
        caffeine: {
            icon: "coffee",
            label: "Keep awake",
            kind: "toggle",
            action: () => Idle.toggleInhibit(),
            activeWhen: () => Idle.inhibit
        },
        notepad: {
            icon: "edit_note",
            label: "Notepad",
            kind: "action",
            action: () => {
                GlobalStates.sidebarRightOpen = true;
                Persistent.states.sidebar.bottomGroup.collapsed = false;
                Persistent.states.sidebar.bottomGroup.tab = 2;
            }
        },
        screenCast: {
            icon: "visibility",
            label: "Screen cast",
            kind: "toggle",
            action: () => {
                const out = Config.options?.bar?.utilButtons?.screenCastOutput ?? "HDMI-A-1";
                if (Persistent.states.screenCast.active) {
                    Quickshell.execDetached(["niri", "msg", "action", "clear-dynamic-cast-target"]);
                    Persistent.states.screenCast.active = false;
                } else {
                    Quickshell.execDetached(["niri", "msg", "action", "set-dynamic-cast-monitor", out]);
                    Persistent.states.screenCast.active = true;
                }
            },
            activeWhen: () => Persistent.states.screenCast.active
        },
        darkMode: {
            icon: "dark_mode",
            label: "Dark mode",
            kind: "toggle",
            action: () => MaterialThemeLoader.setDarkMode(!Appearance.m3colors.darkmode),
            activeWhen: () => Appearance.m3colors.darkmode
        },
        powerProfile: {
            icon: "settings_slow_motion",
            label: "Power profile",
            kind: "toggle",
            action: () => {
                if (PowerProfiles.hasPerformanceProfile) {
                    switch(PowerProfiles.profile) {
                        case PowerProfile.PowerSaver:   PowerProfiles.profile = PowerProfile.Balanced; break;
                        case PowerProfile.Balanced:     PowerProfiles.profile = PowerProfile.Performance; break;
                        case PowerProfile.Performance:  PowerProfiles.profile = PowerProfile.PowerSaver; break;
                    }
                } else {
                    PowerProfiles.profile = PowerProfiles.profile === PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced;
                }
            },
            activeWhen: () => PowerProfiles.profile === PowerProfile.Performance
        }
    })
}
```

- [ ] **Step 2: Lint and commit**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/tools/ToolRegistry.qml
git add shell/modules/bar/threeIsland/dynamicIsland/tools/ToolRegistry.qml
git commit -m "feat(bar/dynamicIsland/tools): ToolRegistry singleton"
```

---

### Task 5.2: Create `ToolButton.qml`

**Files:**
- Create: `shell/modules/bar/threeIsland/dynamicIsland/tools/ToolButton.qml`

- [ ] **Step 1: Write the file**

```qml
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

// Circular button used in the Mod+S tools pill. Reads metadata from
// ToolRegistry by tool id.
Item {
    id: root
    required property string toolId
    required property bool autoCloseAfterAction

    readonly property var entry: ToolRegistry.tools[root.toolId] ?? null
    readonly property bool isActive: entry?.activeWhen ? entry.activeWhen() : false

    implicitWidth: 32
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: mouseArea.containsMouse
            ? Appearance.colors.colLayer3Hover
            : (root.isActive ? Appearance.colors.colLayer3 : "transparent")

        Behavior on color { ColorAnimation { duration: 120 } }
    }

    MaterialSymbol {
        anchors.centerIn: parent
        text: root.entry?.icon ?? "circle"
        iconSize: Appearance.font.pixelSize.large
        color: root.isActive
            ? Appearance.colors.colOnPrimary
            : Appearance.colors.colOnLayer2
        fill: root.isActive ? 1 : 0
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (!root.entry) return;
            root.entry.action();
            if (root.entry.kind === "action" && root.autoCloseAfterAction) {
                GlobalStates.toolsModeOpen = false;
            }
        }
        StyledToolTip { text: root.entry?.label ?? "" }
    }
}
```

- [ ] **Step 2: Lint and commit**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/tools/ToolButton.qml
git add shell/modules/bar/threeIsland/dynamicIsland/tools/ToolButton.qml
git commit -m "feat(bar/dynamicIsland/tools): ToolButton circular icon button"
```

---

### Task 5.3: Create `RyokuToolsMode.qml` wide pill

**Files:**
- Create: `shell/modules/bar/threeIsland/dynamicIsland/tools/RyokuToolsMode.qml`

- [ ] **Step 1: Write the file**

```qml
import qs
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Wide centered pill with tool buttons grouped by DIVIDER tokens. Mounted
// when GlobalStates.toolsModeOpen is true. Press Esc or right-click to close.
Item {
    id: root
    implicitWidth: pill.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    readonly property var toolsConfig: Config.options?.bar?.dynamicIsland?.tools
    readonly property var orderRaw: toolsConfig?.order ?? []
    readonly property bool autoCloseAfterAction: toolsConfig?.autoCloseAfterAction ?? true
    readonly property bool closeOnEsc: toolsConfig?.closeOnEsc ?? true

    readonly property var visibleOrder: {
        const buttons = toolsConfig?.buttons ?? {};
        const out = [];
        for (let i = 0; i < orderRaw.length; i++) {
            const id = orderRaw[i];
            if (id === "DIVIDER") {
                if (out.length > 0 && out[out.length - 1] !== "DIVIDER") out.push("DIVIDER");
            } else if (buttons[id] !== false) {
                out.push(id);
            }
        }
        // strip trailing DIVIDER
        while (out.length > 0 && out[out.length - 1] === "DIVIDER") out.pop();
        return out;
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        implicitWidth: row.implicitWidth + 28
        implicitHeight: 40
        radius: height / 2
        color: Appearance.colors.colLayer2

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.visibleOrder
                delegate: Loader {
                    required property string modelData
                    sourceComponent: modelData === "DIVIDER" ? dividerComp : buttonComp

                    Component {
                        id: dividerComp
                        Rectangle {
                            implicitWidth: 1
                            implicitHeight: 22
                            color: Appearance.colors.colOutline
                            opacity: 0.4
                            Layout.alignment: Qt.AlignVCenter
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                        }
                    }
                    Component {
                        id: buttonComp
                        ToolButton {
                            toolId: modelData
                            autoCloseAfterAction: root.autoCloseAfterAction
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }

    // Right-click anywhere on the pill closes
    MouseArea {
        anchors.fill: pill
        acceptedButtons: Qt.RightButton
        propagateComposedEvents: true
        onPressed: GlobalStates.toolsModeOpen = false
    }

    // Esc closes
    Keys.onEscapePressed: {
        if (root.closeOnEsc) GlobalStates.toolsModeOpen = false
    }

    Component.onCompleted: root.forceActiveFocus()

    // IPC handler for ryoku-shell tools-mode toggle
    IpcHandler {
        target: "toolsMode"
        function toggle(): void { GlobalStates.toolsModeOpen = !GlobalStates.toolsModeOpen }
        function open(): void   { GlobalStates.toolsModeOpen = true }
        function close(): void  { GlobalStates.toolsModeOpen = false }
    }
}
```

- [ ] **Step 2: Lint and commit**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/tools/RyokuToolsMode.qml
git add shell/modules/bar/threeIsland/dynamicIsland/tools/RyokuToolsMode.qml
git commit -m "feat(bar/dynamicIsland/tools): RyokuToolsMode wide pill + IpcHandler"
```

---

### Task 5.4: Wire tools mode into orchestrator + side-island fade

**Files:**
- Modify: `shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml`
- Modify: `shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml`

- [ ] **Step 1: Add tools component in orchestrator**

In `RyokuDynamicIsland.qml`:

```qml
    Component { id: toolsComponent; RyokuToolsMode {} }
```

Update `_componentFor`:

```qml
    function _componentFor(state) {
        switch (state) {
            case "tools":           return toolsComponent;
            case "voiceSearch":     return voiceSearchComponent;
            case "recording":       return recordingComponent;
            case "timer":           return timerComponent;
            case "screenshotToast": return screenshotToastComponent;
            case "music":           return musicComponent;
            case "idle":
            default:                return idleComponent;
        }
    }
```

Add the import:

```qml
import qs.modules.bar.threeIsland.dynamicIsland.tools
```

- [ ] **Step 2: Side-island fade in `RyokuThreeIslandContent.qml`**

In `RyokuThreeIslandContent.qml`, find `leftNotch` and `rightNotch` `Item` blocks. Add a binding so that when `GlobalStates.toolsModeOpen` is true, both shrink and fade out:

For `leftNotch`:

```qml
        opacity: GlobalStates.toolsModeOpen ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutQuad } }
```

Modify `leftNotchWidth` and `rightNotchWidth` properties to honor tools mode:

```qml
    property int leftNotchWidth:  GlobalStates.toolsModeOpen ? 0 : Math.max(140, leftSizer.implicitWidth + 16)
    property int rightNotchWidth: GlobalStates.toolsModeOpen ? 0 : Math.max(140, rightSizer.implicitWidth + 16)
```

Modify `centerNotchWidth` to grow when tools mode is open:

```qml
    property int centerNotchWidth: GlobalStates.toolsModeOpen
        ? Math.max(520, centerSizer.implicitWidth + 16)
        : Math.max(120, centerSizer.implicitWidth + 16)
```

(Existing `Behavior on *NotchWidth` blocks already provide the OutBack easing for free.)

- [ ] **Step 3: Lint and live-reload**

```bash
/usr/bin/qmllint shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml
/usr/bin/qmllint shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml
bin/ryoku-refresh-quickshell
```

- [ ] **Step 4: Manual test (no keybind yet)**

Open `qmlconsole` or use Quickshell IPC directly:

```bash
quickshell ipc call toolsMode toggle
```

The bar should morph: side islands fade and shrink, center expands to ~520px with all tool buttons. Toggle again to close.

- [ ] **Step 5: Commit**

```bash
git add shell/modules/bar/threeIsland/dynamicIsland/RyokuDynamicIsland.qml shell/modules/bar/threeIsland/RyokuThreeIslandContent.qml
git commit -m "feat(bar/threeIsland): tools mode swaps full bar via toolsModeOpen flag"
```

---

### Task 5.5: Add `tools-mode` subcommand to ryoku-shell

**Files:**
- Modify: `shell/scripts/ryoku-shell`

- [ ] **Step 1: Find subcommand dispatch**

```bash
grep -n "case \\\$1\|case \"\\\$1\"\|^case " shell/scripts/ryoku-shell | head -10
```

- [ ] **Step 2: Add a `tools-mode` case**

In `shell/scripts/ryoku-shell`'s case block, add:

```sh
    tools-mode)
        sub="${2:-toggle}"
        case "$sub" in
            toggle|open|close)
                exec quickshell ipc call toolsMode "$sub"
                ;;
            *)
                echo "ryoku-shell tools-mode: expected toggle|open|close, got '$sub'" >&2
                exit 2
                ;;
        esac
        ;;
```

- [ ] **Step 3: Test from terminal**

```bash
shell/scripts/ryoku-shell tools-mode toggle
```
Expected: bar morphs to tools mode. Run again to close.

- [ ] **Step 4: Commit**

```bash
git add shell/scripts/ryoku-shell
git commit -m "feat(ryoku-shell): tools-mode subcommand (toggle|open|close)"
```

---

### Task 5.6: Add Mod+S niri keybind

**Files:**
- Modify: `config/niri/config.d/70-binds.kdl`

- [ ] **Step 1: Find a good insertion point**

```bash
grep -n "Mod+Shift+S\|region.*screenshot" config/niri/config.d/70-binds.kdl | head -3
```

- [ ] **Step 2: Add the bind**

Right above the `Mod+Shift+S` line, add:

```
    // Dynamic Island tools mode (full-bar quicktools pill).
    Mod+S { spawn "ryoku-shell" "tools-mode" "toggle"; }
```

- [ ] **Step 3: Reload niri config**

```bash
niri msg action reload-config
```
Expected: no errors in `journalctl --user -u niri`.

- [ ] **Step 4: Smoke test**

Press **Mod+S** - tools mode opens. Press again - it closes. Press Esc while open - it closes.

- [ ] **Step 5: Commit**

```bash
git add config/niri/config.d/70-binds.kdl
git commit -m "feat(niri/binds): Mod+S toggles Dynamic Island tools mode"
```

---

### Task 5.7: Refactor `UtilButtons.qml` to read from ToolRegistry

**Files:**
- Modify: `shell/modules/bar/UtilButtons.qml`

- [ ] **Step 1: Replace the hardcoded button list**

`UtilButtons.qml` currently has 9 hand-rolled `Loader` blocks. Refactor to a single `Repeater` driven by `ToolRegistry.tools` filtered through the legacy `Config.options.bar.utilButtons.show*` flags.

Outline (write the actual code in this style):

```qml
import qs.modules.bar.threeIsland.dynamicIsland.tools

Item {
    id: root
    implicitWidth: rowLayout.implicitWidth + rowLayout.spacing * 2
    implicitHeight: rowLayout.implicitHeight

    readonly property var legacyOrder: [
        "screenshot", "record", "colorPicker", "notepad", "osk",
        "micToggle", "screenCast", "darkMode", "powerProfile"
    ]

    readonly property var legacyShown: {
        const ub = Config.options?.bar?.utilButtons ?? {};
        const map = {
            screenshot:   ub.showScreenSnip,
            record:       ub.showScreenRecord,
            colorPicker:  ub.showColorPicker,
            notepad:      ub.showNotepad,
            osk:          ub.showKeyboardToggle,
            micToggle:    ub.showMicToggle,
            screenCast:   ub.showScreenCast,
            darkMode:     ub.showDarkModeToggle,
            powerProfile: ub.showPerformanceProfileToggle
        };
        return root.legacyOrder.filter(id => map[id] === true);
    }

    RowLayout {
        id: rowLayout
        spacing: 4
        anchors.centerIn: parent
        Repeater {
            model: root.legacyShown
            delegate: ToolButton {
                required property string modelData
                toolId: modelData
                autoCloseAfterAction: false
            }
        }
    }
}
```

- [ ] **Step 2: Lint and live-reload**

```bash
/usr/bin/qmllint shell/modules/bar/UtilButtons.qml
bin/ryoku-refresh-quickshell
```

For users on `cornerStyle != 4` (legacy bar layout), the right-side util row should look identical to before but be driven from the registry.

- [ ] **Step 3: Commit**

```bash
git add shell/modules/bar/UtilButtons.qml
git commit -m "refactor(bar/UtilButtons): read from ToolRegistry"
```

---

## Phase 6: Settings UI

### Task 6.1: Add a smoke test for the IPC + schema

**Files:**
- Create: `tests/dynamic-island-ipc.sh`

- [ ] **Step 1: Write a bash test**

Path: `tests/dynamic-island-ipc.sh`

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "OK: dynamic island IPC + schema"; }

# Schema: dynamicIsland exists in Config defaults
grep -q "dynamicIsland" shell/modules/common/Config.qml \
    || fail "bar.dynamicIsland missing from Config.qml"

# IPC handler defined
grep -q 'target: "toolsMode"' shell/modules/bar/threeIsland/dynamicIsland/tools/RyokuToolsMode.qml \
    || fail "toolsMode IpcHandler not declared"

# ryoku-shell knows about tools-mode
grep -q "tools-mode" shell/scripts/ryoku-shell \
    || fail "ryoku-shell tools-mode subcommand missing"

# niri bind exists
grep -q 'Mod+S {' config/niri/config.d/70-binds.kdl \
    || fail "Mod+S bind missing in niri config"

pass
```

- [ ] **Step 2: Make executable, run, commit**

```bash
chmod +x tests/dynamic-island-ipc.sh
tests/dynamic-island-ipc.sh
```
Expected: `OK: dynamic island IPC + schema`.

```bash
git add tests/dynamic-island-ipc.sh
git commit -m "test(dynamic-island): smoke test for schema + IPC + bind"
```

---

### Task 6.2: Add Settings -> Bar -> Dynamic Island section

**Files:**
- Modify: `shell/modules/settings/BarConfig.qml`

- [ ] **Step 1: Find the section pattern in BarConfig.qml**

```bash
grep -n "section\|GroupBox\|ConfigSection\|ContentSection" shell/modules/settings/BarConfig.qml | head -20
```

- [ ] **Step 2: Add the new section near existing UtilButtons section**

Find where the existing `utilButtons.show*` toggles render (likely a section labeled "Utility buttons"). Below it, append:

```qml
    // ----- Dynamic Island -----
    ConfigSection {
        title: Translation.tr("Dynamic Island")

        ConfigSwitch {
            text: Translation.tr("Enable Dynamic Island")
            checked: Config.options?.bar?.dynamicIsland?.enabled ?? true
            onCheckedChanged: Config.setNestedValue("bar.dynamicIsland.enabled", checked)
        }

        ConfigSubsection {
            title: Translation.tr("Visible states (drag to reorder priority)")
            visible: Config.options?.bar?.dynamicIsland?.enabled ?? true

            // simple toggle list for now; drag-reorder in the next task
            ConfigSwitch {
                text: Translation.tr("Voice search")
                checked: Config.options?.bar?.dynamicIsland?.states?.voiceSearch ?? true
                onCheckedChanged: Config.setNestedValue("bar.dynamicIsland.states.voiceSearch", checked)
            }
            ConfigSwitch {
                text: Translation.tr("Recording")
                checked: Config.options?.bar?.dynamicIsland?.states?.recording ?? true
                onCheckedChanged: Config.setNestedValue("bar.dynamicIsland.states.recording", checked)
            }
            ConfigSwitch {
                text: Translation.tr("Timer")
                checked: Config.options?.bar?.dynamicIsland?.states?.timer ?? true
                onCheckedChanged: Config.setNestedValue("bar.dynamicIsland.states.timer", checked)
            }
            ConfigSwitch {
                text: Translation.tr("Screenshot toast")
                checked: Config.options?.bar?.dynamicIsland?.states?.screenshotToast ?? true
                onCheckedChanged: Config.setNestedValue("bar.dynamicIsland.states.screenshotToast", checked)
            }
            ConfigSwitch {
                text: Translation.tr("Music")
                checked: Config.options?.bar?.dynamicIsland?.states?.music ?? true
                onCheckedChanged: Config.setNestedValue("bar.dynamicIsland.states.music", checked)
            }
        }

        ConfigSubsection {
            title: Translation.tr("Mod+S Tools pill")
            visible: Config.options?.bar?.dynamicIsland?.enabled ?? true

            ConfigSwitch {
                text: Translation.tr("Auto-close after action")
                checked: Config.options?.bar?.dynamicIsland?.tools?.autoCloseAfterAction ?? true
                onCheckedChanged: Config.setNestedValue("bar.dynamicIsland.tools.autoCloseAfterAction", checked)
            }
            ConfigSwitch {
                text: Translation.tr("Close on Esc")
                checked: Config.options?.bar?.dynamicIsland?.tools?.closeOnEsc ?? true
                onCheckedChanged: Config.setNestedValue("bar.dynamicIsland.tools.closeOnEsc", checked)
            }

            // Per-tool toggles - for v1, render as a flat list of switches.
            // The drag-reorder UI is added in Task 6.3.
            Repeater {
                model: ["screenshot","record","lens","colorPicker","musicRecognize",
                        "micToggle","osk","caffeine","notepad","screenCast","darkMode","powerProfile"]
                delegate: ConfigSwitch {
                    required property string modelData
                    text: modelData
                    checked: (Config.options?.bar?.dynamicIsland?.tools?.buttons?.[modelData]) ?? true
                    onCheckedChanged: Config.setNestedValue("bar.dynamicIsland.tools.buttons." + modelData, checked)
                }
            }
        }

        ConfigSwitch {
            text: Translation.tr("Music popup attached to island")
            checked: Config.options?.bar?.dynamicIsland?.musicPopupContinuous ?? true
            onCheckedChanged: Config.setNestedValue("bar.dynamicIsland.musicPopupContinuous", checked)
        }
    }
```

(`ConfigSection`, `ConfigSubsection`, `ConfigSwitch` are existing Ryoku widgets - find them via `grep -rn "component ConfigSection\|component ConfigSwitch" shell/modules/settings`.)

- [ ] **Step 2: Lint, live-reload, eyeball**

```bash
/usr/bin/qmllint shell/modules/settings/BarConfig.qml
bin/ryoku-refresh-quickshell
```

Open Settings -> Bar. Scroll to the new "Dynamic Island" section. All toggles work and persist.

- [ ] **Step 3: Commit**

```bash
git add shell/modules/settings/BarConfig.qml
git commit -m "feat(settings/Bar): Dynamic Island section (toggles for states + tools)"
```

---

### Task 6.3: Add drag-to-reorder for tools order

**Files:**
- Modify: `shell/modules/settings/BarConfig.qml`
- Reference: `shell/modules/dock/DockApps.qml` (existing drag-reorder pattern)

- [ ] **Step 1: Read the DockApps pattern**

```bash
sed -n '160,260p' shell/modules/dock/DockApps.qml
```

Note the `dragIndex` / `dropTargetIndex` / `_log` / `displacement transform` pattern.

- [ ] **Step 2: Replace the flat per-tool Repeater with a draggable list**

Rough sketch (adapt to match existing `ConfigSection` styling):

```qml
            ListView {
                id: toolsOrderList
                Layout.fillWidth: true
                implicitHeight: contentHeight
                interactive: false
                spacing: 4

                model: Config.options?.bar?.dynamicIsland?.tools?.order ?? []

                property int dragIndex: -1
                property int dropTargetIndex: -1

                delegate: Rectangle {
                    id: row
                    required property string modelData
                    required property int index
                    width: toolsOrderList.width
                    height: 36
                    radius: 6
                    color: dragIndex === index ? Appearance.colors.colLayer3Hover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        MaterialSymbol { text: "drag_indicator" }
                        StyledText {
                            Layout.fillWidth: true
                            text: row.modelData === "DIVIDER" ? "(divider)" : row.modelData
                        }
                        ConfigSwitch {
                            visible: row.modelData !== "DIVIDER"
                            checked: (Config.options?.bar?.dynamicIsland?.tools?.buttons?.[row.modelData]) ?? true
                            onCheckedChanged: Config.setNestedValue("bar.dynamicIsland.tools.buttons." + row.modelData, checked)
                        }
                    }

                    DragHandler {
                        id: dh
                        target: row
                        yAxis.enabled: true
                        xAxis.enabled: false
                        onActiveChanged: {
                            if (active) {
                                toolsOrderList.dragIndex = row.index;
                            } else {
                                if (toolsOrderList.dragIndex !== toolsOrderList.dropTargetIndex
                                    && toolsOrderList.dropTargetIndex >= 0) {
                                    const arr = (Config.options.bar.dynamicIsland.tools.order ?? []).slice();
                                    const item = arr.splice(toolsOrderList.dragIndex, 1)[0];
                                    arr.splice(toolsOrderList.dropTargetIndex, 0, item);
                                    Config.setNestedValue("bar.dynamicIsland.tools.order", arr);
                                }
                                toolsOrderList.dragIndex = -1;
                                toolsOrderList.dropTargetIndex = -1;
                                row.y = 0;
                            }
                        }
                    }

                    onYChanged: {
                        if (dh.active) {
                            const newIdx = Math.max(0, Math.min(toolsOrderList.count - 1,
                                Math.round((row.y + row.height / 2) / row.height)));
                            toolsOrderList.dropTargetIndex = newIdx;
                        }
                    }
                }
            }
```

- [ ] **Step 3: Lint, live-reload**

```bash
/usr/bin/qmllint shell/modules/settings/BarConfig.qml
bin/ryoku-refresh-quickshell
```

Open Settings -> Bar -> Dynamic Island -> "Mod+S Tools pill". Drag a row up/down. After release, the order persists. Press Mod+S - the tools pill reflects the new order.

- [ ] **Step 4: Commit**

```bash
git add shell/modules/settings/BarConfig.qml
git commit -m "feat(settings/Bar): drag-to-reorder for Dynamic Island tools order"
```

---

### Task 6.4: Migration step for legacy utilButtons flags

**Files:**
- Modify: `shell/modules/common/Config.qml`

- [ ] **Step 1: Add a one-shot migration**

In `Config.qml`, find the `Component.onCompleted` or equivalent init handler. Add a check:

```qml
    Component.onCompleted: {
        // Migrate legacy utilButtons.show* flags to dynamicIsland.tools.buttons
        // on first launch after the upgrade. Persistent.states.dynamicIslandMigrated
        // is the gate.
        if (Persistent.states?.dynamicIslandMigrated !== true) {
            const ub = root.options.bar.utilButtons ?? {};
            const map = {
                screenshot: ub.showScreenSnip ?? true,
                record:     ub.showScreenRecord ?? true,
                colorPicker:ub.showColorPicker ?? false,
                notepad:    ub.showNotepad ?? true,
                osk:        ub.showKeyboardToggle ?? true,
                micToggle:  ub.showMicToggle ?? false,
                screenCast: ub.showScreenCast ?? false,
                darkMode:   ub.showDarkModeToggle ?? true,
                powerProfile:ub.showPerformanceProfileToggle ?? false
            };
            for (const key in map) {
                root.setNestedValue("bar.dynamicIsland.tools.buttons." + key, map[key]);
            }
            // lens, musicRecognize, caffeine are new - leave at defaults (true)
            Persistent.states.dynamicIslandMigrated = true;
        }
    }
```

(Add `dynamicIslandMigrated: false` to `Persistent.states` schema if needed.)

- [ ] **Step 2: Lint and live-reload**

```bash
/usr/bin/qmllint shell/modules/common/Config.qml
bin/ryoku-refresh-quickshell
```

Verify on a system with `bar.utilButtons.showColorPicker = true` set previously - after reload, `bar.dynamicIsland.tools.buttons.colorPicker` should also be `true`.

- [ ] **Step 3: Commit**

```bash
git add shell/modules/common/Config.qml
git commit -m "feat(Config): migrate legacy utilButtons.show* flags to dynamicIsland"
```

---

### Task 6.5: Document the new keybind

**Files:**
- Modify: `docs/keybindings.md`

- [ ] **Step 1: Add Mod+S row**

```bash
grep -n "Mod+Shift+S\|Region selector" docs/keybindings.md | head -3
```

Above that row, add:

```
| `Mod+S`       | Toggle Dynamic Island Tools mode (quick screenshot, record, lens, color picker, ...) |
```

- [ ] **Step 2: Commit**

```bash
git add docs/keybindings.md
git commit -m "docs(keybindings): document Mod+S Dynamic Island tools mode"
```

---

## Final acceptance checklist

After Phase 6 completes, run all of these:

- [ ] `tests/dynamic-island-ipc.sh` - schema + IPC + bind smoke test passes
- [ ] `find shell -name "*.qml" -exec /usr/bin/qmllint {} +` - no errors
- [ ] `bin/ryoku-refresh-quickshell` - shell restarts cleanly
- [ ] Visual: idle bar identical to baseline (clock + weather + date)
- [ ] Visual: each of recording / music / timer / screenshot toast / voice search renders correctly
- [ ] Visual: Mod+S morphs side islands closed and grows tools pill; Mod+S again restores
- [ ] Visual: Esc while in tools mode closes
- [ ] Visual: action buttons in tools mode auto-close, toggle buttons stay open
- [ ] Music popup expands DOWN from the music pill with no gap (top corners flat)
- [ ] Settings -> Bar -> Dynamic Island: all toggles persist; drag-reorder of tools order persists
- [ ] On `bar.cornerStyle != 4` (legacy bar): `UtilButtons.qml` still renders correctly via the registry

---

## Notes for the implementer

- The `Behavior on centerNotchWidth` block in `RyokuThreeIslandContent.qml` (~line 105) does the morph animation. You should not need to add new animations - just bind the right values.
- All commits must avoid em-dashes, `Co-Authored-By` trailers, and personal home paths in the staged content (pre-commit hook enforces).
- If you find an existing `ConfigSection` / `ConfigSwitch` / `ConfigSubsection` widget with a slightly different name, use it instead of inventing one. `grep -rn "component ConfigSection" shell/modules/settings` to find it.
- For multi-monitor: `GlobalStates.toolsModeOpen` is a single global flag, so all monitor bars switch together. State pills (recording, music, etc.) are per-bar-instance and render independently on each screen.
- If `cava` is not installed, the music pill should fall back to a static music_note icon. `Cava.unavailable` is the gate. Currently `MusicStatePill` will show empty bars; Phase 3.1 sets `unavailable` correctly. Wire that into the pill in a follow-up if needed.
- `Persistent.states.dynamicIslandMigrated` (Task 6.4) needs to be declared in the `Persistent.qml` (or equivalent) schema, the same way `Persistent.states.screenCast.active` is declared. Find that file via `grep -rn "property.*screenCast\b" shell/modules/common/Persistent.qml` and add a sibling `property bool dynamicIslandMigrated: false`.
