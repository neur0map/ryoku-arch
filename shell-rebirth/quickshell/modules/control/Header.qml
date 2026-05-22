import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../colors" as ColorsModule

Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 100
    color: "transparent"

    gradient: Gradient {
        GradientStop { position: 0.0; color: ColorsModule.Colors.primary_container }
        GradientStop { position: 1.0; color: Qt.darker(ColorsModule.Colors.primary_container, 1.1) }
    }

    Rectangle {
        width: parent.width * 0.4
        height: parent.height
        anchors.right: parent.right
        color: ColorsModule.Colors.secondary_container
        opacity: 0.1
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "Control Center"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                    font.letterSpacing: -0.5
                    color: ColorsModule.Colors.on_primary_container
                }

                Text {
                    text: Qt.formatDateTime(new Date(), "ddd, MMM d · hh:mm")
                    font.pixelSize: 14
                    color: ColorsModule.Colors.on_primary_container
                    opacity: 0.7
                    font.weight: Font.Medium
                }
            }
        }
    }
}