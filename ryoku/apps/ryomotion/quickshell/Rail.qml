pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// The tool rail: a vertical strip of icon buttons down the left edge. Picking
// one switches the contextual panel (the Inspector) beside it. Icon + label,
// the selected one lit in ember with a left accent, like openscreen's rail.
Rectangle {
    id: rail
    width: 74
    color: Theme.bgTop

    readonly property var tools: [
        { "key": "canvas", "icon": "canvas", "label": "Canvas" },
        { "key": "frame", "icon": "frame", "label": "Frame" },
        { "key": "zoom", "icon": "zoom", "label": "Zoom" },
        { "key": "cut", "icon": "cut", "label": "Cut" },
        { "key": "speed", "icon": "speed", "label": "Speed" },
        { "key": "text", "icon": "text", "label": "Text" },
        { "key": "overlay", "icon": "image", "label": "Overlay" },
        { "key": "music", "icon": "music", "label": "Music" },
        { "key": "cursor", "icon": "cursor", "label": "Cursor" },
        { "key": "export", "icon": "export", "label": "Export" }
    ]
    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Theme.hair }

    Column {
        anchors.top: parent.top
        anchors.topMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        Repeater {
            model: rail.tools
            delegate: Item {
                id: btn
                required property var modelData
                readonly property bool on: Project.tool === modelData.key
                width: 66
                height: 52

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: 10
                    color: btn.on ? Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.14)
                                  : ma.containsMouse ? Theme.field : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3; height: 24; radius: 2
                    color: Theme.ember
                    opacity: btn.on ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    Icon {
                        name: btn.modelData.icon
                        size: 21
                        tint: btn.on ? Theme.ember : ma.containsMouse ? Theme.cream : Theme.dim
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    Text {
                        text: btn.modelData.label
                        color: btn.on ? Theme.ember : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 10
                        font.weight: btn.on ? Font.DemiBold : Font.Medium
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Project.tool = btn.modelData.key
                }
            }
        }
    }
}
