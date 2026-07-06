pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../Singletons"

// network popout content: a compact wifi control center that reuses the LinkWifi
// drill-in with its surface-only chrome stripped (no back chevron, no hotspot
// block). a wifi header eyebrow over LinkWifi's live enable toggle, rescan,
// signal-sorted network list and inline password connect. plain transparent
// Item -- the frame blob behind it IS the surface; Popout reads the reported
// implicit size to melt open to fit and grows as the list fills or a password
// row expands. pointer-driven, no keyboard focus.
Item {
    id: root

    property real s: 1
    // popout open: gates LinkWifi's live scanner so nmcli never spins while closed.
    property bool open: false

    anchors.fill: parent

    implicitWidth: 300 * s
    implicitHeight: body.implicitHeight + 27 * s

    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 13 * root.s
        anchors.leftMargin: 16 * root.s
        anchors.rightMargin: 16 * root.s
        spacing: 11 * root.s

        Row {
            spacing: 8 * root.s
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "wifi"
                fill: 1
                color: Theme.brand
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "NETWORK"
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.6 * root.s
            }
        }

        LinkWifi {
            compact: true
            s: root.s
            active: root.open
            enabled: root.open
            width: parent.width
        }
    }
}
