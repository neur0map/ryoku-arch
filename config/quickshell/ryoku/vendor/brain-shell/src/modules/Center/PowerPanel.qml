import QtQuick
import "../../"
import "../../components"

Item {
    id: root

    required property var cpuFreqService
    required property var envyService

    Column {
        anchors.centerIn: parent
        spacing:          16

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            // Label + lock icon hinting auto-cpufreq manages this
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5

                Text {
                    text:           "󰌾"
                    font.pixelSize: 11
                    color:          Qt.rgba(1, 1, 1, 0.25)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text:           "Power Profile"
                    font.pixelSize: 11
                    font.weight:    Font.Medium
                    color:          Qt.rgba(1, 1, 1, 0.4)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                ProfileButton {
                    label:     root.cpuFreqService.activeProfile === "performance" ? "Performance" : "Power Saver"
                    active:    true
                    enabled:   true
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width:  200
            height: 1
            color:  Qt.rgba(1, 1, 1, 0.07)
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "GPU Mode"
                font.pixelSize: 11
                font.weight:    Font.Medium
                color:          Qt.rgba(1, 1, 1, 0.4)
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                ProfileButton {
                    label:     "Integrated"
                    active:    root.envyService.currentMode === "integrated"
                    enabled:   !root.envyService.busy
                    onClicked: root.envyService.switchMode("integrated")
                }
                ProfileButton {
                    label:     "Hybrid"
                    active:    root.envyService.currentMode === "hybrid"
                    enabled:   !root.envyService.busy
                    onClicked: root.envyService.switchMode("hybrid")
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           "GPU mode switch requires a reboot"
                font.pixelSize: 10
                color:          Qt.rgba(1, 1, 1, 0.25)
            }
        }
    }
}
