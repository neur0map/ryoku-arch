import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../colors" as ColorsModule
import qs.components
import qs.services as Services

ColumnLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 20
    Layout.rightMargin: 20
    Layout.topMargin: 20
    spacing: 14

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: "System Resources"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.letterSpacing: 0.3
            color: ColorsModule.Colors.on_surface
        }

        Text {
            text: "󰍛"
            font.family: "Material Design Icons"
            font.pixelSize: 16
            color: ColorsModule.Colors.primary
            opacity: 0.6
        }
    }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: statsColumn.implicitHeight + 28
        radius: 16
        color: ColorsModule.Colors.surface_container
        border.width: 1
        border.color: ColorsModule.Colors.outline_variant

        ColumnLayout {
            id: statsColumn
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            StatBar {
                Layout.fillWidth: true
                label: "CPU"
                value: Services.System.cpu
                icon: "󰻠"
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: ColorsModule.Colors.outline_variant
            }

            StatBar {
                Layout.fillWidth: true
                label: "RAM"
                value: Services.System.ram
                icon: "󰍛"
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: ColorsModule.Colors.outline_variant
            }

            StatBar {
                Layout.fillWidth: true
                label: "Disk"
                value: Services.System.disk
                icon: "󰋊"
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: ColorsModule.Colors.outline_variant
            }

            StatBar {
                Layout.fillWidth: true
                label: "Temp"
                value: Services.System.temp
                icon: "󰔏"
                maxValue: 100
                suffix: "°C"
            }
        }
    }
}