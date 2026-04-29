import QtQuick
import Quickshell.Io
import "../../components"
import "../../"

Item {
    id: root

    implicitWidth:  row.implicitWidth + 6
    implicitHeight: row.implicitHeight

    property int    _signal:       0
    property bool   _ethernet:     false
    property string _connectivity: "unknown"

    readonly property bool _limited: {
        var c = _connectivity
        return c === "limited" || c === "portal" || c === "none"
    }

    readonly property string _netIcon: {
        if (_ethernet) return _limited ? "󰅢" : ""
        if (_signal <= 0) return "󰤭"
        if (_limited) return ""

        if (_signal > 75) return "󰤨"
        if (_signal > 50) return "󰤥"
        if (_signal > 25) return "󰤢"
        return "󰤟"
    }

    readonly property color _netColor: {
        if (!_ethernet && _signal <= 0) return Qt.rgba(1,1,1,0.28)
        if (_connectivity === "none")   return "#f87171"
        if (_limited)                   return "#f5c47a"
        return hov.hovered ? Theme.active : Theme.text
    }

    // VPN blink
    property real _vpnOpacity: 1.0
    SequentialAnimation on _vpnOpacity {
        running: ShellState.vpnConnecting; loops: Animation.Infinite
        NumberAnimation { to: 0.20; duration: 500; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0;  duration: 500; easing.type: Easing.InOutSine }
    }
    Connections {
        target: ShellState
        function onVpnConnectingChanged() {
            if (!ShellState.vpnConnecting) root._vpnOpacity = 1.0
        }
    }

    // Polling
    Process {
        id: wifiPoll
        command: ["bash", "-c", "nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null | grep '^yes:' | head -1 | cut -d: -f2"]
        running: false
        stdout: SplitParser { onRead: function(l) { var s = parseInt(l.trim()); root._signal = isNaN(s) ? 0 : s } }
    }
    Process {
        id: ethPoll
        command: ["bash", "-c", "nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -c 'ethernet:connected'"]
        running: false
        stdout: SplitParser { onRead: function(l) { root._ethernet = parseInt(l.trim()) > 0 } }
    }
    Process {
        id: connPoll
        command: ["bash", "-c", "nmcli -t -f CONNECTIVITY general 2>/dev/null | head -1"]
        running: false
        stdout: SplitParser {
            onRead: function(l) { var v = l.trim().toLowerCase(); if (v !== "") root._connectivity = v }
        }
    }
    Timer {
        interval: 5000; running: true; repeat: true
        onTriggered: {
            wifiPoll.running = false; wifiPoll.running = true
            ethPoll.running  = false; ethPoll.running  = true
            connPoll.running = false; connPoll.running = true
        }
    }
    Component.onCompleted: { wifiPoll.running = true; ethPoll.running = true; connPoll.running = true }

    HoverHandler { id: hov; onHoveredChanged: Popups.networkTriggerHovered = hovered }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4

        // WiFi/ethernet icon — opens to wifi tab
        Text {
            id: netIcon
            text:           root._netIcon
            color:          root._netColor
            font.pixelSize: 16
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Popups.closeAll()
                    Popups.networkPage = "wifi"
                    Popups.networkOpen = true
                }
            }
        }

        // VPN shield — opens to vpn tab
        Text {
            visible:        ShellState.vpnActive || ShellState.vpnConnecting
            text:           ShellState.vpnConnecting ? "󱦚" : "󰦝"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
            opacity:        root._vpnOpacity
            color: ShellState.vpnActive ? Theme.active : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.70)
            Behavior on color   { ColorAnimation  { duration: 200 } }
            Behavior on opacity { NumberAnimation { duration: 80  } }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Popups.closeAll()
                    Popups.networkPage = "vpn"
                    Popups.networkOpen = true
                }
            }
        }

        // Bluetooth — opens to bluetooth tab
        Text {
            visible:        ShellState.btPowered
            text:           ShellState.btConnected ? "󰂱" : "󰂯"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
            color: ShellState.btConnected ? (hov.hovered ? Theme.active : Theme.text) : Qt.rgba(1,1,1,0.32)
            Behavior on color { ColorAnimation { duration: 200 } }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Popups.closeAll()
                    Popups.networkPage = "bluetooth"
                    Popups.networkOpen = true
                }
            }
        }

        // Hotspot — opens to hotspot tab
        Text {
            visible:        ShellState.hotspot
            text:           "󰀂"
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
            color:          Theme.active
            Behavior on color { ColorAnimation { duration: 200 } }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Popups.closeAll()
                    Popups.networkPage = "hotspot"
                    Popups.networkOpen = true
                }
            }
        }
    }
}
