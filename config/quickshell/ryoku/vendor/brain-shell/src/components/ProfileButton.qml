import QtQuick
import "../"

Item {
    id: root

    property string label:   ""
    property string icon:    ""
    property bool   active:  false
    // `enabled` is inherited from Item — no redeclaration needed

    signal clicked()

    implicitWidth:  row.implicitWidth + 24
    implicitHeight: 28

    opacity: root.enabled ? 1 : 0.35
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Rectangle {
        anchors.fill: parent
        radius:       height / 2

        color: root.active
                   ? Theme.active
                   : (hov.hovered && root.enabled ? Qt.rgba(1,1,1,0.08) : "transparent")
        border.color: root.active
                          ? Theme.active
                          : Qt.rgba(1, 1, 1, 0.18)
        border.width: 1

        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            visible:        root.icon !== ""
            text:           root.icon
            font.pixelSize: 12
            color:          root.active ? Theme.background : Qt.rgba(1, 1, 1, 0.7)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        Text {
            text:           root.label
            font.pixelSize: 11
            font.weight:    root.active ? Font.Medium : Font.Normal
            color:          root.active ? Theme.background : Qt.rgba(1, 1, 1, 0.7)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: 120 } }
        }
    }

    HoverHandler { id: hov; cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    MouseArea {
        anchors.fill: parent
        enabled:      root.enabled
        onClicked:    root.clicked()
    }
}
