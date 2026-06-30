import QtQuick
import "Singletons"

// The right half: the live rice preview as the hero, the wallust scheme beneath
// it, and the commit actions. Everything follows Wallhaven.selected.
Item {
    id: pane

    Row {
        id: eyebrow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 16
        spacing: 7

        Rectangle { width: 5; height: 5; radius: 1; color: Theme.brand; anchors.verticalCenter: parent.verticalCenter }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Live preview"
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10
            font.letterSpacing: 2
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
        }
        Item { width: pane.width - 220; height: 1 }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Wallhaven.selected ? Wallhaven.selected.resolution : ""
            color: Theme.subtle
            font.family: Theme.mono
            font.pixelSize: 11
        }
    }

    Rectangle {
        id: mockFrame
        anchors.top: eyebrow.bottom
        anchors.topMargin: 12
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: palette.top
        anchors.bottomMargin: 14
        radius: 13
        clip: true
        color: Theme.surfaceLo
        border.width: 1
        border.color: Theme.line

        MockDesktop {
            anchors.fill: parent
            anchors.margins: 1
            visible: Wallhaven.selected !== null
        }

        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: Wallhaven.selected === null
            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "wallpaper"; size: 28; tint: Theme.faint }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Pick a wallpaper to preview your rice"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 12
            }
        }

        // a quiet busy veil while applying.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            visible: Wallhaven.busy
            Text {
                anchors.centerIn: parent
                text: Wallhaven.status
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: 12
                font.letterSpacing: 1
            }
        }
    }

    PaletteRow {
        id: palette
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: actions.top
        anchors.bottomMargin: 14
        height: 22
        colors: Wallhaven.palette
    }

    Row {
        id: actions
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 38
        spacing: 10

        HubButton {
            primary: true
            icon: "wallpaper"
            label: "Set wallpaper"
            enabled: Wallhaven.selected !== null && !Wallhaven.busy
            onClicked: Wallhaven.apply()
        }
        HubButton {
            icon: "download"
            label: "Save"
            enabled: Wallhaven.selected !== null && !Wallhaven.busy
            onClicked: Wallhaven.download()
        }
        HubButton {
            icon: "external"
            label: "Open"
            enabled: Wallhaven.selected !== null
            onClicked: Wallhaven.openWeb()
        }
    }
}
