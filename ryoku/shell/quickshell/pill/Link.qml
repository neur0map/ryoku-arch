pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import "Singletons"

/**
 * LINK surface = connectivity rows (auto-detected Network + Bluetooth) with
 * WLAN/BT drill-in subviews that cross-fade in place. owns the `subview` state
 * machine, exposes `desiredW` and `back()` for the pill's morph + Escape
 * plumbing. notifications live in their own INBOX surface.
 */
PillSurface {
    id: root

    mTop: 13
    mLeft: 16
    mRight: 16
    mBottom: 13

    property string subview: "main"

    readonly property real desiredW: (subview === "wifi" ? 272 : subview === "bt" ? 286 : 330) * s

    // row-soul focus registry. every hoverable row reports itself here; the
    // bead docks as a glowing seam at the row's left edge, hidden when nothing
    // is focused. only the main subview plays along.
    property Item focusRowItem: null

    // sticky: once a row's been focused the seam stays parked when the pointer
    // leaves, glides to the next focused row instead of waking from the pill
    // centre every hover. cleared on close.
    function reportRowHover(item, hovered) {
        if (hovered)
            focusRowItem = item;
    }

    readonly property bool rowFocused: focusRowItem !== null && subview === "main" && active

    readonly property point rowPoint: {
        void root.width;
        void root.height;
        void mainCol.implicitHeight;
        void root.focusRowItem;
        if (!focusRowItem)
            return Qt.point(4 * s, root.height / 2);
        return focusRowItem.mapToItem(root, 4 * s, focusRowItem.height / 2);
    }

    ameForm: rowFocused ? "rowseam" : "off"
    amePoint: rowPoint

    implicitHeight: subview === "wifi" ? wifiPage.implicitHeight
        : subview === "bt" ? btPage.implicitHeight
        : mainCol.implicitHeight

    readonly property var netDevices: (typeof Networking !== "undefined" && Networking && Networking.devices) ? Networking.devices.values : []
    readonly property var eth: netDevices.find(function(d) { return d && d.type === DeviceType.Wired && d.connected }) || null
    readonly property var wifiDev: netDevices.find(function(d) { return d && d.type === DeviceType.Wifi }) || null
    readonly property bool wired: eth !== null

    readonly property real ethSpeed: (eth && eth.linkSpeed) ? eth.linkSpeed : 0
    readonly property string ethSpeedText: ethSpeed > 0
        ? (ethSpeed >= 1000 ? (ethSpeed / 1000).toFixed(ethSpeed % 1000 === 0 ? 0 : 1) + " Gb/s" : ethSpeed + " Mb/s")
        : ""

    readonly property bool wifiOn: (typeof Networking !== "undefined" && Networking) ? Networking.wifiEnabled : false
    readonly property var wifiNets: (wifiDev && wifiDev.networks) ? wifiDev.networks.values : []
    readonly property var wifiActive: wifiNets.find(function(n) { return n && n.connected }) || null

    readonly property string netzSubText: wired
        ? ("Ethernet"
            + (ethSpeedText.length ? " · " + ethSpeedText : "")
            + (ethIp.length ? " · " + ethIp : ""))
        : (wifiActive ? (wifiActive.name || "") : (wifiOn ? "Nicht verbunden" : "Aus"))

    readonly property var btAdapter: (typeof Bluetooth !== "undefined" && Bluetooth) ? Bluetooth.defaultAdapter : null
    readonly property var btDevices: (typeof Bluetooth !== "undefined" && Bluetooth && Bluetooth.devices) ? Bluetooth.devices.values : []
    readonly property var btConnected: btDevices.filter(function(d) { return d && d.connected })
    readonly property bool btOn: btAdapter ? btAdapter.enabled === true : false
    readonly property var btPrimary: btConnected.length > 0 ? btConnected[0] : null
    readonly property int btBattery: batteryLevel(btPrimary)

    readonly property string btSubText: !btAdapter ? "Service off"
        : !btOn ? "Off"
        : (btPrimary
            ? ((btPrimary.deviceName || btPrimary.name || "Unknown")
                + (btConnected.length > 1 ? " +" + (btConnected.length - 1) : ""))
            : "Not connected")

    property string ethIp: ""

    // pops one nav level. drill-in -> main returns true; main returns false so
    // the caller closes the surface.
    function back() {
        if (subview !== "main") {
            subview = "main";
            return true;
        }
        return false;
    }

    function batteryLevel(d) {
        if (!d || d.battery === undefined || d.battery === null) return -1;
        var b = d.battery;
        if (b <= 0) return -1;
        if (b <= 1) b = b * 100;
        return Math.round(b);
    }

    onActiveChanged: {
        if (active) {
            subview = "main";
        } else {
            focusRowItem = null;
        }
    }

    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 -o addr show scope global up | awk '{for(i=1;i<=NF;i++) if($i==\"inet\"){print $(i+1); exit}}' | cut -d/ -f1"]
        running: false
        stdout: StdioCollector { onStreamFinished: root.ethIp = this.text.trim() }
    }

    Timer {
        interval: 15000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: ipProc.running = true
    }

    Item {
        id: mainView
        anchors.fill: parent
        opacity: root.subview === "main" ? 1 : 0
        visible: opacity > 0.01
        enabled: root.subview === "main" && root.active
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        Column {
            id: mainCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 4 * root.s

            Item {
                width: parent.width
                height: 24 * root.s

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * root.s

                    BrandMark {
                        anchors.verticalCenter: parent.verticalCenter
                        size: 16 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "LINK"
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.6 * root.s
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.hair
            }

            Rectangle {
                id: netzRow
                width: parent.width
                height: 44 * root.s
                radius: Theme.radius
                color: netzHover.hovered ? Theme.frameBg : "transparent"

                HoverHandler {
                    id: netzHover
                    onHoveredChanged: root.reportRowHover(netzRow, hovered)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.subview = "wifi"
                }

                GlyphIcon {
                    id: netzGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * root.s
                    height: 17 * root.s
                    name: root.wired ? "ethernet" : "wifi"
                    color: !root.wired && root.wifiOn ? Theme.vermLit : Theme.iconDim
                    stroke: 1.7
                }

                Column {
                    anchors.left: netzGlyph.right
                    anchors.leftMargin: 11 * root.s
                    anchors.right: netzRight.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.s

                    Text {
                        width: parent.width
                        text: "Network"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.netzSubText
                        color: !root.wired && root.wifiActive ? Theme.vermLit : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: !root.wired && root.wifiActive ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: netzRight
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9 * root.s

                    Filament {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.wired && root.wifiOn && root.wifiActive !== null
                        s: root.s
                        kind: "signal"
                        level: (root.wifiActive && root.wifiActive.signalStrength) || 0
                    }

                    LinkToggle {
                        s: root.s
                        visible: !root.wired
                        anchors.verticalCenter: parent.verticalCenter
                        on: root.wifiOn
                        onToggled: {
                            if (typeof Networking !== "undefined" && Networking)
                                Networking.wifiEnabled = !Networking.wifiEnabled;
                        }
                    }

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14 * root.s
                        height: 14 * root.s
                        name: "chevron-right"
                        color: Theme.iconDim
                        stroke: 1.8
                    }
                }
            }

            Rectangle {
                id: btRow
                width: parent.width
                height: 44 * root.s
                radius: Theme.radius
                color: btHover.hovered ? Theme.frameBg : "transparent"

                HoverHandler {
                    id: btHover
                    onHoveredChanged: root.reportRowHover(btRow, hovered)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.subview = "bt"
                }

                GlyphIcon {
                    id: btGlyph
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 17 * root.s
                    height: 17 * root.s
                    name: "bluetooth"
                    color: root.btConnected.length > 0 ? Theme.vermLit : Theme.iconDim
                    stroke: 1.7
                }

                Column {
                    anchors.left: btGlyph.right
                    anchors.leftMargin: 11 * root.s
                    anchors.right: btRight.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2 * root.s

                    Text {
                        width: parent.width
                        text: "Bluetooth"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12.5 * root.s
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.btSubText
                        color: root.btPrimary ? Theme.vermLit : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: root.btPrimary ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: btRight
                    anchors.right: parent.right
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 9 * root.s

                    Filament {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.btPrimary !== null && root.btBattery >= 0
                        s: root.s
                        kind: "battery"
                        level: Math.max(0, root.btBattery) / 100
                    }

                    LinkToggle {
                        s: root.s
                        visible: root.btAdapter !== null
                        anchors.verticalCenter: parent.verticalCenter
                        on: root.btOn
                        onToggled: btPage.setAdapterEnabled(!root.btOn)
                    }

                    GlyphIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14 * root.s
                        height: 14 * root.s
                        name: "chevron-right"
                        color: Theme.iconDim
                        stroke: 1.8
                    }
                }
            }
        }
    }

    LinkWifi {
        id: wifiPage
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        active: root.active && root.subview === "wifi"
        opacity: root.subview === "wifi" ? 1 : 0
        visible: opacity > 0.01
        enabled: root.subview === "wifi" && root.active
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
        onBack: root.subview = "main"
    }

    LinkBt {
        id: btPage
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        s: root.s
        active: root.active && root.subview === "bt"
        opacity: root.subview === "bt" ? 1 : 0
        visible: opacity > 0.01
        enabled: root.subview === "bt" && root.active
        Behavior on opacity {
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }
        onBack: root.subview = "main"
    }
}
