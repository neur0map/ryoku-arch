import QtQuick
import "../modules"
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import "../IconMap.js" as IconMap

PanelWindow {
    id: btPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-bluetooth"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property bool btOn: false
    property bool scanning: false
    property var devices: []   // [{name, mac, connected, paired}]
    readonly property var shownDevices: devices.slice(0, 8)
    readonly property int numConnected: {
        var n = 0
        for (var i = 0; i < devices.length; i++) if (devices[i].connected) n++
        return n
    }
    property string connCmd: ""
    readonly property color deviceActionFill: Qt.rgba(
        root.paper.r * 0.88,
        root.paper.g * 0.88,
        root.paper.b * 0.88,
        1.0)

    function refresh() { btData.running = false; btData.running = true }

    function activateDevice(device) {
        if (!device || connProc.running) return
        var mac = String(device.mac || "")
        if (!/^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$/.test(mac)) return
        if (device.connected) {
            connCmd = "bluetoothctl disconnect " + mac
        } else if (device.paired) {
            connCmd = "bluetoothctl connect " + mac
        } else {
            connCmd = "bluetoothctl trust " + mac
                + " && bluetoothctl pair " + mac
                + " && bluetoothctl connect " + mac
        }
        connProc.running = true
    }

    // The bash model carries only {name,mac,connected,paired}; battery/icon/state
    // come live off Quickshell.Bluetooth, matched by MAC.
    function btDeviceFor(mac) {
        if (typeof Bluetooth === "undefined" || !Bluetooth || !Bluetooth.devices) return null
        var m = String(mac || "").toUpperCase()
        if (!m) return null
        var vals = Bluetooth.devices.values
        for (var i = 0; i < vals.length; i++) {
            var d = vals[i]
            if (d && String(d.address || "").toUpperCase() === m) return d
        }
        return null
    }
    // BlueZ phone charge is coarse/stale without provenance; suppress it (mirrors Shibumi).
    function batteryText(dev) {
        if (!dev || !dev.batteryAvailable) return ""
        var ic = String(dev.icon || "").toLowerCase()
        if (ic === "phone" || ic === "smartphone") return ""
        var b = Number(dev.battery)
        if (!isFinite(b) || b < 0 || b > 1) return ""
        return Math.round(b * 100) + "%"
    }
    function typeLabel(dev) {
        var ic = String(dev && dev.icon ? dev.icon : "").toLowerCase()
        if (ic === "input-gaming") return "Controller"
        if (ic === "audio-headphones") return "Headphones"
        if (ic === "audio-headset") return "Headset"
        if (ic === "audio-card") return "Speaker"
        if (ic === "input-mouse") return "Mouse"
        if (ic === "input-keyboard") return "Keyboard"
        if (ic === "phone") return "Phone"
        return ic ? ic : "Device"
    }

    property real reveal: root.bluetoothVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.bluetoothVisible ? 160 : 120
            easing.type: root.bluetoothVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.bluetoothVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.bluetoothVisible = false }

    Rectangle {
        id: card
        width: 300
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: btPanel.root
            ownerActive: btPanel.root.bluetoothVisible
            targetX: btPanel.root.bluetoothBarX
            reveal: btPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.bluetoothBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - btPanel.reveal)
            : (barBottom + gap) - 2 * (1 - btPanel.reveal)
        opacity: btPanel.reveal
        focus: root.bluetoothVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.bluetoothVisible = false; event.accepted = true }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            // ── header + power toggle ──
            Item {
                width: parent.width
                height: 24
                Row {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Bluetooth"
                        color: root.ink; font.family: root.mono; font.pixelSize: 13
                        font.letterSpacing: 2; font.weight: Font.Medium
                    }
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: btPanel.btOn && btPanel.numConnected > 0
                        spacing: 3
                        IconText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: IconMap.icon("bluetooth_connected")
                            color: root.seal
                            font.pixelSize: 13
                        }
                        UiText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(btPanel.numConnected)
                            color: root.seal
                            font.family: root.mono; font.pixelSize: 11
                        }
                    }
                }
                Row {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    // power toggle pill
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46; height: 20; radius: 10
                        color: btPanel.btOn ? root.fillActive
                                            : root.fillIdle
                        border.color: btPanel.btOn ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Rectangle {
                            width: 14; height: 14; radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            x: btPanel.btOn ? parent.width - width - 3 : 3
                            color: btPanel.btOn ? root.seal : root.sumi
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { powerProc.running = false; powerProc.running = true }
                        }
                    }
                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                        Behavior on color { ColorAnimation { duration: 120 } }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.bluetoothVisible = false }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            // ── off state ──
            UiText {
                visible: !btPanel.btOn
                width: parent.width; horizontalAlignment: Text.AlignHCenter
                text: "Bluetooth is off"
                color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.35)
                font.family: root.mono; font.pixelSize: 11
                topPadding: 4; bottomPadding: 4
            }

            // ── scan control (only when on) ──
            Rectangle {
                visible: btPanel.btOn
                width: parent.width
                height: 28; radius: root.panelButtonRadius
                readonly property bool hovered: scanMa.containsMouse
                color: btPanel.scanning ? root.fillActive
                       : hovered ? root.fillHover : root.fillIdle
                border.color: (btPanel.scanning || hovered) ? root.seal : root.sep
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText {
                    anchors.centerIn: parent
                    text: btPanel.scanning ? "Scanning…" : "Scan for devices"
                    color: btPanel.scanning ? root.seal : root.ink
                    font.family: root.mono; font.pixelSize: 11
                }
                MouseArea {
                    id: scanMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !btPanel.scanning
                    onClicked: { scanProc.running = false; scanProc.running = true }
                }
            }

            // ── device list ──
            Column {
                width: parent.width
                spacing: 4
                visible: btPanel.btOn
                Repeater {
                    model: btPanel.shownDevices
                    delegate: Rectangle {
                        id: devTile
                        required property var modelData
                        property bool expanded: false
                        readonly property var nativeDev: btPanel.btDeviceFor(modelData.mac)
                        readonly property string batteryText: btPanel.batteryText(nativeDev)
                        readonly property bool canExpand: modelData.connected
                        readonly property bool hovered: tileHover.containsMouse || actionMa.containsMouse || infoMa.containsMouse
                        readonly property int rowHeight: 42
                        width: col.width
                        height: rowHeight + (expanded && canExpand ? detailCol.implicitHeight + 10 : 0)
                        radius: root.panelButtonRadius
                        clip: true
                        color: modelData.connected ? root.fillActive
                               : hovered ? root.fillHover : root.fillIdle
                        border.color: modelData.connected ? root.seal
                                      : hovered ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        MouseArea {
                            id: tileHover
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true
                        }

                        Item {
                            id: rowItem
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            height: devTile.rowHeight

                            Column {
                                anchors.left: parent.left; anchors.leftMargin: 8
                                anchors.right: devTile.canExpand ? infoPill.left : actionButton.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                UiText {
                                    width: parent.width
                                    text: devTile.modelData.name
                                    color: root.ink; font.family: root.mono; font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                                UiText {
                                    width: parent.width
                                    text: devTile.modelData.connected
                                          ? (devTile.batteryText !== "" ? "Connected · " + devTile.batteryText : "Connected")
                                          : (devTile.modelData.paired ? "Paired" : "Available")
                                    color: root.ink
                                    font.family: root.mono; font.pixelSize: 10; font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                            }

                            // info toggle: connected rows only, reveals the inline detail area
                            Rectangle {
                                id: infoPill
                                visible: devTile.canExpand
                                anchors.right: actionButton.left; anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18; height: 18; radius: 9
                                color: devTile.expanded ? root.fillActive
                                       : infoMa.containsMouse ? root.fillHover : root.fillIdle
                                border.color: (devTile.expanded || infoMa.containsMouse) ? root.seal : root.sep
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                UiText {
                                    anchors.centerIn: parent
                                    text: "!"
                                    color: (devTile.expanded || infoMa.containsMouse) ? root.seal : root.sumi
                                    font.family: root.mono; font.pixelSize: 11; font.weight: Font.Medium
                                }
                                MouseArea {
                                    id: infoMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: devTile.expanded = !devTile.expanded
                                }
                            }

                            Rectangle {
                                id: actionButton
                                anchors.right: parent.right; anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: actionLabel.implicitWidth + 14
                                height: 24; radius: root.panelButtonRadius
                                color: btPanel.deviceActionFill
                                border.color: root.sep
                                border.width: 1
                                opacity: connProc.running ? 0.45 : 1
                                UiText {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: devTile.modelData.connected ? "Disconnect" : "Connect"
                                    color: actionMa.containsMouse ? root.seal : root.ink
                                    font.family: root.mono; font.pixelSize: 10
                                }
                                MouseArea {
                                    id: actionMa
                                    anchors.fill: parent
                                    enabled: !connProc.running
                                    hoverEnabled: true
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: btPanel.activateDevice(devTile.modelData)
                                }
                            }
                        }

                        // inline detail: battery / type / address, gated by the info toggle
                        Column {
                            id: detailCol
                            anchors.top: rowItem.bottom; anchors.topMargin: 2
                            anchors.left: parent.left; anchors.leftMargin: 8
                            anchors.right: parent.right; anchors.rightMargin: 8
                            spacing: 2
                            visible: devTile.expanded && devTile.canExpand
                            opacity: visible ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 120 } }

                            Item {
                                width: parent.width; height: 14
                                visible: devTile.batteryText !== ""
                                UiText { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Battery"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
                                UiText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: devTile.batteryText; color: root.ink; font.family: root.mono; font.pixelSize: 10 }
                            }
                            Item {
                                width: parent.width; height: 14
                                UiText { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Type"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
                                UiText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: btPanel.typeLabel(devTile.nativeDev); color: root.ink; font.family: root.mono; font.pixelSize: 10; elide: Text.ElideRight }
                            }
                            Item {
                                width: parent.width; height: 14
                                UiText { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "Address"; color: root.sumiHi; font.family: root.mono; font.pixelSize: 10; font.letterSpacing: 1 }
                                UiText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: String(devTile.modelData.mac || ""); color: root.ink; font.family: root.mono; font.pixelSize: 10 }
                            }
                        }
                    }
                }
                UiText {
                    visible: btPanel.btOn && btPanel.devices.length === 0
                    width: parent.width; horizontalAlignment: Text.AlignHCenter
                    text: btPanel.scanning ? "Searching…" : "No devices, tap Scan"
                    color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.3)
                    font.family: root.mono; font.pixelSize: 11
                    topPadding: 2; bottomPadding: 2
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Rectangle {
                width: parent.width
                height: 28; radius: root.panelButtonRadius
                color: btSetMa.containsMouse ? root.fillPrimaryHover : root.seal
                Behavior on color { ColorAnimation { duration: 120 } }
                UiText { anchors.centerIn: parent; text: "Bluetooth settings"; color: root.paper; font.family: root.mono; font.pixelSize: 11 }
                MouseArea {
                    id: btSetMa
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.bluetoothVisible = false; btRunner.running = false; btRunner.running = true }
                }
            }
        }
    }

    // ── data: power state + device list with connected/paired flags ──
    Process {
        id: btData
        command: ["bash", "-c",
            "if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then " +
            "  echo ON; " +
            "  conn=$(bluetoothctl devices Connected 2>/dev/null | awk '{print $2}'); " +
            "  paired=$(bluetoothctl devices Paired 2>/dev/null | awk '{print $2}'); " +
            "  bluetoothctl devices 2>/dev/null | while read -r _ mac rest; do " +
            "    c=0; p=0; " +
            "    printf '%s\\n' \"$conn\"   | grep -qx \"$mac\" && c=1; " +
            "    printf '%s\\n' \"$paired\" | grep -qx \"$mac\" && p=1; " +
            "    echo \"$c|$p|$mac|$rest\"; " +
            "  done; " +
            "else echo OFF; fi"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                if (lines[0] !== "ON") { btPanel.btOn = false; btPanel.devices = []; return }
                btPanel.btOn = true
                var devs = []
                for (var i = 1; i < lines.length; i++) {
                    var parts = lines[i].split("|")
                    if (parts.length < 4) continue
                    var name = parts.slice(3).join("|").trim()
                    if (!name || name === parts[2]) name = parts[2]   // fall back to mac
                    devs.push({
                        connected: parts[0] === "1",
                        paired:    parts[1] === "1",
                        mac:       parts[2],
                        name:      name
                    })
                }
                // connected first, then paired, then the rest
                devs.sort(function(a, b) {
                    var ra = a.connected ? 0 : a.paired ? 1 : 2
                    var rb = b.connected ? 0 : b.paired ? 1 : 2
                    return ra - rb
                })
                btPanel.devices = devs
            }
        }
    }

    // ── power on/off ──
    Process {
        id: powerProc
        command: ["bash", "-c", "bluetoothctl power " + (btPanel.btOn ? "off" : "on")]
        running: false
        onExited: btPanel.refresh()
    }

    // ── timed discovery scan ──
    Process {
        id: scanProc
        command: ["bash", "-c", "bluetoothctl --timeout 10 scan on >/dev/null 2>&1"]
        running: false
        onRunningChanged: { btPanel.scanning = running; if (!running) btPanel.refresh() }
    }
    Timer {
        interval: 1500; repeat: true
        running: btPanel.scanning && btPanel.visible
        onTriggered: btPanel.refresh()
    }

    // ── connect / disconnect / pair ──
    Process {
        id: connProc
        command: ["bash", "-c", btPanel.connCmd]
        running: false
        onExited: btPanel.refresh()
    }

    Process { id: btRunner; command: ["bash", "-c", root.launchBtCmd] }

    onVisibleChanged: { if (visible) btPanel.refresh() }
}
