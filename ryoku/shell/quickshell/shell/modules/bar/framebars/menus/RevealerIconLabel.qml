pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"

// The collapsed header content of a RevealerButton (contract 16 sec 2.4,
// contract 06 sec 2.2): a leading icon, an elided label that takes the slack,
// and an optional trailing icon shown only when named. Icons are 16px and
// track `iconColor` so a host row can dim or accent them; the label is 14px.
Item {
    id: root

    property string iconName: ""
    property string label: ""
    property string secondaryIconName: ""
    property color iconColor: Theme.ink(Theme.effectiveSurface)

    implicitHeight: Math.max(Theme.iconSm, text.implicitHeight)
    implicitWidth: (root.iconName ? Theme.iconSm + 12 : 0) + text.implicitWidth
        + (root.secondaryIconName ? Theme.iconSm + 12 : 0)

    MaterialIcon {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        visible: root.iconName.length > 0
        width: visible ? Theme.iconSm : 0
        height: Theme.iconSm
        font.pixelSize: Theme.iconSm
        text: root.iconName
        color: root.iconColor
    }

    Text {
        id: text
        anchors.left: root.iconName ? icon.right : parent.left
        anchors.leftMargin: root.iconName ? 12 : 0
        anchors.right: secondary.visible ? secondary.left : parent.right
        anchors.rightMargin: secondary.visible ? 12 : 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        elide: Text.ElideRight
        color: root.iconColor
        font.family: Theme.fontPrimary
        font.pixelSize: Theme.fontSm
    }

    MaterialIcon {
        id: secondary
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.secondaryIconName.length > 0
        width: visible ? Theme.iconSm : 0
        height: Theme.iconSm
        font.pixelSize: Theme.iconSm
        text: root.secondaryIconName
        color: root.iconColor
    }
}
