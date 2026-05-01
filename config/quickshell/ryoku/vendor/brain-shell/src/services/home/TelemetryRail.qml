import QtQuick
import Quickshell.Io
import "../../"
import "../../services/"

// Telemetry rail — wavy-line visualisation. Each metric's filled length
// encodes its value (0..1); the wavelength is fixed in pixels so longer
// fills naturally show more cycles. A passive phase animation keeps the
// lines breathing even when values are static.
//
// All numeric data uses JetBrains Mono to match ClockCard / PlayerCard /
// CalendarCard typography.
Item {
    id: root

    readonly property int railRadius:       Theme.cornerRadius + 6
    readonly property int contentMargin:    10
    readonly property int sectionSpacing:    8
    readonly property int cpuSectionH:      88
    readonly property int memorySectionH:   42
    readonly property int thermalsSectionH: 64
    readonly property int networkSectionH:  70
    readonly property int summarySectionH:  68

    property real _upBps:   0
    property real _downBps: 0
    property real _netPeak: 65536
    property string activeDisplayName: "Display"
    property int currentDisplayRefreshHz: 0
    readonly property string displaySummary: root.currentDisplayRefreshHz > 0
        ? root.activeDisplayName + " · " + root.currentDisplayRefreshHz + " Hz"
        : root.activeDisplayName

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

    readonly property bool   usingDgpu: gpu.dgpu.active
    readonly property string gpuLabel:  usingDgpu ? "dGPU" : "iGPU"
    readonly property string gpuValue:  usingDgpu
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

    function _tempColor(t) {
        if (t >= 85) return "#f38ba8"
        if (t >= 70) return "#f5c47a"
        if (t >= 60) return "#fab387"
        return "#8bd5ca"
    }

    Process {
        id: displayRead
        command: ["hyprctl", "monitors", "-j"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var mons = JSON.parse(text)
                    if (!mons || mons.length === 0) return

                    var mon = mons[0]
                    for (var i = 0; i < mons.length; i++) {
                        if (mons[i].focused) {
                            mon = mons[i]
                            break
                        }
                    }

                    root.activeDisplayName = mon.name || "Display"
                    root.currentDisplayRefreshHz = Math.round(mon.refreshRate || 0)
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: advancedLauncher
        command: ["ryoku-launch-tui", "btop"]
        running: false
    }

    Connections {
        target: PowerProfile
        function onDisplayRefreshGenerationChanged() {
            displayRead.running = false
            displayRead.running = true
        }
    }

    Timer {
        interval: 1000
        running:  root.visible
        repeat:   true
        onTriggered: {
            root._upBps   = root._parseBps(net.upSpeed)
            root._downBps = root._parseBps(net.downSpeed)
            root._netPeak = Math.max(65536, root._upBps, root._downBps, root._netPeak * 0.92)
        }
    }

    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        onTriggered: {
            displayRead.running = false
            displayRead.running = true
        }
    }

    Component.onCompleted: displayRead.running = true

    Rectangle {
        anchors.fill: parent
        radius:       root.railRadius
        gradient: Gradient {
            GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, 0.08) }
            GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.04) }
            GradientStop { position: 1.0;  color: Qt.rgba(1, 1, 1, 0.06) }
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
            margins: root.contentMargin
        }
        spacing: root.sectionSpacing

        // ── CPU ──────────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: root.cpuSectionH

            Text {
                id: telemetryLabel
                anchors.left: parent.left
                anchors.top:  parent.top
                text:           "Telemetry"
                font.pixelSize: 11
                font.weight:    Font.DemiBold
                color:          Qt.rgba(1, 1, 1, 0.45)
            }

            Rectangle {
                id: advancedButton
                anchors.right: parent.right
                anchors.verticalCenter: telemetryLabel.verticalCenter
                width: 66
                height: 18
                radius: 6
                color: advancedHit.containsMouse
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                    : Qt.rgba(1, 1, 1, 0.055)
                border.width: 1
                border.color: advancedHit.containsMouse
                    ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.44)
                    : Qt.rgba(1, 1, 1, 0.12)

                Behavior on color {
                    enabled: !Theme.staticMode
                    ColorAnimation { duration: 130 }
                }
                Behavior on border.color {
                    enabled: !Theme.staticMode
                    ColorAnimation { duration: 130 }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Advanced"
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                    color: advancedHit.containsMouse
                        ? Theme.active
                        : Qt.rgba(1, 1, 1, 0.58)
                }

                MouseArea {
                    id: advancedHit
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        advancedLauncher.running = false
                        advancedLauncher.running = true
                        Popups.closeAll()
                    }
                }
            }

            Text {
                id: cpuPct
                anchors.left:      parent.left
                anchors.top:       parent.top
                anchors.topMargin: 18
                text:           Math.round(cpu.usagePercent) + "%"
                font.pixelSize: 32
                font.weight:    Font.Bold
                font.family:    "JetBrains Mono"
                font.letterSpacing: -1
                color:          Theme.active
            }

            // ── Power-save toggle ───────────────────────────────────────────
            // Single switch — off = normal (performance), on = power saving.
            // Pure shapes, no icon font, so it always renders regardless of
            // Nerd Font fallback. Tap flips PowerProfile.mode → side-effects:
            // brightness 45 %, 60 Hz when advertised, CPU governor / EPP
            // "powersave", and Theme.staticMode = true (freezes motion).
            Item {
                id: powerToggle
                anchors.left:           cpuPct.right
                anchors.leftMargin:     10
                anchors.right:          parent.right
                anchors.verticalCenter: cpuPct.verticalCenter
                height: 34
                clip: true

                readonly property bool savingOn: PowerProfile.mode === "powersave"

                Text {
                    id: powerSaverLabel
                    anchors.left:           parent.left
                    anchors.right:          parent.right
                    anchors.top:            parent.top
                    horizontalAlignment:    Text.AlignRight
                    elide:                  Text.ElideRight
                    text:           "POWER SAVER"
                    font.pixelSize: 9
                    font.weight:    Font.Bold
                    font.family:    "JetBrains Mono"
                    font.letterSpacing: 0
                    color: powerToggle.savingOn
                        ? Theme.active
                        : Qt.rgba(1, 1, 1, 0.55)
                }

                Item {
                    id: switchControl
                    anchors.right:          parent.right
                    anchors.top:            powerSaverLabel.bottom
                    anchors.topMargin:      2
                    width:  34
                    height: 18

                    Rectangle {
                        id: track
                        anchors.fill: parent
                        radius: height / 2
                        color: powerToggle.savingOn
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.55)
                            : Qt.rgba(1, 1, 1, 0.12)
                        border.color: powerToggle.savingOn
                            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.85)
                            : Qt.rgba(1, 1, 1, 0.28)
                        border.width: 1

                        Behavior on color {
                            enabled: !Theme.staticMode
                            ColorAnimation { duration: 160 }
                        }
                        Behavior on border.color {
                            enabled: !Theme.staticMode
                            ColorAnimation { duration: 160 }
                        }
                    }

                    Rectangle {
                        id: knob
                        width:  parent.height - 4
                        height: parent.height - 4
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: powerToggle.savingOn ? parent.width - width - 2 : 2
                        color: powerToggle.savingOn ? "#ffffff" : Qt.rgba(1, 1, 1, 0.62)

                        Behavior on x {
                            enabled: !Theme.staticMode
                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                        }
                        Behavior on color {
                            enabled: !Theme.staticMode
                            ColorAnimation { duration: 160 }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: PowerProfile.toggle()
                    }
                }
            }

            Row {
                anchors.left:      parent.left
                anchors.top:       cpuPct.bottom
                anchors.topMargin: 2
                spacing: 6

                Text {
                    text:           "CPU"
                    font.pixelSize: 10
                    font.weight:    Font.DemiBold
                    color:          Qt.rgba(1, 1, 1, 0.55)
                }
                Text {
                    text:           "·"
                    font.pixelSize: 10
                    color:          Qt.rgba(1, 1, 1, 0.35)
                }
                Text {
                    text:           cpuFreq.curFreqStr
                    font.pixelSize: 10
                    font.family:    "JetBrains Mono"
                    color:          Qt.rgba(1, 1, 1, 0.55)
                }
            }

            WaveBar {
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                value:        Math.max(0, Math.min(1, cpu.usagePercent / 100))
                color:        Theme.active
                wavelength:   16
                amplitude:    3
                strokeWidth:  2
            }
        }

        // ── Memory ───────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: root.memorySectionH

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
                font.pixelSize: 10
                font.family:    "JetBrains Mono"
                color:          Qt.rgba(1, 1, 1, 0.65)
            }

            Row {
                anchors.left:      parent.left
                anchors.bottom:    parent.bottom
                spacing: 6

                Text {
                    text:           Math.round(mem.usagePercent) + "%"
                    font.pixelSize: 10
                    font.family:    "JetBrains Mono"
                    font.weight:    Font.DemiBold
                    color:          "#cba6f7"
                }
            }

            WaveBar {
                anchors.left:        parent.left
                anchors.leftMargin:  36
                anchors.right:       parent.right
                anchors.bottom:      parent.bottom
                value:        Math.max(0, Math.min(1, mem.usagePercent / 100))
                color:        "#cba6f7"
                wavelength:   14
                amplitude:    2.5
                strokeWidth:  2
            }
        }

        // ── Thermals ─────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: root.thermalsSectionH

            Text {
                anchors.left: parent.left
                anchors.top:  parent.top
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
                    required property int index
                    width:  parent.width
                    height: 16
                    y:      17 + index * 17

                    Text {
                        anchors.left:           parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text:           modelData.label
                        font.pixelSize: 10
                        font.weight:    Font.DemiBold
                        color:          Qt.rgba(1, 1, 1, 0.42)
                    }

                    WaveBar {
                        anchors.left:           parent.left
                        anchors.leftMargin:     32
                        anchors.right:          tempLabel.left
                        anchors.rightMargin:    8
                        anchors.verticalCenter: parent.verticalCenter
                        value:        Math.max(0, Math.min(1, modelData.temp / 100))
                        color:        root._tempColor(modelData.temp)
                        wavelength:   12
                        amplitude:    2
                        strokeWidth:  2
                    }

                    Text {
                        id: tempLabel
                        anchors.right:          parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text:           modelData.text
                        font.pixelSize: 10
                        font.family:    "JetBrains Mono"
                        color:          Qt.rgba(1, 1, 1, 0.68)
                    }
                }
            }

            Text {
                text:           root.fanSummary
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                elide:          Text.ElideRight
                font.pixelSize: 9
                font.family:    "JetBrains Mono"
                color:          Qt.rgba(1, 1, 1, 0.35)
            }
        }

        // ── Network ──────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: root.networkSectionH

            Text {
                anchors.left: parent.left
                anchors.top:  parent.top
                text:           "Network"
                font.pixelSize: 11
                font.weight:    Font.DemiBold
                color:          Qt.rgba(1, 1, 1, 0.45)
            }

            Repeater {
                model: [
                    { label: "UP",   color: "#90ef90", value: net.upSpeed,   fill: Math.max(0, Math.min(1, root._upBps   / root._netPeak)) },
                    { label: "DOWN", color: "#a6d0f7", value: net.downSpeed, fill: Math.max(0, Math.min(1, root._downBps / root._netPeak)) }
                ]
                delegate: Item {
                    required property var modelData
                    required property int index
                    width:  parent.width
                    height: 18
                    y:      19 + index * 19

                    Text {
                        anchors.left:           parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text:           modelData.label
                        font.pixelSize: 10
                        font.weight:    Font.DemiBold
                        color:          modelData.color
                    }

                    WaveBar {
                        anchors.left:           parent.left
                        anchors.leftMargin:     40
                        anchors.right:          speedLabel.left
                        anchors.rightMargin:    8
                        anchors.verticalCenter: parent.verticalCenter
                        value:        modelData.fill
                        color:        modelData.color
                        wavelength:   12
                        amplitude:    2
                        strokeWidth:  2
                    }

                    Text {
                        id: speedLabel
                        anchors.right:          parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text:           modelData.value
                        font.pixelSize: 10
                        font.family:    "JetBrains Mono"
                        color:          Qt.rgba(1, 1, 1, 0.68)
                    }
                }
            }

            Text {
                text:           net.iface !== "—" ? ("Interface  " + net.iface) : "Interface unavailable"
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottom: parent.bottom
                elide:          Text.ElideRight
                font.pixelSize: 9
                font.family:    "JetBrains Mono"
                color:          Qt.rgba(1, 1, 1, 0.35)
            }
        }

        // ── GPU + Disk summary ───────────────────────────────────────────────
        Item {
            width:  parent.width
            height: root.summarySectionH

            Column {
                anchors.fill: parent
                spacing: 5

                Item {
                    width:  parent.width
                    height: 20

                    Text {
                        anchors.left:           parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.gpuLabel
                        font.pixelSize: 10
                        font.weight:    Font.DemiBold
                        color:          Qt.rgba(1, 1, 1, 0.42)
                    }

                    Text {
                        anchors.right:          parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.gpuValue
                        font.pixelSize: 10
                        font.family:    "JetBrains Mono"
                        color:          root.usingDgpu ? Qt.rgba(1, 1, 1, 0.70) : Qt.rgba(1, 1, 1, 0.42)
                    }

                    WaveBar {
                        anchors.left:    parent.left
                        anchors.right:   parent.right
                        anchors.bottom:  parent.bottom
                        value:        root.gpuFill
                        color:        root.usingDgpu ? "#a6e3a1" : Qt.rgba(1, 1, 1, 0.35)
                        wavelength:   14
                        amplitude:    2
                        strokeWidth:  2
                    }
                }

                Item {
                    width:  parent.width
                    height: 22
                    visible: root.rootDisk !== null

                    Text {
                        anchors.left:           parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.rootDisk ? ("Disk " + root.rootDisk.mount) : "Disk"
                        font.pixelSize: 10
                        font.weight:    Font.DemiBold
                        color:          Qt.rgba(1, 1, 1, 0.42)
                    }

                    Text {
                        anchors.right:          parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text:           root.rootDisk ? (root.rootDisk.usedStr + " / " + root.rootDisk.totalStr) : "—"
                        font.pixelSize: 10
                        font.family:    "JetBrains Mono"
                        color:          Qt.rgba(1, 1, 1, 0.68)
                    }

                    WaveBar {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        anchors.bottom: parent.bottom
                        value:        root.rootDisk ? Math.max(0, Math.min(1, root.rootDisk.usedPct / 100)) : 0
                        color:        root.rootDisk && root.rootDisk.usedPct >= 85 ? "#f38ba8" : Theme.active
                        wavelength:   14
                        amplitude:    2
                        strokeWidth:  2
                    }
                }

                Rectangle {
                    width:  parent.width
                    height: 16
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.035)
                    border.color: Qt.rgba(1, 1, 1, 0.07)
                    border.width: 1

                    Text {
                        id: displayLabel
                        anchors.left: parent.left
                        anchors.leftMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Display"
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                        color: Qt.rgba(1, 1, 1, 0.36)
                    }

                    Text {
                        anchors.left: displayLabel.right
                        anchors.leftMargin: 6
                        anchors.right: parent.right
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignRight
                        text: root.displaySummary
                        font.pixelSize: 8
                        font.family: "JetBrains Mono"
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        color: Qt.rgba(1, 1, 1, 0.58)
                    }
                }
            }
        }
    }
}
