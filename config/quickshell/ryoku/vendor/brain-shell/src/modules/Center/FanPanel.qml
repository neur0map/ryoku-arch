import QtQuick
import "../../"
import "../../components"

Item {
    id: root

    required property var service

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter:   parent.verticalCenter
        spacing: 10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:           "Fan Control"
            font.pixelSize: 14
            color:          Qt.rgba(1, 1, 1, 0.35)
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: parent.parent.width * 0.1

            ProfileButton {
                icon:      "󱗰"
                label:     "Quiet"
                active:    service.mode === "quiet"
                onClicked: service.setMode("quiet")
            }
            ProfileButton {
                icon:      "󰁪"
                label:     "Auto"
                active:    service.mode === "auto"
                onClicked: service.setMode("auto")
            }
            ProfileButton {
                icon:      "󱓞"
                label:     "Max"
                active:    service.mode === "max"
                onClicked: service.setMode("max")
            }
        }
    }
}
