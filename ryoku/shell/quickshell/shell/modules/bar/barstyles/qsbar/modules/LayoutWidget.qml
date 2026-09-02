import QtQuick
import Quickshell
import shell.services

Item {
    id: rootMod
    required property var root

    readonly property bool iconOnly: root.iconOnly("G19")

    property string layout: {
        var value = KeyboardLayout.variant || KeyboardLayout.layout || ""
        if (!value)
            return "US"

        var match = value.match(/$([^)]+)$/)
        if (match) {
            var inner = match[1].trim().toUpperCase()
            return inner.length <= 4 ? inner : inner.slice(0, 2)
        }
        return value.length <= 4 ? value.toUpperCase() : value.slice(0, 2).toUpperCase()
    }

    readonly property string layoutIcon: "keyboard"
    readonly property color contentColor: root.widgetContentColor("G19", root.widgetIconColor)

    readonly property string tooltipText: "Keyboard layout · " + rootMod.layout

    visible: root.modLayout && implicitWidth > 0.5
    implicitWidth: root.modLayout ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modLayout ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4

        IconText {
            anchors.verticalCenter: parent.verticalCenter

            text: rootMod.layoutIcon
            color: rootMod.contentColor

            font.pixelSize: 15
            font.weight: Font.Medium
            fill: 1

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
        }

        UiText {
            visible: !root.iconOnly("G19")

            anchors.verticalCenter: parent.verticalCenter

            text: rootMod.layout
            color: rootMod.contentColor

            font.family: root.mono
            font.pixelSize: 12

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
        }
    }

    TooltipMixin {
        id: tip
        root: rootMod.root
        owner: rootMod
        text: rootMod.tooltipText
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: tip.show()
        onExited: tip.hide()

        onClicked: function(mouse) {
            tip.hide()
            if (mouse.button === Qt.RightButton) {
                Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", "next"])
            } else {
                Quickshell.execDetached(["ryoku-shell", "hub", "open", "input"])
            }
        }
    }
}
