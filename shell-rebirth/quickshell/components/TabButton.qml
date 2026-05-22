import QtQuick
import "../colors" as ColorsModule

Rectangle {
    id: root
    property string text
    property bool active: false

    width: 90
    height: 32
    radius: 8
    color: active ? ColorsModule.Colors.primary_container : ColorsModule.Colors.secondary_container

    signal clicked()

    Text {
        anchors.centerIn: parent
        text: root.text
        color: ColorsModule.Colors.on_surface
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
