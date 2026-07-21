pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Bluetooth
import "Singletons"

// atoll status chips: wifi / bluetooth / volume / battery ride as bright bone
// chips that light when on (Ryoku's inversion standing in for ilyamiro's warm
// gradient chips) and stay a faint dark plate when off; a plain bell trails.
// each chip opens its popout at the chip's centre. Ryoku's Network is minimal
// (no SSID), so wifi reads On/Off/LAN rather than the network name.
Row {
    id: status

    property real s: 1
    property real slotH: 26 * s
    // ryoku variant: Space Grotesk + square chips (set by AtollBar).
    property bool ryoku: false
    signal requestPopout(string name, real center)

    spacing: 7 * s

    function open(name, item) {
        var p = item.mapToItem(null, item.width / 2, item.height / 2);
        status.requestPopout(name, p.x);
    }

    // a chip that inverts to a bone plate (dark ink) when its thing is on.
    component Chip: Rectangle {
        id: chip
        property string glyph
        property string label
        property bool on: false
        property string popout: ""
        property color accent: Theme.bright
        anchors.verticalCenter: parent.verticalCenter
        height: status.slotH
        width: chipRow.implicitWidth + 20 * status.s
        radius: status.ryoku ? 3 * status.s : 10 * status.s
        color: chip.on ? chip.accent
            : (ca.containsMouse ? Qt.alpha(Theme.tileBg, 0.7) : Qt.alpha(Theme.tileBg, 0.4))
        scale: ca.containsMouse ? 1.05 : 1.0
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
        Behavior on color { ColorAnimation { duration: 200 } }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 7 * status.s
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                fill: 1
                color: chip.on ? Theme.cardBot : Theme.subtle
                font.pixelSize: 15 * status.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.label.length > 0
                text: chip.label
                color: chip.on ? Theme.cardBot : Theme.cream
                font.family: status.ryoku ? Theme.font : Theme.mono
                font.pixelSize: 11 * status.s
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }
        MouseArea {
            id: ca
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (chip.popout.length) status.open(chip.popout, chip)
        }
    }

    Chip {
        readonly property bool eth: Network.kind === "ethernet"
        glyph: eth ? "lan"
            : (!Network.wifiRadio ? "wifi_off"
            : (Network.kind !== "wifi" ? "signal_wifi_off"
            : (Network.level > 0.66 ? "signal_wifi_4_bar"
            : (Network.level > 0.33 ? "network_wifi_3_bar" : "network_wifi_1_bar"))))
        label: eth ? "LAN" : (Network.kind === "wifi" ? "On" : "Off")
        on: Network.kind !== ""
        popout: "network"
    }

    Chip {
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property var conn: (adapter && adapter.enabled)
            ? Bluetooth.devices.values.filter(function (d) { return d && d.connected; }) : []
        visible: adapter !== null
        glyph: (!adapter || !adapter.enabled) ? "bluetooth_disabled"
            : (conn.length > 0 ? "bluetooth_connected" : "bluetooth")
        label: conn.length > 0 ? (conn[0].name || "On") : ((adapter && adapter.enabled) ? "On" : "Off")
        on: conn.length > 0
        popout: "bluetooth"
    }

    Chip {
        readonly property var sink: Audio.sink
        readonly property real vol: (sink && sink.audio) ? sink.audio.volume : 0
        readonly property bool muted: (sink && sink.audio) ? sink.audio.muted : false
        glyph: muted ? "volume_off"
            : (vol > 0.5 ? "volume_up" : (vol > 0 ? "volume_down" : "volume_mute"))
        label: Math.round(vol * 100) + "%"
        on: !muted && vol > 0
        popout: "mixer"
    }

    Chip {
        visible: Battery.present
        glyph: Battery.charging ? "battery_charging_full"
            : (Battery.frac > 0.8 ? "battery_full"
            : (Battery.frac > 0.4 ? "battery_4_bar"
            : (Battery.frac > 0.15 ? "battery_2_bar" : "battery_1_bar")))
        label: Battery.pct + "%"
        on: true
        accent: (Battery.low && !Battery.charging) ? Theme.verm : Theme.bright
        popout: "battery"
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 28 * status.s
        height: status.slotH
        MaterialIcon {
            id: bell
            anchors.centerIn: parent
            text: Flags.dnd ? "notifications_off"
                : (Notifs.unread > 0 ? "notifications_unread" : "notifications")
            fill: Notifs.unread > 0 && !Flags.dnd ? 1 : 0
            color: Flags.dnd ? Theme.vermLit : (Notifs.unread > 0 ? Theme.cream : Theme.subtle)
            font.pixelSize: 16 * status.s
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: status.open("inbox", parent)
        }
    }
}
