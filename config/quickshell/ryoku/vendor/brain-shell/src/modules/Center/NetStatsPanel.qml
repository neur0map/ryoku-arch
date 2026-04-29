import QtQuick
import "../../"
import "../../components"

Item {
    id: root

    required property var service

    Column {
        anchors.centerIn: parent
        width:            parent.width - 16
        spacing:          10

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:           "Network"
            font.pixelSize: 11
            font.weight:    Font.Medium
            color:          Qt.rgba(1, 1, 1, 0.4)
        }

        Column {
            width:   parent.width
            spacing: 6

            StatRow {
                width:      parent.width
                label:      "Interface"
                value:      root.service.iface
            }

            StatRow {
                width:      parent.width
                label:      "↑ Upload"
                value:      root.service.upSpeed
                valueColor: "#90ef90"
            }

            StatRow {
                width:      parent.width
                label:      "↓ Download"
                value:      root.service.downSpeed
                valueColor: "#a6d0f7"
            }
        }
    }
}
