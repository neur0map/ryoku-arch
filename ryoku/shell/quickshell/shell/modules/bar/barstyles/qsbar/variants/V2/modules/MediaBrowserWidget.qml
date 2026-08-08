import QtQuick
import Quickshell

// Combined screenshots/videos browser launcher.
// Left-click = screenshots, right-click = videos. Sits left of the theme icon.
Item {
    id: rootMod
    required property var root
    property var screen: null
    readonly property color contentColor: root.widgetContentColor("G10", root.widgetIconColor)

    implicitWidth: root.v2ActionIconCellWidth
    implicitHeight: 28

    IconText {
        anchors.centerIn: parent
        text: "collections"
        font.pixelSize: 14
        font.weight: Font.Normal
        color: root.mediaBrowserVisible
            ? (root.widgetHasFill("G10") ? rootMod.contentColor : root.seal)
            : rootMod.contentColor
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    TooltipMixin {
        id: tip; root: rootMod.root; owner: rootMod
        text: "L: Screenshots  R: Videos"
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: tip.show()
        onExited:  tip.hide()
        onClicked: function(mouse) {
            tip.hide()
            if (root.mediaBrowserVisible) {
                root.mediaBrowserVisible = false
                return
            }
            root.activatePopupScreen(rootMod.screen)
            root.mediaBrowserMode    = (mouse.button === Qt.RightButton) ? "videos" : "screenshots"
            root.mediaBrowserVisible = true
        }
    }
}
