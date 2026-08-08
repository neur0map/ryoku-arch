import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons as Ui
import "../../shared/Singletons"

Rectangle {
    id: root

    property real s: 1
    property string label: ""
    property bool active: false

    signal activated()

    implicitWidth: Math.max(48 * s, caption.implicitWidth + 20 * s)
    implicitHeight: 24 * s
    radius: Math.max(2, LauncherConfig.radius * 0.18) * s
    color: active ? Theme.modeActive
        : (pointer.hovered ? Qt.rgba(0, 0, 0, 0.88) : Theme.modeIdle)
    border.width: 1
    border.color: active ? Theme.modeActive : Qt.rgba(1, 1, 1, 0.24)

    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.description: active ? "Active launcher mode" : "Launcher mode"
    Accessible.focusable: false
    Accessible.checkable: true
    Accessible.checked: active
    Accessible.selectable: true
    Accessible.selected: active
    Accessible.onPressAction: root.activated()

    Behavior on color {
        ColorAnimation { duration: Motion.selection; easing.type: Easing.OutCubic }
    }

    Text {
        id: caption
        anchors.centerIn: parent
        text: root.label
        color: root.active ? Theme.onModeActive : Theme.bright
        font.family: Theme.mono
        font.pixelSize: 9 * root.s
        font.weight: Font.DemiBold
        font.letterSpacing: 1.4 * root.s
    }

    HoverHandler {
        id: pointer
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.activated()
    }
}
