import QtQuick
import QtQuick.Layouts
import "Singletons"

// One commit on the update timeline: a node on a vertical rail, an area tag, the
// subject, and right-aligned hash + date. The rail links the rows into a git log;
// the newest commit (the update target) is the filled ember node, older ones are
// hollow.
Item {
    id: row

    property string hash: ""
    property string area: ""
    property string subject: ""
    property string date: ""
    property bool head: false
    property bool first: false
    property bool last: false

    implicitHeight: 50

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
        x: row.railX - (row.head ? 5 : 4)
        y: row.nodeY - (row.head ? 5 : 4)
        width: row.head ? 10 : 8
        height: width
        radius: width / 2
        color: row.head ? Theme.ember : "transparent"
        border.width: row.head ? 0 : 2
        border.color: Theme.dim
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

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: areaText.implicitWidth + 16
            implicitHeight: 20
            radius: 6
            color: Theme.surface
            border.width: 1
            border.color: Theme.line

            Text {
                id: areaText
                anchors.centerIn: parent
                text: row.area
                color: Theme.ember
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: row.subject
            color: hover.hovered ? Theme.bright : Theme.cream
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: row.hash
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 11
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 86
            text: row.date
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
        }
    }

    HoverHandler { id: hover }
}
