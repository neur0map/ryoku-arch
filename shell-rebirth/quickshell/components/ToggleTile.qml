import QtQuick
import QtQuick.Layouts
import "../colors" as ColorsModule

Rectangle {
        required property string label
        required property string icon
        required property bool active
        signal clicked

        Layout.fillWidth: true
        Layout.preferredHeight: 82
        radius: 16

        color: active
            ? ColorsModule.Colors.primary_container
            : ColorsModule.Colors.surface_container_high


        border.width: active ? 0 : 1
        border.color: active
            ? "transparent"
            : ColorsModule.Colors.outline_variant

        layer.enabled: active

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 40
                height: 40
                radius: 20
                color: active
                    ? ColorsModule.Colors.primary_container
                    : ColorsModule.Colors.surface_container_high

                Text {
                    anchors.centerIn: parent
                    text: icon
                    font.family: "Material Design Icons"
                    font.pixelSize: 24
                    color: active
                        ? Qt.rgba(1, 1, 1, 1)  // White icon when active
                        : ColorsModule.Colors.on_surface_variant
                }

                Behavior on color {
                    ColorAnimation { duration: 200 }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: label
                font.pixelSize: 12
                font.weight: Font.Medium
                color: active
                    ? Qt.rgba(1, 1, 1, 0.95)  // White text when active
                    : ColorsModule.Colors.on_surface_variant
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: parent.clicked()

            onEntered: parent.scale = 0.96
            onExited: parent.scale = 1.0
        }

        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }

        Behavior on color {
            ColorAnimation { duration: 200 }
        }

        Behavior on border.color {
            ColorAnimation { duration: 200 }
        }
    }