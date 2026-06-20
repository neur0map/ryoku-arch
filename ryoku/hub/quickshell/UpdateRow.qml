import QtQuick
import QtQuick.Layouts
import "Singletons"

// One incoming commit: a node on a vertical rail, the commit subject, and a
// right-aligned short hash. The list mirrors `git log <channel>..origin/<channel>`.
Item {
    id: row

    property string name: ""
    property string fromVersion: ""
    property string toVersion: ""
    property bool first: false
    property bool last: false

    implicitHeight: 44

    readonly property real railX: 13
    readonly property real nodeY: height / 2

    Rectangle {
        x: row.railX - 1
        width: 2
        y: 0
        height: row.nodeY - 6
        color: Theme.line
        visible: !row.first
    }

    Rectangle {
        x: row.railX - 1
        width: 2
        y: row.nodeY + 6
        height: row.height - (row.nodeY + 6)
        color: Theme.line
        visible: !row.last
    }

    Rectangle {
        x: row.railX - 4
        y: row.nodeY - 4
        width: 8
        height: 8
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.ember
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        radius: 9
        color: hover.hovered ? Theme.surfaceLo : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 40
        anchors.rightMargin: 12
        spacing: 13

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: row.name
            color: hover.hovered ? Theme.bright : Theme.cream
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: row.fromVersion !== "" ? (row.fromVersion + "  \u2192  " + row.toVersion) : row.toVersion
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }

    HoverHandler { id: hover }
}
