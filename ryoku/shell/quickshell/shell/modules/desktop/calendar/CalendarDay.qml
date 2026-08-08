pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

Item {
    id: root

    required property var day
    property var holidays: []
    property var events: []
    property bool paper: false
    property bool selected: false
    property real s: 1
    signal activated(string key)
    signal hoverChanged(string key, bool inside)

    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: root.day.key

    readonly property bool emphasized: root.selected || root.day.today || hover.hovered || root.activeFocus
    readonly property color foreground: root.paper && root.emphasized ? Theme.surface : (root.day.inMonth ? Theme.ink : Theme.faint)

    Rectangle {
        id: plate
        anchors.centerIn: parent
        width: 29 * root.s
        height: 29 * root.s
        radius: root.paper ? Theme.radiusTile * root.s : width / 2
        color: root.paper && root.emphasized
            ? Theme.ink
            : (root.day.today ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                              : (root.emphasized ? Theme.tileHover : "transparent"))
        border.width: root.day.today && !root.paper ? 1 : 0
        border.color: Theme.accent
        scale: root.emphasized ? 1 : 0.88
        Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    Text {
        anchors.centerIn: parent
        text: root.day.day
        color: root.foreground
        font.family: Theme.font
        font.pixelSize: 12 * root.s
        font.weight: root.day.today ? Font.DemiBold : Font.Medium
    }

    Rectangle {
        visible: root.holidays.length > 0
        width: 12 * root.s
        height: Math.max(1, root.s)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2 * root.s
        color: root.paper ? Theme.inkDim : Theme.accent
    }

    Rectangle {
        visible: root.events.length > 0
        width: 3 * root.s
        height: width
        radius: width / 2
        anchors.right: parent.right
        anchors.rightMargin: 4 * root.s
        anchors.top: parent.top
        anchors.topMargin: 4 * root.s
        color: root.paper ? Theme.inkDim : Theme.ink
    }

    HoverHandler {
        id: hover
        onHoveredChanged: root.hoverChanged(root.day.key, hovered)
    }
    TapHandler { onTapped: { root.forceActiveFocus(); root.activated(root.day.key); } }
    Keys.onReturnPressed: root.activated(root.day.key)
    Keys.onSpacePressed: root.activated(root.day.key)
}
