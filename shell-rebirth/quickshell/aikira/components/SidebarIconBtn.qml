import QtQuick
import "../../colors" as ColorsModule

Item {
    id: root
    width: 30; height: 30

    property string icon: ""
    property string tooltip: ""
    property bool   active: false
    signal clicked()

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: active
            ? ColorsModule.Colors.primary_container
            : (area.containsMouse ? ColorsModule.Colors.surface_container_high : "transparent")

        Behavior on color { ColorAnimation { duration: 110 } }

        Text {
            anchors.centerIn: parent
            text: root.icon
            font.pixelSize: 14
            color: active
                ? ColorsModule.Colors.on_primary_container
                : ColorsModule.Colors.on_surface_variant
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // Tooltip
    Rectangle {
        visible: area.containsMouse && root.tooltip.length > 0
        anchors { bottom: parent.top; horizontalCenter: parent.horizontalCenter; bottomMargin: 4 }
        width: tipText.implicitWidth + 12; height: 22
        radius: 6
        color: ColorsModule.Colors.surface_container_highest
        z: 99

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.tooltip
            font.pixelSize: 10
            color: ColorsModule.Colors.on_surface
        }
    }
}
