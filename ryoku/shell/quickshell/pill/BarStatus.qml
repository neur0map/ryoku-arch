pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// status cluster in the reference iconography: Material Symbols for network,
// bluetooth-adjacent battery, and notifications, tinted like caelestia's
// m3secondary rail. each glyph is its own click target routing to the surface
// that owns it (link, battery, inbox). `vertical` stacks the glyphs.
Grid {
    id: status

    property real s: 1
    property bool vertical: false

    signal requestSurface(string name)

    readonly property real glyphPx: 14 * s

    columns: vertical ? 1 : 4
    columnSpacing: 9 * s
    rowSpacing: 7 * s
    verticalItemAlignment: Grid.AlignVCenter
    horizontalItemAlignment: Grid.AlignHCenter

    // network: wifi strength or ethernet, Material glyphs.
    Item {
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
            onClicked: status.requestSurface("link")
        }
    }

    // battery: the Material cell family, filled by charge, accent when low.
    Item {
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
            onClicked: status.requestSurface("battery")
        }
    }

    // notifications: the bell, filled with an accent tint while something waits.
    Item {
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
            onClicked: status.requestSurface("inbox")
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
