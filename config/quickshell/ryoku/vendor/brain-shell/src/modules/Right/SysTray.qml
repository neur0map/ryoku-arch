import QtQuick
import Quickshell.Services.SystemTray
import "../../components"
import "../../windows"
import "../../"

Row{
    id: root
Row {
        id: trayRow
        spacing: 5
        visible: false

        Repeater {
            model: SystemTray.items
            delegate: Image {
                width: 16
                height: 16
                source: modelData.icon
                anchors.verticalCenter: parent.verticalCenter

                MouseArea {
                    anchors.fill: parent
                    onClicked: modelData.activate()
                }
            }
        }
    }

    // Tray Toggle Button
    IconBtn {
        text: trayRow.visible ? "" : ""
        onClicked: trayRow.visible = !trayRow.visible
    }
}
