pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Bluetooth
import "Singletons"

/**
 * Bluetooth drill-in for the link surface: back chevron, scan with 25s
 * auto-stop, adapter toggle, live device list. Known devices use the
 * Quickshell connect/disconnect calls; unpaired devices run a bluetoothctl
 * pair-trust-connect flow with an inline ember while running and a transient
 * failure line.
 */
Item {
    id: root

    property real s: 1
    property bool active: false

    signal back()

    readonly property var adapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
    readonly property var devices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []

    /**
     * BlueZ hands the cache out in arbitrary order; sort connected first,
     * then paired, then named devices, nameless MACs last so a discovery scan
     * doesn't churn the useful rows around.
     */
    readonly property var devicesSorted: devices.slice().sort(function(a, b) {
        function rank(d) {
            if (!d) return 3;
            if (d.connected) return 0;
            if (d.paired) return 1;
            return (d.name && d.name.length) ? 2 : 3;
        }
        var r = rank(a) - rank(b);
        if (r !== 0) return r;
        return String((a && a.name) || "").localeCompare(String((b && b.name) || ""));
    })
    readonly property bool discovering: adapter ? adapter.discovering === true : false

    property string pairingAddress: ""
    property string failedAddress: ""

    implicitHeight: listFrame.y + listFrame.height

    function metaFor(d) {
        if (!d) return "";
        var parts = [];
        if (d.connected) parts.push("connected");
        else if (d.paired) parts.push("paired");
        if (d.state !== undefined && typeof BluetoothDeviceState !== "undefined") {
            var st = BluetoothDeviceState.toString(d.state);
            if (st && st.length > 0 && parts.indexOf(st.toLowerCase()) === -1) parts.push(st.toLowerCase());
        }
        return parts.join(" · ");
    }

    function batteryLevel(d) {
        if (!d || d.battery === undefined || d.battery === null) return -1;
        var b = d.battery;
        if (b <= 0) return -1;
        if (b <= 1) b = b * 100;
        return Math.round(b);
    }

    /**
     * Click dispatch for a device row: disconnect when connected, connect when
     * paired, otherwise run the bluetoothctl pair-trust-connect flow.
     */
    function activateDevice(d) {
        if (!d)
            return;
        if (d.connected) {
            if (typeof d.disconnect === "function")
                d.disconnect();
            return;
        }
        if (d.paired) {
            if (typeof d.connect === "function")
                d.connect();
            return;
        }
        pairDevice(d);
    }

    function pairDevice(d) {
        if (!d || !d.address || pairProc.running)
            return;
        pairingAddress = d.address;
        failedAddress = "";
        pairProc.command = ["sh", "-c",
            'timeout 30 bluetoothctl pair "$1" && bluetoothctl trust "$1" && timeout 30 bluetoothctl connect "$1"',
            "sh", d.address];
        pairProc.running = true;
    }

    onActiveChanged: {
        if (!active) {
            scanTimer.stop();
            if (adapter && adapter.discovering)
                adapter.discovering = false;
        }
    }

    Timer {
        id: scanTimer
        interval: 25000
        repeat: false
        onTriggered: if (root.adapter) root.adapter.discovering = false
    }

    Timer {
        id: failTimer
        interval: 4000
        repeat: false
        onTriggered: root.failedAddress = ""
    }

    Process {
        id: pairProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(exitCode) {
            var addr = root.pairingAddress;
            root.pairingAddress = "";
            if (exitCode !== 0) {
                root.failedAddress = addr;
                failTimer.restart();
            }
        }
    }

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 17 * root.s
                height: 17 * root.s

                GlyphIcon {
                    anchors.fill: parent
                    name: "chevron-left"
                    color: backArea.containsMouse ? Theme.cream : Theme.iconDim
                    stroke: 1.8
                }

                MouseArea {
                    id: backArea
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.back()
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "BLUETOOTH"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.adapter ? root.adapter.enabled === true : false
                text: root.discovering ? "Scanning…" : "Scan"
                color: root.discovering ? Theme.vermLit : Theme.dim
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.DemiBold

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6 * root.s
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.adapter)
                            return;
                        root.adapter.discovering = !root.adapter.discovering;
                        if (root.adapter.discovering)
                            scanTimer.restart();
                        else
                            scanTimer.stop();
                    }
                }
            }

            LinkToggle {
                s: root.s
                anchors.verticalCenter: parent.verticalCenter
                on: root.adapter ? root.adapter.enabled === true : false
                onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    Item {
        id: listFrame
        anchors.top: divider.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.devices.length > 0 ? Math.min(devCol.implicitHeight, 200 * root.s) : 24 * root.s

        Text {
            visible: root.devices.length === 0
            anchors.left: parent.left
            anchors.leftMargin: 6 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: root.discovering ? "Scanning…" : "No devices"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.Medium
        }

        Flickable {
            id: devFlick
            visible: root.devices.length > 0
            anchors.fill: parent
            contentHeight: devCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: devCol
                width: devFlick.width
                spacing: 2 * root.s

                Repeater {
                    model: root.devicesSorted

                    Column {
                        id: devItem
                        required property var modelData
                        readonly property bool isConnected: modelData ? modelData.connected === true : false
                        readonly property bool isPaired: modelData ? modelData.paired === true : false
                        readonly property string addr: (modelData && modelData.address) ? modelData.address : ""
                        readonly property bool pairing: addr.length > 0 && root.pairingAddress === addr
                        readonly property bool failed: addr.length > 0 && root.failedAddress === addr
                        readonly property int battery: root.batteryLevel(modelData)
                        width: devCol.width
                        spacing: 2 * root.s

                        Rectangle {
                            width: parent.width
                            height: 38 * root.s
                            radius: 9 * root.s
                            color: rowHover.hovered ? Theme.frameBg : "transparent"

                            HoverHandler { id: rowHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activateDevice(devItem.modelData)
                            }

                            Rectangle {
                                id: devTile
                                anchors.left: parent.left
                                anchors.leftMargin: 6 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26 * root.s
                                height: 26 * root.s
                                radius: 8 * root.s
                                color: Theme.tileBg
                                border.width: 1
                                border.color: Theme.border

                                GlyphIcon {
                                    anchors.centerIn: parent
                                    width: 15 * root.s
                                    height: 15 * root.s
                                    name: "bluetooth"
                                    color: devItem.isConnected ? Theme.vermLit : Theme.iconDim
                                    stroke: 1.7
                                }
                            }

                            Column {
                                anchors.left: devTile.right
                                anchors.leftMargin: 10 * root.s
                                anchors.right: devRight.left
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1 * root.s

                                Text {
                                    width: parent.width
                                    text: devItem.modelData ? (devItem.modelData.deviceName || devItem.modelData.name || "Unknown") : "Unknown"
                                    color: devItem.isConnected ? Theme.cream : Theme.subtle
                                    font.family: Theme.font
                                    font.pixelSize: 11.5 * root.s
                                    font.weight: devItem.isConnected ? Font.DemiBold : Font.Medium
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    visible: text.length > 0
                                    text: root.metaFor(devItem.modelData)
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 9.5 * root.s
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                id: devRight
                                anchors.right: parent.right
                                anchors.rightMargin: 8 * root.s
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8 * root.s

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: devItem.pairing
                                    width: 4 * root.s
                                    height: 4 * root.s
                                    radius: width / 2
                                    color: Theme.flameGlow

                                    SequentialAnimation on opacity {
                                        running: devItem.pairing
                                        loops: Animation.Infinite
                                        NumberAnimation { from: 0.35; to: 1; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1; to: 0.35; duration: Motion.pulse; easing.type: Easing.InOutSine }
                                    }
                                }

                                Filament {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: devItem.isConnected && devItem.battery >= 0
                                    s: root.s
                                    kind: "battery"
                                    level: Math.max(0, devItem.battery) / 100
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !devItem.isPaired && !devItem.pairing
                                    radius: 999
                                    color: Theme.tileBg
                                    border.width: 1
                                    border.color: Theme.border
                                    height: 18 * root.s
                                    width: pairText.implicitWidth + 16 * root.s

                                    Text {
                                        id: pairText
                                        anchors.centerIn: parent
                                        text: "Pair"
                                        color: Theme.dim
                                        font.family: Theme.font
                                        font.pixelSize: 9.5 * root.s
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }

                        Text {
                            visible: devItem.failed
                            text: "Pairing failed"
                            color: Theme.vermLit
                            font.family: Theme.font
                            font.pixelSize: 9.5 * root.s
                            leftPadding: 42 * root.s
                        }
                    }
                }
            }
        }

        WheelScroller {
            anchors.fill: parent
            s: root.s
            flick: devFlick
        }
    }
}
