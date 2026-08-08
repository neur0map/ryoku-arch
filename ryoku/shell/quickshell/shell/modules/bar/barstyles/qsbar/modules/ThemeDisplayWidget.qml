import QtQuick
import Quickshell

Item {
    id: rootMod
    required property var root
    property var screen: null

    implicitWidth: 22
    implicitHeight: 28

    IconText {
        anchors.centerIn: parent
        text: "palette"
        font.pixelSize: 14
        font.weight: Font.Normal
        color: root.imagePickerVisible
            ? root.seal
            : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.65)
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    TooltipMixin {
        id: tip; root: rootMod.root; owner: rootMod
        text: "Wallpaper"
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
            rootMod.root.toggleImagePicker("wallpaper", rootMod.screen)
        }
    }
}
