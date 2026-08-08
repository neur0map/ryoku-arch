import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: cpuPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-cpu"

    readonly property int barBottom: 35
    readonly property int gap: 8

    readonly property int cpuPct: root.systemCpuPercent
    property string gpuDriver: ""
    property int gpuUtil: 0
    property int gpuTemp: 0
    property int gpuMemUsed: 0
    property int gpuMemTotal: 0
    readonly property bool hasGpu: gpuDriver !== "" && gpuDriver !== "none"

    property real reveal: root.cpuVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.cpuVisible ? 160 : 120
            easing.type: root.cpuVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.cpuVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        onClicked: root.cpuVisible = false
    }

    Rectangle {
        id: card
        width: 320
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.pillRadius : 0
        color: root.bg
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }

        x: Math.round(Math.max(6, Math.min(root.cpuBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom" ? (parent.height - barBottom - gap - height) : (barBottom + gap)
        opacity: cpuPanel.reveal
        focus: root.cpuVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.cpuVisible = false;
                event.accepted = true;
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header ──
            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CPU \u00B7 GPU"
                    color: root.ink
                    font.family: root.mono
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2715"
                    color: closeMa.containsMouse ? root.seal : root.sumi
                    font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.cpuVisible = false
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── CPU (label · bar · % on one row) ──
            Item {
                width: parent.width
                height: 16
                UiText {
                    id: cpuLbl
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "CPU"; color: root.sumiHi
                    font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1
                }
                UiText {
                    id: cpuVal
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: cpuPanel.cpuPct + "%"; color: root.seal
                    font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
                Rectangle {
                    anchors.left: cpuLbl.right; anchors.leftMargin: 8
                    anchors.right: cpuVal.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8; radius: 4
                    color: root.fillActive
                    Rectangle {
                        width: parent.width * cpuPanel.cpuPct / 100
                        height: parent.height; radius: 4
                        color: root.seal
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }

            // ── GPU (label · bar · % on one row) ──
            Item {
                width: parent.width
                height: 16
                visible: cpuPanel.hasGpu
                UiText {
                    id: gpuLbl
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: "GPU"; color: root.sumiHi
                    font.family: root.mono; font.pixelSize: 11; font.letterSpacing: 1
                }
                UiText {
                    id: gpuVal
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: cpuPanel.gpuUtil + "%"; color: root.seal
                    font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                }
                Rectangle {
                    anchors.left: gpuLbl.right; anchors.leftMargin: 8
                    anchors.right: gpuVal.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    height: 8; radius: 4
                    color: root.fillActive
                    Rectangle {
                        width: parent.width * cpuPanel.gpuUtil / 100
                        height: parent.height; radius: 4
                        color: root.seal
                        Behavior on width { NumberAnimation { duration: 300 } }
                    }
                }
            }

            Row {
                width: parent.width
                visible: cpuPanel.hasGpu && cpuPanel.gpuTemp > 0
                UiText {
                    text: "Temperature"
                    color: root.sumiHi
                    font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.4
                }
                UiText {
                    text: cpuPanel.gpuTemp + "\u00B0C"
                    color: root.ink
                    font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.3
                }
            }

            Row {
                width: parent.width
                visible: cpuPanel.hasGpu && cpuPanel.gpuMemTotal > 0
                UiText {
                    text: "VRAM"
                    color: root.sumiHi
                    font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.4
                }
                UiText {
                    text: cpuPanel.gpuMemUsed + " / " + cpuPanel.gpuMemTotal + " MiB"
                    color: root.ink
                    font.family: root.mono; font.pixelSize: 11
                    width: parent.width * 0.3
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── button ──
            Rectangle {
                width: parent.width
                height: 28; radius: root.tileRadius
                color: btopMa.containsMouse ? root.fillPrimaryHover : root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: "Open btop"
                    color: root.paper
                    font.family: root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: btopMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.cpuVisible = false;
                        btopRunner.running = false;
                        btopRunner.running = true;
                    }
                }
            }
        }
    }

    Process {
        id: dataProc
        command: ["bash", "-c",
            "if command -v nvidia-smi &>/dev/null; then " +
            "  nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | " +
            "  awk -F', ' '{printf \"GPU %s %s %s %s\\n\", $1, $2, $3, $4}'; " +
            "elif [ -f /sys/class/drm/card0/device/gpu_busy_percent ]; then " +
            "  read p < /sys/class/drm/card0/device/gpu_busy_percent; " +
            "  echo \"GPU $p 0 0 0\"; " +
            "elif [ -f /sys/class/hwmon/hwmon2/device/gpu_busy_percent ]; then " +
            "  read p < /sys/class/hwmon/hwmon2/device/gpu_busy_percent; " +
            "  echo \"GPU $p 0 0 0\"; " +
            "else echo GPU none 0 0 0; " +
            "fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].trim().split(/\s+/)
                    if (parts[0] === "GPU" && parts.length >= 2) {
                        cpuPanel.gpuDriver = parts[1] === "none" ? "none" : "detected"
                        cpuPanel.gpuUtil = parseInt(parts[1]) || 0
                        cpuPanel.gpuTemp = parseInt(parts[2]) || 0
                        cpuPanel.gpuMemUsed = parseInt(parts[3]) || 0
                        cpuPanel.gpuMemTotal = parseInt(parts[4]) || 0
                    }
                }
            }
        }
    }

    Process {
        id: btopRunner
        command: ["bash", "-c", "kitty 'btop'"]
    }

    // refresh live while the panel is open
    Timer {
        interval: 1500
        running: cpuPanel.visible && root.cpuVisible
        repeat: true
        triggeredOnStart: true
        onTriggered: { dataProc.running = false; dataProc.running = true }
    }
}
