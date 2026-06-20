pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// A small set of mutually exclusive options as a labelled segmented control. Used
// for enum knobs (visualiser style, shape, position) per the segmented convention,
// the right control when there are a few named choices. Reports chosen(key).
Item {
    id: row

    property string label: ""
    property var options: []     // [{ key, label }]
    property string current: ""

    signal chosen(string key)

    implicitWidth: 320
    implicitHeight: 38

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - track.width - 14
        elide: Text.ElideRight
        text: row.label
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 30
        width: seg.width + 6
        radius: 9
        color: Theme.surfaceLo
        border.width: 1
        border.color: Theme.line

        Row {
            id: seg
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: row.options

                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    readonly property bool active: row.current === cell.modelData.key
                    width: cellText.implicitWidth + 26
                    height: 26
                    radius: 7
                    color: cell.active ? Theme.ember : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.quick } }

                    Text {
                        id: cellText
                        anchors.centerIn: parent
                        text: cell.modelData.label
                        color: cell.active ? Theme.onAccent : (cellHov.hovered ? Theme.cream : Theme.dim)
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: cell.active ? Font.DemiBold : Font.Medium
                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                    }

                    HoverHandler { id: cellHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: row.chosen(cell.modelData.key) }
                }
            }
        }
    }
}
