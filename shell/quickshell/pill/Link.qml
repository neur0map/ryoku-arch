pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import "Singletons"

/**
 * 繋 LINK surface: connectivity rows (auto-detected Netz, Bluetooth) over the
 * 報 INBOX notification center, with WLAN and Bluetooth drill-in subviews that
 * cross-fade in place. Owns the `subview` state machine and exposes
 * `desiredW`, `emberX`/`emberY` (flame dock point beside the 報 marker) and
 * `back()` for the pill's morph and Escape plumbing. Opening marks all
 * notifications seen after a short beat so unread embers register first.
 */
PillSurface {
    id: root

    mTop: 13
    mLeft: 16
    mRight: 16
    mBottom: 13

    property string subview: "main"

    readonly property real desiredW: (subview === "wifi" ? 272 : subview === "bt" ? 286 : 330) * s

    readonly property point emberPoint: {
        void root.width;
        void root.height;
        void mainCol.implicitHeight;
        void root.subview;
        return emberAnchor.mapToItem(root, emberAnchor.width / 2, emberAnchor.height / 2);
    }
    readonly property real emberX: emberPoint.x
    readonly property real emberY: emberPoint.y

    /**
     * Row-soul focus registry. Each hoverable row reports itself here; the bead
     * docks as a glowing seam at the left edge of the focused row and hides
     * when nothing is focused. Only the main subview participates.
     */
    property Item focusRowItem: null

    /**
     * Sticky: once a row has been focused the seam stays parked on it when the
     * pointer leaves, gliding to the next focused row instead of re-waking
     * from the pill centre on every hover. Cleared only when the surface
     * closes.
     */
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

    readonly property string btSubText: !btOn ? "Aus"
        : (btPrimary
            ? ((btPrimary.deviceName || btPrimary.name || "Unknown")
                + (btConnected.length > 1 ? " +" + (btConnected.length - 1) : ""))
            : "Not connected")

    property string ethIp: ""

    /**
     * Pops one navigation level: drill-in back to main returns true, main
     * returns false so the caller closes the surface instead.
     */
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
            seenTimer.restart();
        } else {
            seenTimer.stop();
            focusRowItem = null;
        }
    }

    Timer {
        id: seenTimer
        interval: 600
        repeat: false
        onTriggered: Notifs.markAllSeen()
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

    /**
     * Ember mark: a small flame-glow dot over a soft halo, the unread marker
     * shared by the header badge and unread notification titles.
     */
    component Ember: Item {
        id: ember
        property real size: 4 * root.s

        width: size * 2.2
        height: size * 2.2

        Rectangle {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            radius: width / 2
            color: Theme.flameGlow
            opacity: 0.22
        }

        Rectangle {
            anchors.centerIn: parent
            width: ember.size
            height: ember.size
            radius: width / 2
            color: Theme.flameGlow
        }
    }

    /**
     * Single inbox entry: icon tile or diamond, body text, ×N coalesce badge,
     * age label that cross-fades into a dismiss glyph on hover. Critical
     * entries gain a vermilion left hairline and cream emphasis.
     */
    component NotifRow: Rectangle {
        id: nrow

        required property var entry
        property bool critical: false
        readonly property var n: entry.n

        width: parent ? parent.width : 0
        height: 26 * root.s
        radius: 7 * root.s
        color: nrowHover.hovered ? Theme.frameBg : "transparent"

        HoverHandler {
            id: nrowHover
            onHoveredChanged: root.reportRowHover(nrow, hovered)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Notifs.activateEntry(nrow.entry);
                root.requestClose();
            }
        }

        Rectangle {
            visible: nrow.critical
            anchors.left: parent.left
            anchors.leftMargin: 1 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 2 * root.s
            height: parent.height - 10 * root.s
            radius: 999
            color: Theme.verm
        }

        Rectangle {
            id: nrowTile
            anchors.left: parent.left
            anchors.leftMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s
            radius: 5 * root.s
            color: Theme.tileBg
            border.width: 1
            border.color: Theme.border

            Image {
                id: nrowImg
                anchors.fill: parent
                anchors.margins: nrow.n.image ? 0 : 2 * root.s
                source: Notifs.iconFor(nrow.n)
                sourceSize.width: 64
                sourceSize.height: 64
                fillMode: Image.PreserveAspectCrop
                smooth: true
                visible: source.toString().length > 0
            }

            Rectangle {
                anchors.centerIn: parent
                visible: !nrowImg.visible
                width: 5 * root.s
                height: 5 * root.s
                radius: 1.5 * root.s
                rotation: 45
                color: nrow.critical ? Theme.vermLit : Theme.verm
            }
        }

        Text {
            anchors.left: nrowTile.right
            anchors.leftMargin: 8 * root.s
            anchors.right: nrowRight.left
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: nrow.n.body.length > 0 ? nrow.n.body : nrow.n.summary
            color: nrow.critical ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10.5 * root.s
            font.weight: nrow.critical ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
            textFormat: Text.PlainText
        }

        Row {
            id: nrowRight
            anchors.right: parent.right
            anchors.rightMargin: 8 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.s

            Text {
                visible: nrow.entry.count > 1
                anchors.verticalCenter: parent.verticalCenter
                text: "×" + nrow.entry.count
                color: nrow.critical ? Theme.vermLit : Theme.vermDim
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                font.weight: Font.Bold
            }

            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(nrowAge.implicitWidth, nrowX.implicitWidth)
                height: Math.max(nrowAge.implicitHeight, nrowX.implicitHeight)

                Text {
                    id: nrowAge
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: nrowHover.hovered ? 0 : 1
                    text: Notifs.ageLabel(nrow.n)
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                }

                Text {
                    id: nrowX
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: nrowHover.hovered ? 1 : 0
                    text: "✕"
                    color: nrowXArea.containsMouse ? Theme.cream : Theme.dim
                    font.pixelSize: 10 * root.s
                    Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                    MouseArea {
                        id: nrowXArea
                        anchors.fill: parent
                        anchors.margins: -6 * root.s
                        enabled: nrowHover.hovered
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dismissEntry(nrow.entry)
                    }
                }
            }
        }
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

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "繋"
                        color: Theme.cream
                        font.family: Theme.fontJp
                        font.weight: Font.Medium
                        font.pixelSize: 16 * root.s
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

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * root.s
                    visible: Notifs.unread > 0

                    Ember {
                        id: headerEmber
                        anchors.verticalCenter: parent.verticalCenter
                        size: 6 * root.s

                        SequentialAnimation on opacity {
                            running: headerEmber.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.55; to: 1; duration: 1200; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1; to: 0.55; duration: 1200; easing.type: Easing.InOutSine }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Notifs.unread + " NEU"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4 * root.s
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
                radius: 10 * root.s
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
                radius: 10 * root.s
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
                        anchors.verticalCenter: parent.verticalCenter
                        on: root.btOn
                        onToggled: if (root.btAdapter) root.btAdapter.enabled = !root.btAdapter.enabled
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

            Item {
                width: parent.width
                height: 20 * root.s

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * root.s

                    Item {
                        id: emberAnchor
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10 * root.s
                        height: 10 * root.s
                    }

                    Text {
                        id: inboxKanji
                        anchors.verticalCenter: parent.verticalCenter
                        text: "報"
                        color: Theme.dim
                        font.family: Theme.fontJp
                        font.weight: Font.Medium
                        font.pixelSize: 11.5 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "INBOX"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1.8 * root.s
                    }
                }

                Row {
                    id: clearRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.count > 0
                    spacing: 4 * root.s

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "払"
                        color: clearArea.containsMouse ? Theme.vermLit : Theme.vermDim
                        font.family: Theme.fontJp
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CLEAR"
                        color: clearArea.containsMouse ? Theme.vermLit : Theme.vermDim
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4 * root.s
                    }
                }

                MouseArea {
                    id: clearArea
                    anchors.fill: clearRow
                    anchors.margins: -5 * root.s
                    visible: Notifs.count > 0
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifs.clearAll()
                }
            }

            Item {
                visible: Notifs.count > 0
                width: parent.width
                height: notifFlick.height

                Flickable {
                    id: notifFlick
                    width: parent.width
                    height: Math.min(notifCol.implicitHeight, 320 * root.s)
                    contentHeight: notifCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    onContentHeightChanged: returnToBounds()

                    Column {
                        id: notifCol
                        width: notifFlick.width
                        spacing: 6 * root.s

                        Repeater {
                            model: Notifs.groups

                            Column {
                                id: group
                                required property var modelData
                                readonly property bool expanded: Notifs.expandedApps[modelData.app] === true
                                width: notifCol.width
                                spacing: 2 * root.s

                                Repeater {
                                    model: group.modelData.criticals

                                    NotifRow {
                                        required property var modelData
                                        entry: modelData
                                        critical: true
                                    }
                                }

                                Rectangle {
                                    id: groupHead
                                    width: parent.width
                                    height: 32 * root.s
                                    radius: 8 * root.s
                                    color: headHover.hovered ? Theme.frameBg : "transparent"

                                    HoverHandler {
                                        id: headHover
                                        onHoveredChanged: root.reportRowHover(groupHead, hovered)
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Notifs.toggleExpanded(group.modelData.app)
                                    }

                                    Rectangle {
                                        id: headTile
                                        anchors.left: parent.left
                                        anchors.leftMargin: 6 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 20 * root.s
                                        height: 20 * root.s
                                        radius: 6 * root.s
                                        color: Theme.tileBg
                                        border.width: 1
                                        border.color: Theme.border

                                        Image {
                                            id: headImg
                                            anchors.fill: parent
                                            anchors.margins: group.modelData.newest.image ? 0 : 3 * root.s
                                            source: Notifs.iconFor(group.modelData.newest)
                                            sourceSize.width: 64
                                            sourceSize.height: 64
                                            fillMode: Image.PreserveAspectCrop
                                            smooth: true
                                            visible: source.toString().length > 0
                                        }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            visible: !headImg.visible
                                            width: 6 * root.s
                                            height: 6 * root.s
                                            radius: 2 * root.s
                                            rotation: 45
                                            color: Theme.verm
                                        }
                                    }

                                    Text {
                                        id: headName
                                        anchors.left: headTile.right
                                        anchors.leftMargin: 8 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(implicitWidth, 110 * root.s)
                                        text: group.modelData.app
                                        color: Theme.subtle
                                        font.family: Theme.font
                                        font.pixelSize: 9 * root.s
                                        font.weight: Font.Bold
                                        font.capitalization: Font.AllUppercase
                                        font.letterSpacing: 1.2 * root.s
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        id: headCount
                                        anchors.left: headName.right
                                        anchors.leftMargin: 5 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "· " + group.modelData.count
                                        color: Theme.faint
                                        font.family: Theme.font
                                        font.pixelSize: 9 * root.s
                                    }

                                    Text {
                                        anchors.left: headCount.right
                                        anchors.leftMargin: 8 * root.s
                                        anchors.right: headX.left
                                        anchors.rightMargin: 8 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: group.modelData.preview.body.length > 0
                                            ? group.modelData.preview.body
                                            : group.modelData.preview.summary
                                        color: Theme.dim
                                        font.family: Theme.font
                                        font.pixelSize: 10 * root.s
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        textFormat: Text.PlainText
                                    }

                                    Text {
                                        id: headChev
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: group.expanded ? "▾" : "▸"
                                        color: Theme.faint
                                        font.pixelSize: 9 * root.s
                                    }

                                    Text {
                                        id: headX
                                        anchors.right: headChev.left
                                        anchors.rightMargin: 7 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        opacity: headHover.hovered ? 1 : 0
                                        text: "✕"
                                        color: headXArea.containsMouse ? Theme.cream : Theme.dim
                                        font.pixelSize: 10 * root.s
                                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                                        MouseArea {
                                            id: headXArea
                                            anchors.fill: parent
                                            anchors.margins: -6 * root.s
                                            enabled: headHover.hovered
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Notifs.dismissApp(group.modelData.app)
                                        }
                                    }
                                }

                                Column {
                                    visible: group.expanded
                                    width: parent.width
                                    spacing: 2 * root.s

                                    Repeater {
                                        model: group.expanded ? group.modelData.entries : []

                                        NotifRow {
                                            required property var modelData
                                            entry: modelData
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                WheelScroller {
                    anchors.fill: parent
                    s: root.s
                    flick: notifFlick
                }
            }

            Column {
                visible: Notifs.count === 0
                width: parent.width
                topPadding: 14 * root.s
                bottomPadding: 14 * root.s
                spacing: 4 * root.s

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "静"
                    color: Theme.ghost
                    opacity: 0.55
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 32 * root.s
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "SILENCE"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Bold
                    font.letterSpacing: 2.2 * root.s
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
