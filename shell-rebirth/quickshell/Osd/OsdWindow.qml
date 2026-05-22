import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services as Services
import "../colors" as ColorsModule
import qs.Core
import QtQuick.Layouts

Item {
    id: root
    visible: Services.Osd.visible
    property var colors: ColorsModule.Colors

    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottomMargin: Services.Osd.visible ? 60 : -implicitHeight

    implicitWidth: 360
    implicitHeight: 100

    Behavior on y {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: colors.surface_container_high
        border.color: colors.outline_variant
        border.width: 1
        opacity: Services.Osd.visible ? 1.0 : 0.0

        layer.enabled: true
        layer.smooth: true

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        Row {
            anchors {
                fill: parent
                margins: 24
            }
            spacing: 20

            // Icon column
            Rectangle {
                width: 52
                height: 52
                radius: 12
                color: colors.primary_container
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    anchors.centerIn: parent
                    text: Services.Osd.type === "volume" ? getVolumeIcon() : Icons.brightness
                    font.pixelSize: 28
                    font.family: "Material Design Icons"
                    color: colors.on_primary_container
                }
            }

            // Content column
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                width: parent.width - 52 - 20

                // Title and percentage row
                Row {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: Services.Osd.type === "volume" ? "Volume" : "Brightness"
                        color: colors.on_surface
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item {
                        width: parent.width - 180
                        height: 1
                    }

                    Text {
                        text: Math.min(Math.round(Services.Osd.value), 100) + "%"
                        color: colors.on_surface_variant
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                // Progress bar
                Rectangle {
                    width: parent.width
                    height: 8
                    radius: 4
                    color: colors.surface_container_highest

                    Rectangle {
                        height: parent.height
                        radius: 4
                        width: parent.width * Math.min(Math.max(Services.Osd.value, 0), 100) / 100
                        color: colors.primary

                        Behavior on width {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Shimmer effect on the fill
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.1) }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                    }
                }
            }
        }
    }

    function getVolumeIcon() {
        let vol = Services.Osd.value
        if (Services.Audio && Services.Audio.muted) return Icons.volumeMuted
        if (vol === 0) return Icons.volumeZero
        if (vol < 33) return Icons.volumeLow
        if (vol < 66) return Icons.volumeMedium
        return Icons.volumeHigh
    }
}