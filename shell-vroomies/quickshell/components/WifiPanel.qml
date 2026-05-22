import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: wifiPanel
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins {
        top: root.wifiVisible ? 58 : -500
        right: 10
    }
    implicitHeight: 440
    implicitWidth: 340
    color: "transparent"
    focusable: true
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.wifiVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Behavior on margins.top {
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    readonly property color bg:      zyuTheme.bar_bg
    readonly property color fg:      zyuTheme.bar_fg
    readonly property color accent:  zyuTheme.accent
    readonly property color muted:   Qt.rgba(zyuTheme.bar_fg.r, zyuTheme.bar_fg.g, zyuTheme.bar_fg.b, 0.4)
    readonly property color danger:  "#f38ba8"

    property bool wifiEnabled:    true
    property string currentSSID:  ""
    property int    wifiSignal:   0
    property var    wifiNetworks: []
    property bool   wifiScanning: false
    property string passwordSSID: ""
    property bool   wifiConnecting: false

    function refreshWifi() {
        wifiNetworks = []
        wifiScanning = true
        wifiCurrentProc.running = true
        wifiScanProc.running = true
    }

    Component.onCompleted: {
        wifiStatusProc.running = true
        refreshWifi()
    }

    Connections {
        target: root
        function onWifiVisibleChanged() {
            if (root.wifiVisible) {
                focusTimer.start()
                wifiPanel.refreshWifi()
            }
        }
    }

    Timer { id: focusTimer;   interval: 50;  repeat: false; onTriggered: { wifiPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive; releaseTimer.start() } }
    Timer { id: releaseTimer; interval: 100; repeat: false; onTriggered: wifiPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand }

    Process {
        id: wifiStatusProc
        command: ["bash", "-c", "nmcli radio wifi 2>/dev/null || echo 'disabled'"]
        stdout: SplitParser { onRead: data => wifiPanel.wifiEnabled = data.trim() === "enabled" }
    }

    Process {
        id: wifiCurrentProc
        command: ["bash", "-c", "nmcli -t -f active,ssid,signal dev wifi 2>/dev/null | grep '^yes' | head -1"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(":")
                if (parts.length >= 3) {
                    wifiPanel.currentSSID = parts[1]
                    wifiPanel.wifiSignal  = parseInt(parts[2]) || 0
                } else {
                    wifiPanel.currentSSID = ""
                    wifiPanel.wifiSignal  = 0
                }
            }
        }
    }

    Process {
        id: wifiScanProc
        command: ["bash", "-c", "nmcli -t -f ssid,signal,security dev wifi list --rescan yes 2>/dev/null | head -20"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return
                var parts = line.split(":")
                if (parts.length < 2) return
                var ssid = parts[0]
                if (ssid === "" || ssid === wifiPanel.currentSSID) return
                var signal = parseInt(parts[1]) || 0
                var security = parts.length >= 3 ? parts[2] : ""
                var current = wifiPanel.wifiNetworks.slice()
                for (var i = 0; i < current.length; i++) { if (current[i].ssid === ssid) return }
                current.push({ ssid: ssid, signal: signal, security: security })
                wifiPanel.wifiNetworks = current
            }
        }
        onExited: wifiPanel.wifiScanning = false
    }

    Process {
        id: wifiToggleProc
        command: ["bash", "-c", wifiPanel.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on"]
        onExited: { wifiStatusProc.running = true; if (wifiPanel.wifiEnabled) wifiPanel.refreshWifi() }
    }

    Process {
        id: wifiConnectProc
        property string ssid: ""
        property string password: ""
        command: {
            if (password !== "")
                return ["bash", "-c", "nmcli dev wifi connect '" + ssid + "' password '" + password + "' 2>&1"]
            else
                return ["bash", "-c", "nmcli dev wifi connect '" + ssid + "' 2>&1"]
        }
        onExited: {
            wifiPanel.wifiConnecting = false
            wifiPanel.passwordSSID   = ""
            wifiCurrentProc.running  = true
        }
    }

    Process {
        id: wifiDisconnectProc
        command: ["bash", "-c", "nmcli dev disconnect $(nmcli -t -f device,type dev | grep ':wifi$' | cut -d: -f1 | head -1) 2>/dev/null"]
        onExited: { wifiPanel.currentSSID = ""; wifiPanel.wifiSignal = 0 }
    }

    Item {
        anchors.fill: parent
        focus: root.wifiVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (wifiPanel.passwordSSID !== "") {
                    wifiPanel.passwordSSID = ""
                    wifiPassInput.text = ""
                } else {
                    root.wifiVisible = false
                }
                event.accepted = true
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(wifiPanel.bg.r, wifiPanel.bg.g, wifiPanel.bg.b, 0.92)
            radius: 18
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 36; height: 36; radius: 12
                        color: Qt.rgba(wifiPanel.accent.r, wifiPanel.accent.g, wifiPanel.accent.b, 0.15)
                        Text {
                            anchors.centerIn: parent
                            text: "󰤨"
                            color: wifiPanel.accent
                            font.pixelSize: 20
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            text: "Wi-Fi"
                            color: wifiPanel.fg
                            font.pixelSize: 15; font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        Text {
                            text: wifiPanel.wifiEnabled
                                ? (wifiPanel.currentSSID !== "" ? "Connected" : "Enabled")
                                : "Disabled"
                            color: wifiPanel.muted
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        width: 48; height: 26; radius: 13
                        color: wifiPanel.wifiEnabled ? wifiPanel.accent : Qt.rgba(0.3, 0.3, 0.3, 0.5)
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            width: 22; height: 22; radius: 11; y: 2
                            x: wifiPanel.wifiEnabled ? 24 : 2
                            color: wifiPanel.bg
                            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: wifiToggleProc.running = true
                        }
                    }

                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: closeMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: wifiPanel.muted
                            font.pixelSize: 13
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.wifiVisible = false
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    radius: 14
                    color: Qt.rgba(wifiPanel.accent.r, wifiPanel.accent.g, wifiPanel.accent.b, 0.08)
                    border.color: Qt.rgba(wifiPanel.accent.r, wifiPanel.accent.g, wifiPanel.accent.b, 0.2)
                    border.width: 1
                    visible: wifiPanel.currentSSID !== ""

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        spacing: 12

                        Rectangle {
                            width: 32; height: 32; radius: 10
                            color: Qt.rgba(wifiPanel.accent.r, wifiPanel.accent.g, wifiPanel.accent.b, 0.15)
                            Text {
                                anchors.centerIn: parent
                                text: wifiPanel.wifiSignal > 66 ? "󰤨" : wifiPanel.wifiSignal > 33 ? "󰤥" : "󰤟"
                                color: wifiPanel.accent
                                font.pixelSize: 16
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: wifiPanel.currentSSID
                                color: wifiPanel.fg
                                font.pixelSize: 13; font.bold: true
                                font.family: "JetBrainsMono Nerd Font"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "Connected · " + wifiPanel.wifiSignal + "%"
                                color: wifiPanel.muted
                                font.pixelSize: 10
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 8
                            color: wifiDiscMa.containsMouse
                                ? Qt.rgba(wifiPanel.danger.r, wifiPanel.danger.g, wifiPanel.danger.b, 0.15)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: wifiDiscMa.containsMouse ? wifiPanel.danger : wifiPanel.muted
                                font.pixelSize: 12
                                font.family: "JetBrainsMono Nerd Font"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                id: wifiDiscMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: wifiDisconnectProc.running = true
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: Qt.rgba(0, 0, 0, 0.25)
                    border.color: Qt.rgba(wifiPanel.accent.r, wifiPanel.accent.g, wifiPanel.accent.b, 0.3)
                    border.width: 1
                    visible: wifiPanel.passwordSSID !== ""

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: "󰌾"
                            color: wifiPanel.accent
                            font.pixelSize: 14
                            font.family: "JetBrainsMono Nerd Font"
                        }

                        TextInput {
                            id: wifiPassInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: wifiPanel.fg
                            font.pixelSize: 12
                            font.family: "JetBrainsMono Nerd Font"
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            clip: true
                            Text {
                                text: "Password for " + wifiPanel.passwordSSID
                                color: wifiPanel.muted
                                visible: !parent.text
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                font: parent.font
                            }
                            Keys.onReturnPressed: {
                                if (text.length > 0) {
                                    wifiPanel.wifiConnecting = true
                                    wifiConnectProc.ssid     = wifiPanel.passwordSSID
                                    wifiConnectProc.password = text
                                    wifiConnectProc.running  = true
                                    text = ""
                                }
                            }
                        }

                        Rectangle {
                            width: 28; height: 28; radius: 8
                            color: wifiPanel.accent
                            Text {
                                anchors.centerIn: parent
                                text: "→"
                                color: wifiPanel.bg
                                font.pixelSize: 13; font.bold: true
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (wifiPassInput.text.length > 0) {
                                        wifiPanel.wifiConnecting = true
                                        wifiConnectProc.ssid     = wifiPanel.passwordSSID
                                        wifiConnectProc.password = wifiPassInput.text
                                        wifiConnectProc.running  = true
                                        wifiPassInput.text       = ""
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    visible: wifiPanel.wifiEnabled
                    Text {
                        text: "Available Networks"
                        color: wifiPanel.muted
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 28; height: 28; radius: 8
                        color: wifiRefreshMa.containsMouse ? Qt.rgba(wifiPanel.accent.r, wifiPanel.accent.g, wifiPanel.accent.b, 0.15) : "transparent"
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            anchors.centerIn: parent
                            text: wifiPanel.wifiScanning ? "󰑓" : "󰑐"
                            color: wifiRefreshMa.containsMouse ? wifiPanel.accent : wifiPanel.muted
                            font.pixelSize: 14
                            font.family: "JetBrainsMono Nerd Font"
                        }
                        MouseArea {
                            id: wifiRefreshMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (!wifiPanel.wifiScanning) wifiPanel.refreshWifi() }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Qt.rgba(0, 0, 0, 0.15)
                    radius: 14
                    clip: true

                    ListView {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4
                        boundsBehavior: Flickable.StopAtBounds
                        model: wifiPanel.wifiNetworks

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 48
                            radius: 12
                            color: wifiNetMa.containsMouse
                                ? Qt.rgba(wifiPanel.accent.r, wifiPanel.accent.g, wifiPanel.accent.b, 0.08)
                                : "transparent"
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12; anchors.rightMargin: 12
                                spacing: 12

                                Rectangle {
                                    width: 28; height: 28; radius: 8
                                    color: Qt.rgba(wifiPanel.accent.r, wifiPanel.accent.g, wifiPanel.accent.b, 0.1)
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.signal > 66 ? "󰤨" : modelData.signal > 33 ? "󰤥" : "󰤟"
                                        color: wifiPanel.accent
                                        font.pixelSize: 14
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        text: modelData.ssid
                                        color: wifiPanel.fg
                                        font.pixelSize: 12
                                        font.family: "JetBrainsMono Nerd Font"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: (modelData.security !== "" && modelData.security !== "--"
                                            ? "󰌾 " + modelData.security : "Open") + " · " + modelData.signal + "%"
                                        color: wifiPanel.muted
                                        font.pixelSize: 9
                                        font.family: "JetBrainsMono Nerd Font"
                                    }
                                }
                            }

                            MouseArea {
                                id: wifiNetMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.security !== "" && modelData.security !== "--") {
                                        wifiPanel.passwordSSID = modelData.ssid
                                        wifiPassInput.forceActiveFocus()
                                    } else {
                                        wifiPanel.wifiConnecting = true
                                        wifiConnectProc.ssid     = modelData.ssid
                                        wifiConnectProc.password = ""
                                        wifiConnectProc.running  = true
                                    }
                                }
                            }
                        }
                        ScrollBar.vertical: ScrollBar { active: true; width: 4 }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: wifiPanel.wifiNetworks.length === 0 && !wifiPanel.wifiScanning
                        text: wifiPanel.wifiEnabled ? "No networks found" : "Wi-Fi is off"
                        color: wifiPanel.muted
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: wifiPanel.wifiScanning
                        text: "Scanning..."
                        color: wifiPanel.muted
                        font.pixelSize: 12
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }
        }
    }
}
