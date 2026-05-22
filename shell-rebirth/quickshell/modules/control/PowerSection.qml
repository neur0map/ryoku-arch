import QtQuick
import QtQuick.Layouts
import "../../colors" as ColorsModule
import qs.components

ColumnLayout {
    Layout.fillWidth: true
    Layout.leftMargin: 20
    Layout.rightMargin: 20
    Layout.topMargin: 20
    Layout.bottomMargin: 30
    spacing: 14

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: "Power Options"
            font.pixelSize: 15
            font.weight: Font.DemiBold
            font.letterSpacing: 0.3
            color: ColorsModule.Colors.error
        }

        Text {
            text: "󰐥"
            font.family: "Material Design Icons"
            font.pixelSize: 16
            color: ColorsModule.Colors.on_primary_container
            opacity: 0.6
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 14
        rowSpacing: 14

        ActionButton {
            icon: "󰐥"
            label: "Power Off"
            buttonColor: ColorsModule.Colors.error_container
            onClicked: run("systemctl poweroff")
        }

        ActionButton {
            icon: "󰜉"
            label: "Restart"
            buttonColor: ColorsModule.Colors.primary_container
            onClicked: run("systemctl reboot")
        }

        ActionButton {
            icon: "󰒲"
            label: "Sleep"
            buttonColor: ColorsModule.Colors.secondary_container
            onClicked: run("systemctl suspend")
        }

        ActionButton {
            icon: "󰍃"
            label: "Log Out"
            buttonColor: ColorsModule.Colors.tertiary_container
            onClicked: run("loginctl terminate-user $USER")
        }
    }

}