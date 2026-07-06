pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// status cluster: network, battery, notifications, dnd. each glyph is its own
// click target routing to the surface that owns it (link, battery, inbox), so
// the bar answers "am I online / charged / pinged" at a glance and one click.
Row {
    id: status

    property real s: 1

    signal requestSurface(string name)

    spacing: 10 * s

    // network: wifi arcs or an ethernet plug tick; faint when offline.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 17 * status.s
        height: 17 * status.s

        WifiGlyph {
            anchors.fill: parent
            visible: Network.kind !== "ethernet"
            s: status.s * 0.92
            level: Network.level
            on: Network.wifiRadio && Network.kind === "wifi"
        }
        GlyphIcon {
            anchors.fill: parent
            visible: Network.kind === "ethernet"
            name: "ethernet"
            color: Theme.subtle
            stroke: 1.6
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4 * status.s
            cursorShape: Qt.PointingHandCursor
            onClicked: status.requestSurface("link")
        }
    }

    // battery: cell + tight percentage, only on machines that have one.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        visible: Battery.present
        width: battRow.implicitWidth
        height: battRow.implicitHeight

        Row {
            id: battRow
            spacing: 5 * status.s

            BatteryGlyph {
                anchors.verticalCenter: parent.verticalCenter
                s: status.s * 0.9
                frac: Battery.frac
                charging: Battery.charging
                low: Battery.low
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.pct
                color: Battery.low ? Theme.vermLit : (Battery.charging ? Theme.flameGlow : Theme.subtle)
                font.family: Theme.mono
                font.pixelSize: 9 * status.s
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4 * status.s
            cursorShape: Qt.PointingHandCursor
            onClicked: status.requestSurface("battery")
        }
    }

    // notifications: bell with an ember dot while something waits.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 16 * status.s
        height: 16 * status.s

        GlyphIcon {
            anchors.fill: parent
            name: "inbox"
            color: Notifs.unread > 0 ? Theme.cream : Theme.iconDim
            stroke: 1.7
        }
        Rectangle {
            visible: Notifs.unread > 0
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -1.5 * status.s
            anchors.rightMargin: -1.5 * status.s
            width: 5 * status.s
            height: 5 * status.s
            radius: width / 2
            color: Theme.flameGlow
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4 * status.s
            cursorShape: Qt.PointingHandCursor
            onClicked: status.requestSurface("inbox")
        }
    }

    GlyphIcon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Flags.dnd
        width: 15 * status.s
        height: 15 * status.s
        name: "dnd"
        color: Theme.vermLit
        stroke: 1.6
    }
}
