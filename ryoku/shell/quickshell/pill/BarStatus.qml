pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Bluetooth
import "Singletons"

// status cluster in the reference iconography: Material Symbols for volume,
// network, bluetooth, battery and notifications, tinted like caelestia's
// m3secondary rail. `vertical` stacks the glyphs.
//
// each glyph opens its own popout on CLICK, positioned at the glyph: the popout
// grows from the bar edge at the icon (down from a top bar, up from a bottom
// bar), like the reference. requestPopout carries the popout name + the icon's
// along-axis centre in window coords (the popout's own coordinate space). the
// bell opens the inbox notification-centre popout at the bell, like the glyphs.
Grid {
    id: status

    property real s: 1
    property bool vertical: false

    signal requestPopout(string name, real center)
    signal requestSurface(string name)

    // open a named popout anchored at an icon: report the icon's centre along
    // the bar axis (x on a top/bottom bar, y on a side bar) in window coords.
    function open(name, item) {
        const p = item.mapToItem(null, item.width / 2, item.height / 2);
        requestPopout(name, vertical ? p.y : p.x);
    }

    readonly property real glyphPx: 14 * s

    columns: vertical ? 1 : 8
    columnSpacing: 9 * s
    rowSpacing: 7 * s
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter

    // volume: click opens the mixer.
    Item {
        id: volIcon
        width: status.glyphPx + 4 * status.s
        height: status.glyphPx + 4 * status.s

        readonly property var sink: Audio.sink
        readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
        readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

        MaterialIcon {
            anchors.centerIn: parent
            text: volIcon.muted ? "volume_off"
                : (volIcon.vol > 0.5 ? "volume_up"
                : (volIcon.vol > 0 ? "volume_down" : "volume_mute"))
            fill: 1
            color: volIcon.muted ? Theme.faint : Theme.subtle
            font.pixelSize: status.glyphPx
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: status.open("mixer", volIcon)
        }
    }

    // network: click opens the network popout.
    Item {
        id: netIcon
        width: status.glyphPx + 4 * status.s
        height: status.glyphPx + 4 * status.s

        MaterialIcon {
            anchors.centerIn: parent
            text: {
                if (Network.kind === "ethernet")
                    return "lan";
                if (!Network.wifiRadio)
                    return "wifi_off";
                if (Network.kind !== "wifi")
                    return "signal_wifi_off";
                return Network.level > 0.8 ? "signal_wifi_4_bar"
                    : (Network.level > 0.55 ? "network_wifi_3_bar"
                    : (Network.level > 0.3 ? "network_wifi_2_bar" : "network_wifi_1_bar"));
            }
            fill: 1
            color: Network.kind === "" ? Theme.faint : Theme.subtle
            font.pixelSize: status.glyphPx
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: status.open("network", netIcon)
        }
    }

    // bluetooth: click opens the bluetooth popout.
    Item {
        id: btIcon
        visible: Bluetooth.defaultAdapter !== null
        width: status.glyphPx + 4 * status.s
        height: status.glyphPx + 4 * status.s

        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property bool anyConnected: Bluetooth.devices.values.some(function (d) { return d && d.connected; })

        MaterialIcon {
            anchors.centerIn: parent
            text: !btIcon.adapter || !btIcon.adapter.enabled ? "bluetooth_disabled"
                : (btIcon.anyConnected ? "bluetooth_connected" : "bluetooth")
            fill: 1
            color: btIcon.adapter && btIcon.adapter.enabled ? Theme.subtle : Theme.faint
            font.pixelSize: status.glyphPx
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: status.open("bluetooth", btIcon)
        }
    }

    // battery: click opens the battery popout.
    Item {
        id: battIcon
        visible: Battery.present
        width: battRow.implicitWidth
        height: battRow.implicitHeight

        Row {
            id: battRow
            spacing: 3 * status.s

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                    if (Battery.charging)
                        return "battery_charging_full";
                    const f = Battery.frac;
                    if (f > 0.95) return "battery_full";
                    if (f > 0.8) return "battery_6_bar";
                    if (f > 0.65) return "battery_5_bar";
                    if (f > 0.5) return "battery_4_bar";
                    if (f > 0.35) return "battery_3_bar";
                    if (f > 0.2) return "battery_2_bar";
                    return "battery_1_bar";
                }
                fill: 1
                color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.subtle)
                font.pixelSize: status.glyphPx + 1 * status.s
            }
            Text {
                visible: !status.vertical
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.pct + "%"
                color: Battery.low ? Theme.vermLit : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 9.5 * status.s
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: status.open("battery", battIcon)
        }
    }

    // notifications: the bell, filled with an accent tint while something waits.
    // opens the inbox notification-centre popout at the bell.
    Item {
        id: bellIcon
        width: status.glyphPx + 4 * status.s
        height: status.glyphPx + 4 * status.s

        MaterialIcon {
            anchors.centerIn: parent
            text: Flags.dnd ? "notifications_off"
                : (Notifs.unread > 0 ? "notifications_unread" : "notifications")
            fill: Notifs.unread > 0 && !Flags.dnd ? 1 : 0
            color: Flags.dnd ? Theme.vermLit
                : (Notifs.unread > 0 ? Theme.cream : Theme.subtle)
            font.pixelSize: status.glyphPx
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: status.open("inbox", bellIcon)
        }
    }

    // keep-awake shows only while it burns.
    MaterialIcon {
        visible: Flags.keepAwake
        text: "coffee"
        color: Theme.flameGlow
        font.pixelSize: status.glyphPx
    }
}
