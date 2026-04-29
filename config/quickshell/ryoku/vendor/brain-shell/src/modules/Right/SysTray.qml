import QtQuick
import Quickshell.Services.SystemTray
import "../../components"
import "../../windows"
import "../../"

// Ryoku: wrap in a notch-height Item so the chevron + tray icons
// vertically center in the bar instead of top-aligning at row top.
Item {
    implicitWidth:  contentRow.implicitWidth
    implicitHeight: Theme.notchHeight

    Row {
        id: contentRow
        anchors.centerIn: parent

        Row {
            id: trayRow
            spacing: 5
            visible: false
            anchors.verticalCenter: parent.verticalCenter

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

        IconBtn {
            id: toggleBtn
            anchors.verticalCenter: parent.verticalCenter
            text: trayRow.visible ? "" : ""
            onClicked: trayRow.visible = !trayRow.visible
        }
    }
}
