import QtQuick
import "../../modules"

// The wallpaper-palette accent picker: color01..07 + foreground. Selecting emits
// `chose(id)`; the caller writes root.barColor. Lifted from the old ControlPanel
// BAR COLOR grid.
Grid {
    id: sw
    property var root
    property var options: root ? root.barColorOptions : []
    property string current: ""
    signal chose(string id)

    columns: 8
    columnSpacing: 6
    rowSpacing: 6

    Repeater {
        model: sw.options
        delegate: Rectangle {
            id: cell
            required property string modelData
            readonly property bool on: sw.current === modelData
            width: 24
            height: 24
            radius: sw.root.tileRadius
            color: sw.root.paletteColor(modelData)
            border.width: on ? 2 : 1
            border.color: on ? sw.root.ink : sw.root.sep
            scale: ma.containsMouse ? 1.06 : 1.0
            z: ma.containsMouse ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

            UiText {
                anchors.centerIn: parent
                text: cell.modelData === "foreground" ? "FG" : cell.modelData.slice(-2)
                color: sw.root.paletteContrastColor(cell.modelData)
                font.family: sw.root.mono
                font.pixelSize: 9
                font.weight: Font.Medium
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: sw.chose(cell.modelData)
            }
        }
    }
}
