import QtQuick
import QtQuick.Layouts
import "../colors" as ColorsModule

ColumnLayout {
    required property string label
    required property real value
    required property string icon
    property real maxValue: 100
    property string suffix: "%"

    Layout.fillWidth: true
    spacing: 10

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: 8
            color: value > 80
                ? Qt.rgba(239/255, 83/255, 80/255, 0.2)
                : value > 60
                    ? Qt.rgba(255/255, 167/255, 38/255, 0.2)
                    : Qt.rgba(ColorsModule.Colors.primary.r, ColorsModule.Colors.primary.g, ColorsModule.Colors.primary.b, 0.2)

            Text {
                anchors.centerIn: parent
                text: icon
                font.family: "Material Design Icons"
                font.pixelSize: 18
                color: value > 80
                    ? "#ef5350"
                    : value > 60
                        ? "#ffa726"
                        : ColorsModule.Colors.primary
            }

            Behavior on color {
                ColorAnimation { duration: 300 }
            }
        }

        Text {
            Layout.fillWidth: true
            text: label
            color: ColorsModule.Colors.on_surface
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        Text {
            text: Math.round(value) + suffix
            color: value > 80
                ? "#ef5350"
                : value > 60
                    ? "#ffa726"
                    : ColorsModule.Colors.primary
            font.pixelSize: 15
            font.weight: Font.Bold
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 8
        radius: 4
        color: ColorsModule.Colors.surface_container_high

        Rectangle {
            width: Math.min(parent.width * (value/maxValue), parent.width)
            height: parent.height
            radius: 4

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: value > 80
                        ? "#ef5350"
                        : value > 60
                            ? "#ffa726"
                            : ColorsModule.Colors.primary
                }
                GradientStop {
                    position: 1.0
                    color: value > 80
                        ? "#e53935"
                        : value > 60
                            ? "#ff9800"
                            : ColorsModule.Colors.secondary
                }
            }

            Behavior on width {
                NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
            }
        }
    }
}