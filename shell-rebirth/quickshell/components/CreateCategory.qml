import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services as Services
import "../colors" as ColorsModule

Dialog {
    id: categoryDialog
    title: "Create New Category"
    modal: true

    x: (root.width - width) / 2
    y: (root.height - height) / 2
    width: 400
    height: 220
    parent: root

    background: Rectangle {
        radius: 28
        color: ColorsModule.Colors.surface_container_lowest
        border.color: ColorsModule.Colors.outline_variant
        border.width: 1

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(151, 204, 249, 0.1)
        }
    }

    header: Rectangle {
        height: 64
        radius: 28
        color: ColorsModule.Colors.surface_container_lowest

        Rectangle {
            width: 48
            height: 4
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            radius: 2
            color: ColorsModule.Colors.outline_variant
            opacity: 0.3
        }

        Text {
            anchors.centerIn: parent
            text: categoryDialog.title
            font.pixelSize: 20
            font.weight: Font.Bold
            color: ColorsModule.Colors.on_surface
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        TextField {
            id: categoryInput
            Layout.fillWidth: true
            placeholderText: "Enter category name..."
            font.pixelSize: 14
            focus: true
            color: ColorsModule.Colors.on_surface
            placeholderTextColor: ColorsModule.Colors.on_surface_variant

            background: Rectangle {
                radius: 14
                color: ColorsModule.Colors.surface_container_high
                border.color: categoryInput.activeFocus
                    ? ColorsModule.Colors.primary
                    : ColorsModule.Colors.outline_variant
                border.width: 2
            }

            onAccepted: {
                if (text.trim().length > 0) {
                    Services.Notes.addCategory(text.trim())
                    categoryDialog.close()
                    text = ""
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Button {
                text: "Cancel"
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                background: Rectangle {
                    radius: 14
                    color: parent.hovered
                        ? ColorsModule.Colors.surface_container_high
                        : "transparent"
                    border.width: 1
                    border.color: ColorsModule.Colors.outline_variant
                }

                contentItem: Text {
                    text: parent.text
                    color: ColorsModule.Colors.on_surface
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    categoryDialog.close()
                    categoryInput.text = ""
                }
            }

            Button {
                text: "Create"
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                enabled: categoryInput.text.trim().length > 0

                background: Rectangle {
                    radius: 14
                    color: parent.hovered && parent.enabled
                        ? Qt.darker(ColorsModule.Colors.primary_container, 1.2)
                        : ColorsModule.Colors.primary_container
                    border.width: 2
                    border.color: ColorsModule.Colors.primary
                    opacity: 0.3
                }

                contentItem: Text {
                    text: parent.text
                    color: ColorsModule.Colors.on_primary_container
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    if (categoryInput.text.trim().length > 0) {
                        Services.Notes.addCategory(categoryInput.text.trim())
                        categoryDialog.close()
                        categoryInput.text = ""
                    }
                }
            }
        }
    }
}