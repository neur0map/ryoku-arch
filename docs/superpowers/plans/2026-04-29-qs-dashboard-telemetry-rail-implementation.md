# QS Dashboard Telemetry Rail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current tabbed Quickshell dashboard with a single unified home view that keeps `Profile`, `Calendar`, `Clock`, and `Player`, and adds a custom telemetry rail instead of the old repeated card/speedometer system UI.

**Architecture:** Collapse `Dashboard.qml` from a page-switching shell into a single `DashHome` surface. Keep the existing personal/media cards mostly intact, but move system telemetry into a new dedicated `TelemetryRail.qml` component that reuses the existing Brain Shell services while presenting CPU, RAM, temperatures, network, GPU, and disk with mixed graph/bar treatments. Keep verification in the existing `tests/brain-shell-spec1.sh` smoke test and use the repo checkout explicitly when refreshing live Quickshell config.

**Tech Stack:** QML, QtQuick Canvas, Quickshell services, existing Brain Shell system service QML files, Bash smoke test

---

## File Map

- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml`
  - Remove page state, tab bar, and `DashStats` mounting.
  - Mount a single `DashHome` body.
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml`
  - Expand from two columns to three columns.
  - Add the telemetry rail on the right while keeping `Profile`, `Calendar`, `Clock`, and `Player`.
- Create: `config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml`
  - Own CPU history sampling and custom rendering for the telemetry surface.
  - Reuse `CpuService`, `MemService`, `NetService`, `ThermalService`, `DiskService`, `CpuFreqService`, `GpuService`, and `EnvyControlService`.
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/home/qmldir`
  - Export `TelemetryRail.qml` alongside the existing home components.
- Modify/Test: `tests/brain-shell-spec1.sh`
  - Replace the old “Home + System tabs” checks with unified-dashboard and telemetry-rail checks.
  - Update the manual checklist text to describe the new unified view.

---

### Task 1: Collapse the dashboard shell to a single home surface

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml:1-177`
- Modify/Test: `tests/brain-shell-spec1.sh:81-145`

- [ ] **Step 1: Write the failing smoke test for the unified dashboard shell**

Replace the current dashboard-specific assertions in `tests/brain-shell-spec1.sh` with this block:

```bash
# --- Dashboard unified shell -----------------------------------------
! grep -q 'TabSwitcher\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard tab bar should be removed"
! grep -q 'property string page:' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard page state should be removed"
! grep -q 'DashStats\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should not mount DashStats directly"
grep -q 'DashHome\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  || fail "Dashboard should mount DashHome"
pass "dashboard unified shell"
```

Also update the manual checklist footer to match the new shell:

```bash
echo "  4. Click center notch -> Dashboard opens as one unified home view"
echo "  5. Verify the dashboard has no tab bar and shows home content immediately"
```

- [ ] **Step 2: Run the smoke test to verify it fails for the right reason**

Run: `tests/brain-shell-spec1.sh`

Expected: FAIL with `Dashboard tab bar should be removed`

- [ ] **Step 3: Rewrite `Dashboard.qml` to remove the page shell and mount only `DashHome`**

Replace `config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml` with:

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../shapes"
import "../services/"
import "../"

PanelWindow {
    id: root

    required property var anchorWindow

    readonly property int fw: Theme.notchRadius
    readonly property int fh: Theme.notchRadius
    readonly property int animDuration: Theme.animDuration

    color:   "transparent"
    visible: windowVisible

    anchors.top:   true
    anchors.left:  true
    anchors.right: true

    implicitHeight: Theme.notchHeight + Theme.dashboardHeight
    exclusionMode:  ExclusionMode.Ignore

    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region { item: maskProxy }
    Item {
        id:     maskProxy
        x:      ((root.width - sizer.width) / 2) + root.fw
        y:      Theme.notchHeight
        width:  sizer.width - root.fw
        height: sizer.height - Theme.notchHeight
    }

    property bool windowVisible: false

    Connections {
        target: Popups
        function onDashboardOpenChanged() {
            if (Popups.dashboardOpen) {
                closeTimer.stop()
                root.windowVisible = true
            } else {
                closeTimer.restart()
            }
        }
    }

    Timer {
        id: closeTimer
        interval: root.animDuration + 20
        onTriggered: root.windowVisible = false
    }

    Item {
        id: sizer
        anchors.top:              parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true

        width:  Popups.dashboardOpen ? Theme.dashboardWidth + 2 * root.fw : Theme.cNotchMinWidth + 2 * root.fw
        height: Popups.dashboardOpen ? Theme.dashboardHeight : Theme.notchHeight / 2

        Behavior on width  { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: root.animDuration; easing.type: Easing.InOutCubic } }

        PopupShape {
            anchors.fill:  parent
            attachedEdge:  "top"
            color:         Theme.background
            radius:        Theme.cornerRadius
            flareWidth:    root.fw
            flareHeight:   root.fh
        }

        Item {
            anchors {
                fill:         parent
                topMargin:    root.fh + 8
                leftMargin:   root.fw + 8
                rightMargin:  root.fw + 8
                bottomMargin: 8
            }

            opacity: Popups.dashboardOpen ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: Popups.dashboardOpen
                        ? root.animDuration * 0.5
                        : root.animDuration * 0.15
                }
            }

            DashHome {
                anchors.fill: parent
            }
        }
    }
}
```

- [ ] **Step 4: Run the smoke test to verify the unified shell passes**

Run: `tests/brain-shell-spec1.sh`

Expected:

```text
OK: dashboard unified shell
```

- [ ] **Step 5: Commit the shell collapse**

```bash
git add tests/brain-shell-spec1.sh \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml
git commit -m "feat: collapse dashboard to a single home view"
```

---

### Task 2: Build the telemetry rail and wire it into DashHome

**Files:**
- Create: `config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml:1-119`
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/home/qmldir:1-5`
- Modify/Test: `tests/brain-shell-spec1.sh`

- [ ] **Step 1: Extend the smoke test for the telemetry rail and verify it fails**

Append this block after the unified-shell checks in `tests/brain-shell-spec1.sh`:

```bash
# --- Dashboard telemetry rail ----------------------------------------
[[ -f config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml ]] \
  || fail "TelemetryRail.qml missing"
grep -q 'TelemetryRail\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml \
  || fail "DashHome should mount TelemetryRail"
! grep -q 'QuickSettings\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml \
  || fail "DashHome QuickSettings column should stay removed"
! grep -q 'Speedometer\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml \
  || fail "Telemetry rail should not reuse Speedometer widgets"
grep -q 'Canvas\s*{' \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml \
  || fail "Telemetry rail should render a custom graph canvas"
pass "dashboard telemetry rail"
```

Update the footer lines too:

```bash
echo "  5. Verify Profile, Calendar, Clock, Player, and the telemetry rail appear together"
echo "  6. Verify the rail shows a CPU graph, RAM bar, thermal lanes, network bars, and compact GPU/disk summaries"
```

Run: `tests/brain-shell-spec1.sh`

Expected: FAIL with `TelemetryRail.qml missing`

- [ ] **Step 2: Create `TelemetryRail.qml` with mixed graph/bar telemetry**

Create `config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml` with:

```qml
import QtQuick
import "../../"
import "../../services/"

Item {
    id: root

    readonly property int railRadius: Theme.cornerRadius + 6
    readonly property int sampleCount: 28

    property var  _cpuHistory: []
    property real _upBps:      0
    property real _downBps:    0
    property real _netPeak:    65536

    CpuService         { id: cpu;     active: root.visible }
    MemService         { id: mem;     active: root.visible }
    NetService         { id: net;     active: root.visible }
    ThermalService     { id: thermal; active: root.visible }
    DiskService        { id: disk;    active: root.visible }
    EnvyControlService { id: envy }
    CpuFreqService     { id: cpuFreq }
    GpuService {
        id:       gpu
        active:   root.visible
        envyMode: envy.currentMode
    }

    readonly property var rootDisk: {
        var list = disk.disks
        for (var i = 0; i < list.length; i++) {
            if (list[i].mount === "/") return list[i]
        }
        return list.length > 0 ? list[0] : null
    }

    readonly property bool usingDgpu: gpu.dgpu.active
    readonly property string gpuLabel: usingDgpu ? "dGPU" : "iGPU"
    readonly property string gpuValue: usingDgpu
        ? (Math.round(gpu.dgpu.usagePercent) + "%  ·  " + gpu.dgpu.usedVram + " / " + gpu.dgpu.totalVram)
        : gpu.igpu.curMhz
    readonly property real gpuFill: usingDgpu
        ? Math.max(0, Math.min(1, gpu.dgpu.usagePercent / 100))
        : Math.max(0, Math.min(1, gpu.igpu.freqPercent / 100))

    readonly property string fanSummary: {
        if (thermal.fanCount === 0) return "Fans unavailable"
        if (thermal.fanCount === 1) return "Fan " + thermal.fan1Str
        return "Fans " + thermal.fan1Str + " / " + thermal.fan2Str
    }

    function _appendSeries(series, value) {
        var next = series.slice()
        next.push(Math.max(0, Math.min(1, value)))
        while (next.length > root.sampleCount) next.shift()
        return next
    }

    function _seedSeries() {
        if (root._cpuHistory.length > 0) return
        var seed = []
        for (var i = 0; i < root.sampleCount; i++) seed.push(0)
        root._cpuHistory = seed
    }

    function _parseBps(text) {
        var m = text.match(/([0-9.]+)\s*([KMG]?B)\/s/)
        if (!m) return 0
        var n = parseFloat(m[1])
        var unit = m[2]
        if (unit === "GB") return n * 1024 * 1024 * 1024
        if (unit === "MB") return n * 1024 * 1024
        if (unit === "KB") return n * 1024
        return n
    }

    function _tempColor(temp) {
        if (temp >= 85) return "#f38ba8"
        if (temp >= 70) return "#f5c47a"
        if (temp >= 60) return "#fab387"
        return "#8bd5ca"
    }

    Component.onCompleted: root._seedSeries()

    Timer {
        interval: 1000
        running:  root.visible
        repeat:   true
        onTriggered: {
            root._seedSeries()
            root._upBps = root._parseBps(net.upSpeed)
            root._downBps = root._parseBps(net.downSpeed)
            root._netPeak = Math.max(65536, root._upBps, root._downBps, root._netPeak * 0.92)
            root._cpuHistory = root._appendSeries(root._cpuHistory, cpu.usagePercent / 100)
            cpuGraph.requestPaint()
        }
    }

    Rectangle {
        anchors.fill: parent
        radius:       root.railRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
            GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.04) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.06) }
        }
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
    }

    Rectangle {
        anchors.fill: parent
        radius:       root.railRadius
        color:        Qt.rgba(8/255, 12/255, 18/255, 0.55)
    }

    Column {
        anchors {
            fill:    parent
            margins: 14
        }
        spacing: 14

        Item {
            width:  parent.width
            height: 122

            Text {
                anchors.left: parent.left
                anchors.top:  parent.top
                text:           "Telemetry"
                font.pixelSize: 11
                font.weight:    Font.DemiBold
                color:          Qt.rgba(1, 1, 1, 0.45)
            }

            Text {
                anchors.left: parent.left
                anchors.top:  parent.top
                anchors.topMargin: 20
                text:           Math.round(cpu.usagePercent) + "%"
                font.pixelSize: 34
                font.weight:    Font.Bold
                color:          Theme.active
            }

            Text {
                anchors.left: parent.left
                anchors.top:  parent.top
                anchors.topMargin: 62
                text:           "CPU  ·  " + cpuFreq.curFreqStr
                font.pixelSize: 11
                color:          Qt.rgba(1, 1, 1, 0.55)
            }

            Canvas {
                id: cpuGraph
                anchors {
                    left:   parent.left
                    right:  parent.right
                    bottom: parent.bottom
                }
                height: 54

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    if (root._cpuHistory.length < 2) return

                    var pts = root._cpuHistory
                    var step = width / Math.max(1, pts.length - 1)

                    ctx.beginPath()
                    ctx.moveTo(0, height)
                    for (var i = 0; i < pts.length; i++) {
                        var yFill = height - Math.max(6, pts[i] * (height - 10))
                        ctx.lineTo(i * step, yFill)
                    }
                    ctx.lineTo(width, height)
                    ctx.closePath()

                    var fill = ctx.createLinearGradient(0, 0, 0, height)
                    fill.addColorStop(0.0, "rgba(166,208,247,0.34)")
                    fill.addColorStop(1.0, "rgba(166,208,247,0.02)")
                    ctx.fillStyle = fill
                    ctx.fill()

                    ctx.beginPath()
                    for (var j = 0; j < pts.length; j++) {
                        var y = height - Math.max(6, pts[j] * (height - 10))
                        if (j === 0) ctx.moveTo(0, y)
                        else ctx.lineTo(j * step, y)
                    }
                    ctx.strokeStyle = "rgba(166,208,247,0.95)"
                    ctx.lineWidth = 2
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }
        }

        Item {
            width:  parent.width
            height: 58

            Text {
                anchors.left: parent.left
                anchors.top:  parent.top
                text:           "Memory"
                font.pixelSize: 11
                font.weight:    Font.DemiBold
                color:          Qt.rgba(1, 1, 1, 0.45)
            }

            Text {
                anchors.right: parent.right
                anchors.top:   parent.top
                text:           mem.usedStr + " / " + mem.totalStr
                font.pixelSize: 11
                color:          Qt.rgba(1, 1, 1, 0.65)
            }

            Rectangle {
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                height:         16
                radius:         8
                color:          Qt.rgba(1, 1, 1, 0.08)
                border.color:   Qt.rgba(1, 1, 1, 0.08)
                border.width:   1

                Rectangle {
                    anchors.left:   parent.left
                    anchors.top:    parent.top
                    anchors.bottom: parent.bottom
                    width:          parent.width * Math.max(0, Math.min(1, mem.usagePercent / 100))
                    radius:         parent.radius
                    color:          "#cba6f7"
                    Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                }

                Text {
                    anchors.centerIn: parent
                    text:           mem.usagePercent + "%"
                    font.pixelSize: 10
                    font.weight:    Font.DemiBold
                    color:          "#0b0f14"
                }
            }
        }

        Item {
            width:  parent.width
            height: 76

            Column {
                anchors.fill: parent
                spacing: 8

                Text {
                    text:           "Thermals"
                    font.pixelSize: 11
                    font.weight:    Font.DemiBold
                    color:          Qt.rgba(1, 1, 1, 0.45)
                }

                Repeater {
                    model: [
                        { label: "CPU", temp: thermal.cpuTemp, text: thermal.cpuTempStr },
                        { label: "GPU", temp: thermal.gpuTemp, text: root.usingDgpu ? thermal.gpuTempStr : "idle" }
                    ]
                    delegate: Item {
                        required property var modelData
                        width:  parent.width
                        height: 18

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text:           modelData.label
                            font.pixelSize: 10
                            color:          Qt.rgba(1, 1, 1, 0.42)
                        }

                        Rectangle {
                            anchors.left:   parent.left
                            anchors.leftMargin: 34
                            anchors.right:  valueLabel.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height:         8
                            radius:         4
                            color:          Qt.rgba(1, 1, 1, 0.08)

                            Rectangle {
                                anchors.left:   parent.left
                                anchors.top:    parent.top
                                anchors.bottom: parent.bottom
                                width:          parent.width * Math.max(0, Math.min(1, modelData.temp / 100))
                                radius:         parent.radius
                                color:          root._tempColor(modelData.temp)
                                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                        }

                        Text {
                            id: valueLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text:           modelData.text
                            font.pixelSize: 10
                            color:          Qt.rgba(1, 1, 1, 0.68)
                        }
                    }
                }

                Text {
                    text:           root.fanSummary
                    font.pixelSize: 9
                    color:          Qt.rgba(1, 1, 1, 0.35)
                }
            }
        }

        Item {
            width:  parent.width
            height: 82

            Column {
                anchors.fill: parent
                spacing: 8

                Text {
                    text:           "Network"
                    font.pixelSize: 11
                    font.weight:    Font.DemiBold
                    color:          Qt.rgba(1, 1, 1, 0.45)
                }

                Repeater {
                    model: [
                        { label: "UP", color: "#90ef90", value: net.upSpeed, fill: Math.max(0, Math.min(1, root._upBps / root._netPeak)) },
                        { label: "DOWN", color: "#a6d0f7", value: net.downSpeed, fill: Math.max(0, Math.min(1, root._downBps / root._netPeak)) }
                    ]
                    delegate: Item {
                        required property var modelData
                        width:  parent.width
                        height: 22

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text:           modelData.label
                            font.pixelSize: 10
                            font.weight:    Font.DemiBold
                            color:          modelData.color
                        }

                        Rectangle {
                            anchors.left:   parent.left
                            anchors.leftMargin: 42
                            anchors.right:  speedLabel.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            height:         8
                            radius:         4
                            color:          Qt.rgba(1, 1, 1, 0.08)

                            Rectangle {
                                anchors.left:   parent.left
                                anchors.top:    parent.top
                                anchors.bottom: parent.bottom
                                width:          parent.width * modelData.fill
                                radius:         parent.radius
                                color:          modelData.color
                                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                            }
                        }

                        Text {
                            id: speedLabel
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text:           modelData.value
                            font.pixelSize: 10
                            color:          Qt.rgba(1, 1, 1, 0.68)
                        }
                    }
                }

                Text {
                    text:           net.iface !== "-" ? ("Interface  " + net.iface) : "Interface unavailable"
                    font.pixelSize: 9
                    color:          Qt.rgba(1, 1, 1, 0.35)
                }
            }
        }

        Item {
            width:  parent.width
            height: 74

            Column {
                anchors.fill: parent
                spacing: 8

                Item {
                    width:  parent.width
                    height: 24

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.gpuLabel
                        font.pixelSize: 10
                        color:          Qt.rgba(1, 1, 1, 0.42)
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.gpuValue
                        font.pixelSize: 10
                        color:          root.usingDgpu ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(1, 1, 1, 0.42)
                    }

                    Rectangle {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                        height:         6
                        radius:         3
                        color:          Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            anchors.left:   parent.left
                            anchors.top:    parent.top
                            anchors.bottom: parent.bottom
                            width:          parent.width * root.gpuFill
                            radius:         parent.radius
                            color:          root.usingDgpu ? "#a6e3a1" : Qt.rgba(1, 1, 1, 0.24)
                            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                Item {
                    width:  parent.width
                    height: 28
                    visible: root.rootDisk !== null

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.rootDisk ? ("Disk " + root.rootDisk.mount) : "Disk"
                        font.pixelSize: 10
                        color:          Qt.rgba(1, 1, 1, 0.42)
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.rootDisk ? (root.rootDisk.usedStr + " / " + root.rootDisk.totalStr) : "-"
                        font.pixelSize: 10
                        color:          Qt.rgba(1, 1, 1, 0.68)
                    }

                    Rectangle {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                        height:         6
                        radius:         3
                        color:          Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            anchors.left:   parent.left
                            anchors.top:    parent.top
                            anchors.bottom: parent.bottom
                            width:          root.rootDisk ? parent.width * Math.max(0, Math.min(1, root.rootDisk.usedPct / 100)) : 0
                            radius:         parent.radius
                            color:          root.rootDisk && root.rootDisk.usedPct >= 85 ? "#f38ba8" : Theme.active
                            Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Export the new home component in `qmldir`**

Update `config/quickshell/ryoku/vendor/brain-shell/src/services/home/qmldir` to:

```text
ProfileCard    ProfileCard.qml
CalendarCard   CalendarCard.qml
ClockCard      ClockCard.qml
PlayerCard     PlayerCard.qml
QuickSettings  QuickSettings.qml
TelemetryRail  TelemetryRail.qml
```

- [ ] **Step 4: Rework `DashHome.qml` into a three-column unified home layout**

Replace `config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml` with:

```qml
import QtQuick
import Quickshell.Io
import "../"
import "../../components"

Item {
    id: root

    readonly property int colW:     190
    readonly property int centerW:  380
    readonly property int railW:    260
    readonly property int gap:        8
    readonly property int profileH: 154
    readonly property int clockH:   210

    property string _avatarPath: ""
    property string _staticJpg:  ""

    Process {
        command: ["bash", "-c", "echo $HOME"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var h = line.trim()
                if (h === "") return
                root._staticJpg  = h + "/.curr_wall_static.jpg"
                root._avatarPath = root._staticJpg
            }
        }
    }

    Connections {
        target: WallpaperService
        function onWallpaperApplied(path) {
            root._avatarPath = ""
            reloadTimer.restart()
        }
    }

    Timer {
        id: reloadTimer
        interval: 0
        repeat:   false
        onTriggered: root._avatarPath = root._staticJpg
    }

    Row {
        id: mainRow
        anchors {
            top:              parent.top
            bottom:           parent.bottom
            topMargin:        root.gap
            horizontalCenter: parent.horizontalCenter
        }
        spacing: root.gap
        width: leftCol.width + centerCol.width + rail.width + root.gap * 2

        Item {
            id: leftCol
            width: root.colW
            height: parent.height

            ProfileCard {
                id: profileCard
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: root.profileH
                avatarPath: root._avatarPath
            }

            CalendarCard {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: profileCard.bottom
                    topMargin: root.gap
                    bottom: parent.bottom
                }
            }
        }

        Item {
            id: centerCol
            width: root.centerW
            height: parent.height

            ClockCard {
                id: clockCard
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: root.clockH
            }

            PlayerCard {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: clockCard.bottom
                    topMargin: root.gap
                    bottom: parent.bottom
                }
            }
        }

        TelemetryRail {
            id: rail
            width:  root.railW
            height: parent.height
        }
    }
}
```

- [ ] **Step 5: Run the smoke test to verify the telemetry rail passes**

Run: `tests/brain-shell-spec1.sh`

Expected:

```text
OK: dashboard unified shell
OK: dashboard telemetry rail
```

- [ ] **Step 6: Commit the telemetry rail redesign**

```bash
git add tests/brain-shell-spec1.sh \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/qmldir \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml
git commit -m "feat: add telemetry rail to dashboard home"
```

---

### Task 3: Verify, refresh from this checkout, and visually validate

**Files:**
- Test: `tests/brain-shell-spec1.sh`
- Verify: `config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml`
- Verify: `config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml`
- Verify: `config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml`

- [ ] **Step 1: Run the full static smoke test again**

Run: `tests/brain-shell-spec1.sh`

Expected:

```text
OK: dashboard unified shell
OK: dashboard telemetry rail
OK: existing stack untouched
```

- [ ] **Step 2: Run a whitespace/sanity diff check**

Run:

```bash
git diff --check -- \
  config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml \
  config/quickshell/ryoku/vendor/brain-shell/src/services/home/qmldir \
  tests/brain-shell-spec1.sh
```

Expected: no output

- [ ] **Step 3: Refresh the live Quickshell config from this repo checkout**

Run:

```bash
env RYOKU_PATH=/home/omi/prowl/ryoku-arch bin/ryoku-refresh-quickshell
```

Expected:

```text
refreshed /home/omi/.config/quickshell/ryoku from /home/omi/prowl/ryoku-arch/config/quickshell/ryoku
```

Note: keep the `RYOKU_PATH=/home/omi/prowl/ryoku-arch` prefix. Without it, the helper refreshes from `~/.local/share/ryoku`, not from this working checkout.

- [ ] **Step 4: Restart Quickshell and verify the process came back**

Run:

```bash
bin/ryoku-restart-shell
pgrep -a quickshell
```

Expected:

```text
<pid> quickshell -c ryoku
```

- [ ] **Step 5: Perform the manual visual checklist**

Verify all of the following:

1. Clicking the center pill opens one unified home surface.
2. No dashboard tab bar is visible.
3. `Profile`, `Calendar`, `Clock`, and `Player` remain present together.
4. The right-side telemetry rail is visually distinct from `StatCard` and does not show repeated `Speedometer` widgets.
5. CPU renders as a custom graph with a large live percentage.
6. RAM renders as a thick occupancy bar with used/total text.
7. Temperatures read as heat lanes, not as duplicated gauges.
8. Network reads as split animated activity bars with live rates.
9. GPU and disk remain compact bottom summaries instead of headline cards.

---

## Self-Review

- **Spec coverage:** This plan removes the tab shell, preserves the four requested home cards, adds a dedicated telemetry rail, keeps the popup width on the first pass, and includes both static and live verification.
- **Placeholder scan:** No `TODO`, `TBD`, or “appropriate handling” placeholders remain. The new component path, smoke-test checks, and refresh commands are explicit.
- **Type consistency:** The plan reuses existing exported service names exactly as defined in the vendored Brain Shell tree: `CpuService`, `MemService`, `NetService`, `ThermalService`, `DiskService`, `CpuFreqService`, `GpuService`, and `EnvyControlService`.
