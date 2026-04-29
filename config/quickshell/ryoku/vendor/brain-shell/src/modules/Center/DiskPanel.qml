import QtQuick
import "../../"
import "../../components"

Item {
    id: root

    required property var service

    Column {
        anchors.centerIn: parent
        width:            parent.width - 16
        spacing:          6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:           "Disks"
            font.pixelSize: 11
            font.weight:    Font.Medium
            color:          Qt.rgba(1, 1, 1, 0.4)
        }

        Column {
            width:   parent.width
            spacing: 10

            Repeater {
                model: root.service.disks

                delegate: DiskBar {
                    width:    parent.width
                    source:   modelData.source
                    mount:    modelData.mount
                    usedPct:  modelData.usedPct
                    usedStr:  modelData.usedStr
                    totalStr: modelData.totalStr
                }
            }
        }
    }
}
