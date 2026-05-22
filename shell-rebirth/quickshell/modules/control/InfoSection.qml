import QtQuick.Layouts
import"../../colors" as ColorsModule
import Quickshell
import Quickshell.Io
import QtQuick
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
            text: "System Info"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.letterSpacing: 0.3
            color: ColorsModule.Colors.on_surface
        }

        Text {
            text: "󰋖"
            font.family: "Material Design Icons"
            font.pixelSize: 16
            color: ColorsModule.Colors.primary
            opacity: 0.6
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: infoColumn.implicitHeight + 28
        radius: 16
        color: ColorsModule.Colors.surface_container
        border.width: 1
        border.color: ColorsModule.Colors.outline_variant

        ColumnLayout {
            id: infoColumn
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            InfoRow {
                Layout.fillWidth: true
                icon: "󰥔"
                label: "Uptime"
                value: Services.System.uptime
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: ColorsModule.Colors.outline_variant
            }

            InfoRow {
                Layout.fillWidth: true
                icon: "󰌽"
                label: "Network"
                value: Services.Network.wifiEnabled ? "Connected" : "Disconnected"
            }
        }
    }
}