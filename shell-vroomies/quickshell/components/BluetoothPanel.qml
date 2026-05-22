import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: btPanel
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins {
        top:   root.btVisible ? 58 : -500
        right: 10
    }
    implicitHeight: 420
    implicitWidth:  320
    color: "transparent"
    focusable: true
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.btVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    Behavior on margins.top { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    property color bg:      zyuTheme.bar_bg
    property color fg:      zyuTheme.bar_fg
    property color accent:  zyuTheme.accent
    property color surface: zyuTheme.widget_bg
    property color muted:   Qt.rgba(zyuTheme.bar_fg.r, zyuTheme.bar_fg.g, zyuTheme.bar_fg.b, 0.38)
    property color danger:  "#f38ba8"

    property bool   btEnabled:       false
    property string connectedDevice: ""
    property var    btDevices:       []
    property bool   btScanning:      false

    function refreshBt() {
        if (btScanning) return
        btDevices  = []
        btScanning = true
        btStatusProc.running  = true
        btCurrentProc.running = true
        btScanProc.running    = true
    }

    Component.onCompleted: refreshBt()

    Connections {
        target: root
        function onBtVisibleChanged() {
            if (root.btVisible) btPanel.refreshBt()
        }
    }

    Process {
        id: btStatusProc
        command: ["bash", "-c", "bluetoothctl show | grep 'Powered: yes' >/dev/null && echo 'enabled' || echo 'disabled'"]
        stdout: SplitParser { onRead: data => btPanel.btEnabled = data.trim() === "enabled" }
    }

    Process {
        id: btCurrentProc
        command: ["bash", "-c", "bluetoothctl info | grep 'Name:' | cut -d' ' -f2-"]
        stdout: SplitParser { onRead: data => btPanel.connectedDevice = data.trim() }
    }

    Process {
        id: btScanProc
        command: ["bash", "-c", "bluetoothctl --timeout 5 scan on >/dev/null; bluetoothctl devices"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var parts = line.split(" ")
                if (parts.length < 3) return
                var mac  = parts[1]
                var name = parts.slice(2).join(" ")
                var current = btPanel.btDevices.slice()
                for (var i = 0; i < current.length; i++) { if (current[i].mac === mac) return }
                current.push({ name: name, mac: mac })
                btPanel.btDevices = current
            }
        }
        onExited: btPanel.btScanning = false
    }

    Process {
        id: btToggleProc
        command: ["bash", "-c", btPanel.btEnabled ? "bluetoothctl power off" : "bluetoothctl power on"]
        onExited: btPanel.refreshBt()
    }

    Process {
        id: btConnectProc
        property string mac: ""
        command: ["bash", "-c", "bluetoothctl connect " + mac]
        onExited: btPanel.refreshBt()
    }

    Process {
        id: btDisconnectProc
        command: ["bash", "-c", "bluetoothctl disconnect"]
        onExited: btPanel.connectedDevice = ""
    }

    Item {
        anchors.fill: parent
        focus: root.btVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.btVisible = false
                event.accepted = true
            }
        }

        Rectangle {
            anchors.fill: parent
            color: btPanel.bg
            radius: 18
            border.color: Qt.rgba(1,1,1,0.05)
            border.width: 1
            Behavior on color { ColorAnimation { duration: 300 } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                // ── Header ────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 36; height: 36; radius: 10
                        color: Qt.rgba(btPanel.accent.r, btPanel.accent.g, btPanel.accent.b, 0.12)
                        Behavior on color { ColorAnimation { duration: 300 } }
                        Text {
                            anchors.centerIn: parent
                            text: btPanel.btEnabled ? "󰂯" : "󰂲"
                            color: btPanel.btEnabled ? btPanel.accent : btPanel.muted
                            font.pixelSize: 19; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 1
                        Text {
                            text: "Bluetooth"
                            color: btPanel.fg
                            font.pixelSize: 14; font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                        Text {
                            text: btPanel.btEnabled
                                ? (btPanel.connectedDevice !== "" ? "● " + btPanel.connectedDevice : "On · No device")
                                : "Off"
                            color: btPanel.btEnabled
                                ? (btPanel.connectedDevice !== "" ? btPanel.accent : btPanel.muted)
                                : btPanel.muted
                            font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }

                    // Toggle
                    Rectangle {
                        width: 46; height: 24; radius: 12
                        color: btPanel.btEnabled ? btPanel.accent : Qt.rgba(0.3,0.3,0.3,0.5)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            width: 20; height: 20; radius: 10; y: 2
                            x: btPanel.btEnabled ? 24 : 2
                            color: btPanel.bg
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: btToggleProc.running = true
                        }
                    }
                }

                // ── Divider ───────────────────────────────
                Rectangle {
                    Layout.fillWidth: true; height: 1
                    color: Qt.rgba(1,1,1,0.06)
                }

                // ── Connected device card ─────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    radius: 12
                    visible: btPanel.connectedDevice !== ""
                    color: Qt.rgba(btPanel.accent.r, btPanel.accent.g, btPanel.accent.b, 0.08)
                    border.color: Qt.rgba(btPanel.accent.r, btPanel.accent.g, btPanel.accent.b, 0.22)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 300 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: "󰂱"; color: btPanel.accent
                            font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: btPanel.connectedDevice
                            color: btPanel.fg; font.pixelSize: 12; font.bold: true
                            font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 8
                            color: discMa.containsMouse
                                ? Qt.rgba(btPanel.danger.r, btPanel.danger.g, btPanel.danger.b, 0.18)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 130 } }
                            Text {
                                anchors.centerIn: parent; text: "󰅖"
                                color: discMa.containsMouse ? btPanel.danger : btPanel.muted
                                font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
                                Behavior on color { ColorAnimation { duration: 130 } }
                            }
                            MouseArea {
                                id: discMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: btDisconnectProc.running = true
                            }
                        }
                    }
                }

                // ── Devices header ────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    visible: btPanel.btEnabled

                    Text {
                        text: "Available devices"
                        color: btPanel.muted; font.pixelSize: 10
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Item { Layout.fillWidth: true }

                    // Scan count badge
                    Rectangle {
                        visible: btPanel.btDevices.length > 0
                        width: countLabel.implicitWidth + 10; height: 18; radius: 9
                        color: Qt.rgba(btPanel.accent.r, btPanel.accent.g, btPanel.accent.b, 0.12)
                        Text {
                            id: countLabel
                            anchors.centerIn: parent
                            text: btPanel.btDevices.length
                            color: btPanel.accent; font.pixelSize: 9; font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }

                    Item { width: 6 }

                    // Reload
                    Item {
                        width: 22; height: 22
                        Text {
                            anchors.centerIn: parent; text: "󰑐"
                            color: reloadMa.containsMouse ? btPanel.accent : btPanel.muted
                            font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 130 } }
                            RotationAnimation on rotation {
                                loops: Animation.Infinite; from: 0; to: 360; duration: 900
                                running: btPanel.btScanning
                            }
                        }
                        MouseArea {
                            id: reloadMa; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: btPanel.refreshBt()
                        }
                    }
                }

                // ── Device list ───────────────────────────
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: btPanel.surface; radius: 14; clip: true
                    Behavior on color { ColorAnimation { duration: 300 } }

                    // Empty / loading state
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: btPanel.btDevices.length === 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: !btPanel.btEnabled ? "󰂲" : btPanel.btScanning ? "󰑐" : "󰂯"
                            color: btPanel.muted; font.pixelSize: 28
                            font.family: "JetBrainsMono Nerd Font"
                            RotationAnimation on rotation {
                                loops: Animation.Infinite; from: 0; to: 360; duration: 900
                                running: btPanel.btScanning && btPanel.btDevices.length === 0
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: !btPanel.btEnabled ? "Bluetooth is off"
                                : btPanel.btScanning  ? "Scanning..."
                                : "No devices found"
                            color: btPanel.muted; font.pixelSize: 11
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 3
                        clip: true
                        model: btPanel.btDevices
                        visible: btPanel.btDevices.length > 0

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 44; radius: 10
                            color: itemMa.containsMouse
                                ? Qt.rgba(btPanel.accent.r, btPanel.accent.g, btPanel.accent.b, 0.1)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }

                            property bool isConnected: modelData.name === btPanel.connectedDevice

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12; anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: parent.parent.isConnected ? "󰂱" : "󰂯"
                                    color: parent.parent.isConnected ? btPanel.accent : btPanel.muted
                                    font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    Text {
                                        text: modelData.name
                                        color: parent.parent.parent.isConnected ? btPanel.accent : btPanel.fg
                                        font.pixelSize: 12; font.bold: parent.parent.parent.isConnected
                                        font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                    Text {
                                        text: modelData.mac
                                        color: btPanel.muted; font.pixelSize: 9
                                        font.family: "JetBrainsMono Nerd Font"
                                        opacity: 0.6
                                    }
                                }

                                Rectangle {
                                    width: 20; height: 20; radius: 5
                                    visible: parent.parent.parent.isConnected
                                    color: Qt.rgba(btPanel.accent.r, btPanel.accent.g, btPanel.accent.b, 0.18)
                                    Text {
                                        anchors.centerIn: parent; text: "✓"
                                        color: btPanel.accent; font.pixelSize: 10; font.bold: true
                                    }
                                }
                            }

                            MouseArea {
                                id: itemMa; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    btConnectProc.mac = modelData.mac
                                    btConnectProc.running = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
