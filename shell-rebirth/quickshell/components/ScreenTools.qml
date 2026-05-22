import QtQuick
import Quickshell.Io
import qs.components
import "../colors" as ColorsModule

Item {
    width: 340
    height: 110
    property var colors: ColorsModule.Colors
    property bool recording: false
    property bool hoveredRecord: false
    property bool hoveredScreenshot: false

    Component.onCompleted: {
        checkRecordingProc.running = true
    }

    Process {
        id: checkRecordingProc
        command: ["pgrep", "-x", "wf-recorder"]

        onExited: (exitCode, exitStatus) => {
            recording = (exitCode === 0)
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        radius: 12
        color: colors.surface_container
        border.color: colors.outline_variant
        border.width: 1

        Rectangle {
            id: recordingIndicator
            visible: recording
            width: 8
            height: 8
            radius: 4
            color: colors.error
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 12

            SequentialAnimation on opacity {
                running: recording
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.2; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.2; to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: recording ? "● Recording" : "Capture"
                color: recording ? colors.error : colors.on_surface_variant
                font.pixelSize: 11
                font.weight: Font.Medium
                opacity: 0.7
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Rectangle {
                    width: 140
                    height: 52
                    radius: 10
                    color: recording
                        ? (hoveredRecord ? Qt.lighter(colors.error_container, 1.15) : colors.error_container)
                        : (hoveredRecord ? Qt.lighter(colors.primary_container, 1.2) : colors.primary_container)
                    border.color: recording ? colors.error : colors.primary
                    border.width: hoveredRecord ? 1.5 : 1

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on border.width { NumberAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    scale: hoveredRecord ? 1.03 : 1.0

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        Rectangle {
                            width: 18
                            height: 18
                            radius: recording ? 3 : 9
                            color: recording ? colors.error : colors.primary
                            anchors.verticalCenter: parent.verticalCenter

                            Behavior on radius { NumberAnimation { duration: 180 } }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: recording ? "Stop" : "Record"
                            color: recording ? colors.on_error_container : colors.on_primary_container
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: hoveredRecord = true
                        onExited: hoveredRecord = false

                        onClicked: {
                            if (!recording) {
                                recordProc.running = true
                                recording = true
                            } else {
                                stopProc.running = true
                                recording = false
                            }
                        }
                    }
                }

                Rectangle {
                    width: 140
                    height: 52
                    radius: 10
                    color: hoveredScreenshot
                        ? Qt.lighter(colors.tertiary_container, 1.2)
                        : colors.tertiary_container
                    border.color: colors.tertiary
                    border.width: hoveredScreenshot ? 1.5 : 1

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on border.width { NumberAnimation { duration: 120 } }
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    scale: hoveredScreenshot ? 1.03 : 1.0

                    Row {
                        anchors.centerIn: parent
                        spacing: 8

                        // Camera icon
                        Item {
                            width: 18
                            height: 18
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                width: 18
                                height: 14
                                radius: 3
                                color: "transparent"
                                border.color: colors.tertiary
                                border.width: 1.5
                                anchors.centerIn: parent

                                Rectangle {
                                    width: 4
                                    height: 4
                                    radius: 2
                                    color: colors.tertiary
                                    anchors.centerIn: parent
                                }

                                Rectangle {
                                    width: 6
                                    height: 3
                                    radius: 1
                                    color: colors.tertiary
                                    anchors.bottom: parent.top
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottomMargin: -1
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Screenshot"
                            color: colors.on_tertiary_container
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: hoveredScreenshot = true
                        onExited: hoveredScreenshot = false

                        onClicked: {
                            screenshotProc.running = true
                            screenshotFlash.opacity = 1.0
                        }
                    }
                }
            }
        }

        Rectangle {
            id: screenshotFlash
            anchors.fill: parent
            radius: 12
            color: "white"
            opacity: 0

            Behavior on opacity {
                SequentialAnimation {
                    NumberAnimation { duration: 80 }
                    PauseAnimation { duration: 40 }
                    NumberAnimation { to: 0; duration: 180 }
                }
            }
        }
    }

    Process {
        id: recordProc
        command: ["sh", "-c", "nohup wf-recorder -f ~/Videos/recordings/recording_$(date +%Y%m%d_%H%M%S).mp4 >/dev/null 2>&1 &"]
    }

    Process {
        id: stopProc
        command: ["pkill", "wf-recorder"]
    }

    Process {
        id: screenshotProc
        command: ["sh", "-c", "qs ipc call systemPanel toggle && grimblast copysave area ~/Pictures/Screenshots/screenshot_$(date +%Y%m%d_%H%M%S).png"]
    }
}