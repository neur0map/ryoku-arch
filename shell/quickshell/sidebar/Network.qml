import QtQuick
import QtQuick.Effects
import Quickshell.Networking
import Quickshell.Io
import "Singletons"

Card {
    id: root
    eyebrow: "Network"

    readonly property var devices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var eth: devices.find(function(d) { return d && d.type === DeviceType.Wired && d.connected }) || null
    readonly property var wifiDev: devices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wired: eth !== null

    readonly property real ethSpeed: (eth && eth.linkSpeed) ? eth.linkSpeed : 0
    readonly property string ethSpeedText: ethSpeed > 0
        ? (ethSpeed >= 1000 ? (ethSpeed / 1000).toFixed(ethSpeed % 1000 === 0 ? 0 : 1) + " Gb/s" : ethSpeed + " Mb/s")
        : ""

    property string ethIp: ""
    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 -o addr show scope global up | awk '{for(i=1;i<=NF;i++) if($i==\"inet\"){print $(i+1); exit}}' | cut -d/ -f1"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.ethIp = this.text.trim() }
    }
    Component.onCompleted: ipProc.running = true
    onWiredChanged: ipProc.running = true

    Timer {
        interval: 15000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: ipProc.running = true
    }

    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var wifiNets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var wifiNetsSorted: wifiNets.slice().sort(function(a, b) {
        return ((b ? b.signalStrength : 0) || 0) - ((a ? a.signalStrength : 0) || 0)
    })
    readonly property var wifiActive: wifiNets.find(function(n) { return n && n.connected }) || null
    readonly property string wifiSsid: wifiActive ? (wifiActive.name || "") : (wifiOn ? "Not connected" : "Off")

    Item {
        id: wiredView
        visible: root.wired || !root.wifiDev
        width: parent.width
        implicitHeight: wiredTop.implicitHeight + wiredBottom.implicitHeight + 11 * root.s

        Item {
            id: wiredTop
            width: parent.width
            implicitHeight: 36 * root.s

            Rectangle {
                id: iconbox
                width: 36 * root.s; height: 36 * root.s; radius: 11 * root.s
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.tileBg
                border.width: 1
                border.color: Theme.border
                Image {
                    id: ethIcon
                    anchors.centerIn: parent
                    width: 19 * root.s; height: 19 * root.s
                    source: Qt.resolvedUrl("assets/icons/ethernet.svg")
                    sourceSize.width: 64; sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true; visible: false
                }
                MultiEffect {
                    anchors.fill: ethIcon
                    source: ethIcon
                    colorization: 1.0
                    colorizationColor: Theme.vermLit
                }
            }

            Column {
                anchors.left: iconbox.right
                anchors.leftMargin: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * root.s
                Text {
                    text: "Ethernet"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.DemiBold
                }
                Row {
                    spacing: 0
                    Text {
                        text: root.wired ? "Connected" : "Disconnected"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Medium
                    }
                    Text {
                        visible: root.ethSpeedText.length > 0
                        text: " · "
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Medium
                    }
                    Text {
                        visible: root.ethSpeedText.length > 0
                        text: root.ethSpeedText
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.DemiBold
                    }
                }
            }

            Rectangle {
                id: ip
                visible: root.ethIp.length > 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                radius: 8 * root.s
                color: Theme.tileBg
                border.width: 1
                border.color: Theme.border
                implicitHeight: 22 * root.s
                width: ipText.implicitWidth + 18 * root.s
                height: implicitHeight
                Text {
                    id: ipText
                    anchors.centerIn: parent
                    text: root.ethIp
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                }
            }
        }

        Item {
            id: wiredBottom
            anchors.top: wiredTop.bottom
            anchors.topMargin: 11 * root.s
            width: parent.width
            implicitHeight: 24 * root.s

            Rectangle {
                id: autochip
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                radius: 999
                color: Theme.tileBg
                border.width: 1
                border.color: Theme.border
                implicitHeight: 18 * root.s
                width: autoRow.implicitWidth + 14 * root.s
                height: implicitHeight
                Row {
                    id: autoRow
                    anchors.centerIn: parent
                    spacing: 4 * root.s
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5 * root.s; height: 5 * root.s; radius: width / 2
                        color: (root.eth && root.eth.autoconnect !== false) ? Theme.vermLit : Theme.dim
                    }
                    Text {
                        text: "Auto"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 8.5 * root.s
                        font.weight: Font.Bold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 0.85 * root.s
                    }
                }
            }

            Rectangle {
                id: disconnect
                visible: root.wired && root.eth && typeof root.eth.disconnect === "function"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                radius: 9 * root.s
                color: Theme.tileBg
                border.width: 1
                border.color: Theme.border
                implicitHeight: 24 * root.s
                width: discRow.implicitWidth + 22 * root.s
                height: implicitHeight
                Row {
                    id: discRow
                    anchors.centerIn: parent
                    spacing: 6 * root.s
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 13 * root.s; height: 13 * root.s
                        Image {
                            id: linkIcon
                            anchors.fill: parent
                            source: Qt.resolvedUrl("assets/icons/link.svg")
                            sourceSize.width: 64; sourceSize.height: 64
                            fillMode: Image.PreserveAspectFit
                            smooth: true; mipmap: true; visible: false
                        }
                        MultiEffect {
                            anchors.fill: linkIcon
                            source: linkIcon
                            colorization: 1.0
                            colorizationColor: Theme.vermLit
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Disconnect"
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10.5 * root.s
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.eth && typeof root.eth.disconnect === "function") root.eth.disconnect() }
                }
            }
        }
    }

    Item {
        id: wifiView
        visible: !root.wired && root.wifiDev
        width: parent.width
        implicitHeight: wifiTop.implicitHeight + wifiList.height + 11 * root.s

        Item {
            id: wifiTop
            width: parent.width
            implicitHeight: 36 * root.s

            Rectangle {
                id: wifiIconbox
                width: 36 * root.s; height: 36 * root.s; radius: 11 * root.s
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.tileBg
                border.width: 1
                border.color: Theme.border
                Image {
                    id: wifiIcon
                    anchors.centerIn: parent
                    width: 19 * root.s; height: 19 * root.s
                    source: Qt.resolvedUrl("assets/icons/wifi.svg")
                    sourceSize.width: 64; sourceSize.height: 64
                    fillMode: Image.PreserveAspectFit
                    smooth: true; mipmap: true; visible: false
                }
                MultiEffect {
                    anchors.fill: wifiIcon
                    source: wifiIcon
                    colorization: 1.0
                    colorizationColor: root.wifiOn ? Theme.vermLit : Theme.dim
                }
            }

            Column {
                anchors.left: wifiIconbox.right
                anchors.leftMargin: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * root.s
                Text {
                    text: "WLAN"
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.wifiSsid
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.Medium
                }
            }

            Toggle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                s: root.s
                on: root.wifiOn
                onToggled: { if (typeof Networking !== "undefined" && Networking) Networking.wifiEnabled = !Networking.wifiEnabled }
            }
        }

        Flickable {
            id: wifiList
            anchors.top: wifiTop.bottom
            anchors.topMargin: 11 * root.s
            width: parent.width
            visible: root.wifiOn
            height: root.wifiOn ? Math.min(netCol.implicitHeight, 170 * root.s) : 0
            contentHeight: netCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: netCol
                width: parent.width
                spacing: 4 * root.s
                Repeater {
                    model: root.wifiNetsSorted
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool active: modelData && modelData.connected
                        width: netCol.width
                        height: 30 * root.s
                        radius: 8 * root.s
                        color: active ? Theme.accent16 : Theme.tileBg
                        border.width: 1
                        border.color: active ? Theme.accent45 : Theme.border
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 11 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: (modelData && modelData.name) ? modelData.name : "Hidden"
                            color: active ? Theme.vermLit : Theme.cream
                            elide: Text.ElideRight
                            width: parent.width - 70 * root.s
                            font.family: Theme.font
                            font.pixelSize: 11 * root.s
                            font.weight: active ? Font.DemiBold : Font.Medium
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 11 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: Math.round(((modelData && modelData.signalStrength) || 0)) + "%"
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 10 * root.s
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!modelData) return
                                if (active) { if (typeof modelData.disconnect === "function") modelData.disconnect() }
                                else { if (typeof modelData.connect === "function") modelData.connect() }
                            }
                        }
                    }
                }
            }
        }
    }
}
