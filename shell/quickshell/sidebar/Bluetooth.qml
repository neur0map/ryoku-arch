import QtQuick
import QtQuick.Effects
import Quickshell.Bluetooth
import "Singletons"

Card {
    id: root

    readonly property var adapter: typeof Bluetooth !== "undefined" && Bluetooth ? Bluetooth.defaultAdapter : null
    readonly property var devices: typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property int connectedCount: {
        var n = 0;
        for (var i = 0; i < devices.length; i++) if (devices[i] && devices[i].connected) n++;
        return n;
    }

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

    function batteryFor(d) {
        if (!d || d.battery === undefined || d.battery === null) return "";
        var b = d.battery;
        if (b <= 0) return "";
        if (b <= 1) b = b * 100;
        return Math.round(b) + "%";
    }

    Timer {
        id: scanTimer
        interval: 25000
        repeat: false
        onTriggered: if (root.adapter) root.adapter.discovering = false
    }

    Item {
        width: parent.width
        implicitHeight: 21 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10 * root.s

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 18 * root.s; height: 18 * root.s
                Image {
                    id: btHead
                    anchors.fill: parent
                    source: Qt.resolvedUrl("assets/icons/bluetooth.svg")
                    sourceSize.width: 64; sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true; visible: false
                }
                MultiEffect {
                    anchors.fill: btHead
                    source: btHead
                    colorization: 1.0
                    colorizationColor: Theme.iconDim
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Bluetooth"
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * root.s
                font.weight: Font.DemiBold
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.connectedCount + " connected"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            id: scanBtn
            visible: root.adapter && root.adapter.enabled
            anchors.right: toggle.left
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            radius: 8 * root.s
            property bool scanning: root.adapter ? root.adapter.discovering : false
            color: scanning ? Theme.accent16 : Theme.tileBg
            border.width: 1
            border.color: scanning ? Theme.accent45 : Theme.border
            implicitHeight: 21 * root.s
            width: scanTxt.implicitWidth + 18 * root.s
            height: implicitHeight
            Text {
                id: scanTxt
                anchors.centerIn: parent
                text: scanBtn.scanning ? "Scanning…" : "Scan"
                color: scanBtn.scanning ? Theme.vermLit : Theme.dim
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
            }
            MouseArea {
                anchors.fill: parent
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
        Toggle {
            id: toggle
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            s: root.s
            on: root.adapter ? root.adapter.enabled : false
            onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
        }
    }

    Item {
        id: listFrame
        width: parent.width
        implicitHeight: root.devices.length > 0 ? Math.min(list.contentHeight, 170 * root.s) : 22 * root.s

        Text {
            visible: root.devices.length === 0
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: (root.adapter && root.adapter.discovering) ? "Searching…" : "No devices"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.Medium
        }

        Flickable {
            id: list
            visible: root.devices.length > 0
            anchors.fill: parent
            contentHeight: rows.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            Column {
                id: rows
                width: list.width
                spacing: 6 * root.s

                Repeater {
                    model: root.devices
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool isConnected: modelData ? modelData.connected : false
                        readonly property string battery: root.batteryFor(modelData)
                        width: rows.width
                        implicitHeight: 46 * root.s
                        radius: 11 * root.s
                        color: isConnected ? Theme.accent16 : "transparent"
                        border.width: 1
                        border.color: isConnected ? Theme.accent45 : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 9 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 11 * root.s

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30 * root.s; height: 30 * root.s; radius: 9 * root.s
                                color: isConnected ? Theme.accent16 : Theme.tileBg
                                border.width: 1
                                border.color: isConnected ? Theme.accent45 : Theme.border
                                Image {
                                    id: dico
                                    anchors.centerIn: parent
                                    width: 16 * root.s; height: 16 * root.s
                                    source: Qt.resolvedUrl("assets/icons/bluetooth.svg")
                                    sourceSize.width: 64; sourceSize.height: 64
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true; mipmap: true; visible: false
                                }
                                MultiEffect {
                                    anchors.fill: dico
                                    source: dico
                                    colorization: 1.0
                                    colorizationColor: isConnected ? Theme.vermLit : Theme.dim
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1 * root.s
                                Text {
                                    text: modelData ? (modelData.deviceName || modelData.name || "Unknown") : "Unknown"
                                    color: isConnected ? Theme.cream : Theme.subtle
                                    font.family: Theme.font
                                    font.pixelSize: 12.5 * root.s
                                    font.weight: isConnected ? Font.DemiBold : Font.Medium
                                }
                                Text {
                                    text: root.metaFor(modelData)
                                    color: Theme.faint
                                    font.family: Theme.font
                                    font.pixelSize: 10 * root.s
                                    font.weight: Font.Medium
                                }
                            }
                        }

                        Text {
                            visible: isConnected && battery.length > 0
                            anchors.right: parent.right
                            anchors.rightMargin: 11 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: battery
                            color: Theme.vermLit
                            font.family: Theme.font
                            font.pixelSize: 10.5 * root.s
                            font.weight: Font.DemiBold
                        }

                        Rectangle {
                            visible: !isConnected
                            anchors.right: parent.right
                            anchors.rightMargin: 9 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 8 * root.s
                            color: Theme.tileBg
                            border.width: 1
                            border.color: Theme.border
                            implicitHeight: 22 * root.s
                            width: connText.implicitWidth + 18 * root.s
                            height: implicitHeight
                            Text {
                                id: connText
                                anchors.centerIn: parent
                                text: "Connect"
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: 10 * root.s
                                font.weight: Font.DemiBold
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!modelData) return;
                                if (modelData.connected) modelData.disconnect();
                                else modelData.connect();
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: list.visible && list.contentHeight > listFrame.height
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 18 * root.s
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Theme.panelBot }
            }
        }
    }
}
