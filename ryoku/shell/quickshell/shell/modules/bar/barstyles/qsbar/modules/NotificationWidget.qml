import QtQuick
import Quickshell

Item {
    id: rootMod
    required property var root

    readonly property string tooltipText: root.notifCount > 0
        ? (root.notifCount + (root.notifCount === 1 ? " notification" : " notifications"))
        : "No notifications"

    implicitWidth: 26
    implicitHeight: 28

    IconText {
        id: bellIcon
        anchors.centerIn: parent
        text: "\uE7F4"   // notifications (bell)
        font.pixelSize: 15
        color: root.notifCount > 0
            ? root.seal
            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // count badge — top-right, theme red with high-contrast text
    Rectangle {
        visible: root.notifCount > 0
        width: Math.max(12, badgeTxt.implicitWidth + 6)
        height: 12
        radius: 6
        color: root.seal
        anchors {
            verticalCenter: bellIcon.verticalCenter; verticalCenterOffset: -6
            horizontalCenter: bellIcon.horizontalCenter; horizontalCenterOffset: 7
        }
        Text {
            id: badgeTxt
            anchors.centerIn: parent
            text: root.notifCount > 99 ? "99" : root.notifCount
            color: root.paper
            font.family: root.mono
            font.pixelSize: 7
            font.weight: Font.Bold
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: { tip.hide() }
        onClicked: { tip.hide(); root.notifVisible = !root.notifVisible }
    }
}
