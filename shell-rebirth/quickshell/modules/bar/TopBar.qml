import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.bar.components
import "../../colors" as ColorsModule

Item {
    id: topBar

    implicitHeight: 42
    anchors.left: parent.left
    anchors.right: parent.right
    focus: true

    Item {
        anchors.fill: parent

        RowLayout {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }
            Rectangle {
                implicitWidth: 20
            }
            spacing: 8
            Workspaces {}
            Cpu {}
            Battery {}
            Clock {}
            Bluetooth {}
        }

        MediaPill {
            anchors.centerIn: parent
        }

        RowLayout {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
            }
            spacing: 10
            Network {}
            Volume {}
            Temp {}
            Memory {}
            SystemTray {}
            Rectangle {
                implicitWidth: 20
            }
        }
    }
}