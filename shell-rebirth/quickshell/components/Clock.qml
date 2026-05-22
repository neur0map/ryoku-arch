import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../colors" as ColorsModule
import qs.services as Services
import Quickshell.Io


Rectangle {
    id: root

    property bool showSeconds: true
    property bool smoothTransition: true

    /* ---------- sizing ---------- */
    width: 200
    height: width
    radius: width / 2

    /* ---------- matugen colors ---------- */
    color: ColorsModule.Colors.surface_container
    border.color: ColorsModule.Colors.outline_variant
    border.width: 2

    /* ---------- time tracking for smooth updates ---------- */
    QtObject {
        id: timeTracker
        property date currentTime: new Date()
    }

    Timer {
        interval: 100  // Update every 100ms for smooth second hand
        running: true
        repeat: true
        onTriggered: {
            timeTracker.currentTime = new Date()
        }
    }

    /* ---------- helper functions for angle calculations ---------- */
    function getHourAngle() {
        var hours = timeTracker.currentTime.getHours() % 12
        var minutes = timeTracker.currentTime.getMinutes()
        var seconds = timeTracker.currentTime.getSeconds()
        return (hours + minutes / 60 + seconds / 3600) * 30
    }

    function getMinuteAngle() {
        var minutes = timeTracker.currentTime.getMinutes()
        var seconds = timeTracker.currentTime.getSeconds()
        return (minutes + seconds / 60) * 6
    }

    function getSecondAngle() {
        var seconds = timeTracker.currentTime.getSeconds()
        var milliseconds = timeTracker.currentTime.getMilliseconds()
        return (seconds + milliseconds / 1000) * 6
    }

    /* ---------- clock face ---------- */
    Item {
        anchors.fill: parent
        anchors.margins: 20

        // Hour markers with improved design
        Repeater {
            model: 12

            Rectangle {
                width: index % 3 === 0 ? 4 : 2
                height: index % 3 === 0 ? 16 : 10
                color: index % 3 === 0 ? ColorsModule.Colors.primary : ColorsModule.Colors.on_surface_variant
                opacity: index % 3 === 0 ? 1.0 : 0.7
                radius: width / 2
                layer.enabled: true
                layer.samples: 4

                x: parent.width / 2 - width / 2
                y: 0

                transform: Rotation {
                    origin.x: width / 2
                    origin.y: parent.height / 2
                    angle: index * 30
                }

                // Small glow effect for primary markers
                Rectangle {
                    width: parent.width + 2
                    height: parent.height + 2
                    radius: width / 2
                    color: "transparent"
                    border.color: ColorsModule.Colors.primary
                    border.width: 1
                    opacity: parent.opacity * 0.3
                    anchors.centerIn: parent
                    visible: index % 3 === 0
                }
            }
        }

        // Minute markers (small dots between hour markers)
        Repeater {
            model: 60
            Rectangle {
                width: 2
                height: 4
                color: ColorsModule.Colors.on_surface_variant
                opacity: 0.3
                radius: width / 2
                visible: index % 5 !== 0  // Don't show where hour markers are

                x: parent.width / 2 - width / 2
                y: 6

                transform: Rotation {
                    origin.x: width / 2
                    origin.y: parent.height / 2 - 6
                    angle: index * 6
                }
            }
        }

        // Hour hand with improved design
        Rectangle {
            id: hourHand
            width: 6
            height: parent.height * 0.3
            color: ColorsModule.Colors.primary
            radius: width / 2
            antialiasing: true
            layer.enabled: true
            layer.samples: 4

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: -8

            // Gradient effect
            gradient: Gradient {
                GradientStop { position: 0.0; color: ColorsModule.Colors.primary }
                GradientStop { position: 0.8; color: Qt.darker(ColorsModule.Colors.primary, 1.2) }
            }

            transform: Rotation {
                id: hourRotation
                origin.x: hourHand.width / 2
                origin.y: hourHand.height + 8
                angle: getHourAngle()

                Behavior on angle {
                    enabled: root.smoothTransition
                    SpringAnimation { spring: 2; damping: 0.2; modulus: 360 }
                }
            }
        }

        // Minute hand with improved design
        Rectangle {
            id: minuteHand
            width: 4
            height: parent.height * 0.4
            color: ColorsModule.Colors.primary
            radius: width / 2
            antialiasing: true
            layer.enabled: true
            layer.samples: 4

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: -8

            // Gradient effect
            gradient: Gradient {
                GradientStop { position: 0.0; color: ColorsModule.Colors.primary }
                GradientStop { position: 0.8; color: Qt.darker(ColorsModule.Colors.primary, 1.1) }
            }

            transform: Rotation {
                id: minuteRotation
                origin.x: minuteHand.width / 2
                origin.y: minuteHand.height + 8
                angle: getMinuteAngle()

                Behavior on angle {
                    enabled: root.smoothTransition
                    SpringAnimation { spring: 3; damping: 0.2; modulus: 360 }
                }
            }
        }

        // Second hand with improved design
        Rectangle {
            id: secondHand
            width: 2
            height: parent.height * 0.45
            color: ColorsModule.Colors.tertiary
            radius: width / 2
            antialiasing: true
            visible: root.showSeconds
            layer.enabled: true
            layer.samples: 4

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.verticalCenter
            anchors.bottomMargin: -8

            // Small circle at the end of second hand
            Rectangle {
                width: 6
                height: 6
                radius: width / 2
                color: ColorsModule.Colors.tertiary
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: -3
            }

            transform: Rotation {
                id: secondRotation
                origin.x: secondHand.width / 2
                origin.y: secondHand.height + 8
                angle: getSecondAngle()

                Behavior on angle {
                    enabled: root.smoothTransition
                    SpringAnimation { spring: 4; damping: 0.15; modulus: 360 }
                }
            }
        }

        // Center dot with improved design
        Rectangle {
            width: 16
            height: 16
            radius: width / 2
            color: ColorsModule.Colors.primary
            anchors.centerIn: parent
            layer.enabled: true
            layer.samples: 4

            // Inner dot
            Rectangle {
                width: 8
                height: 8
                radius: width / 2
                color: ColorsModule.Colors.surface_container
                anchors.centerIn: parent
            }

            // Outer glow
            Rectangle {
                width: parent.width + 4
                height: parent.height + 4
                radius: width / 2
                color: "transparent"
                border.color: ColorsModule.Colors.primary
                border.width: 1
                opacity: 0.3
                anchors.centerIn: parent
            }
        }

        // Digital time display
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            color: ColorsModule.Colors.surface_container
            radius: 12
            height: 24
            width: digitalTime.width + 16

            Text {
                id: digitalTime
                text: {
                    var hours = timeTracker.currentTime.getHours()
                    var minutes = timeTracker.currentTime.getMinutes()
                    var ampm = hours >= 12 ? "PM" : "AM"
                    hours = hours % 12
                    hours = hours ? hours : 12 // 12-hour format
                    return hours + ":" + (minutes < 10 ? "0" + minutes : minutes) + " " + ampm
                }
                color: ColorsModule.Colors.on_surface
                font.pixelSize: 12
                font.bold: true
                anchors.centerIn: parent
            }

        }
    }

    /* ---------- subtle material look ---------- */
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.color: ColorsModule.Colors.surface_tint
        border.width: 1
        opacity: 0.08
    }

}