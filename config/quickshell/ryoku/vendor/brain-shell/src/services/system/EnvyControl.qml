import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../"

// Graphics & power status panel.

Column {
    id: root
    spacing: 12
    width: parent.width

    readonly property var  bat:      UPower.displayDevice
    readonly property bool charging: bat.ready
                                     ? (bat.state === UPowerDeviceState.Charging ||
                                        bat.state === UPowerDeviceState.PendingCharge ||
                                        bat.state === UPowerDeviceState.FullyCharged)
                                     : false

    property string powerProfile: charging ? "Performance" : "Powersave"
    property string gfxMode:      "..."
    property bool   dgpuEnabled:  false

    Process {
        id: gfxReader
        command: ["envycontrol", "-q"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var mode = text.trim()
                root.gfxMode     = mode
                root.dgpuEnabled = (mode === "hybrid")
            }
        }
    }

    onVisibleChanged: if (visible) gfxReader.running = true

    // ── Power profile row (read-only) ─────────────────────────────────────────
    Column {
        width: parent.width
        spacing: 4

        Text {
            text:                "Power Profile"
            color:               Qt.rgba(1, 1, 1, 0.4)
            font.pixelSize:      10
            font.capitalization: Font.AllUppercase
            leftPadding:         2
        }

        Rectangle {
            width:  parent.width
            height: 40
            radius: Theme.cornerRadius
            color:  Qt.rgba(1, 1, 1, 0.05)

            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 8

                Text { text: "⚙️"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }

                Text {
                    text:           root.powerProfile.charAt(0).toUpperCase()
                                    + root.powerProfile.slice(1)
                    color:          Theme.text
                    font.pixelSize: 13
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                text:    "🔒"
                font.pixelSize: 12
                opacity: 0.4
            }
        }
    }

    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

    // ── dGPU toggle row ───────────────────────────────────────────────────────
    Column {
        width: parent.width
        spacing: 4

        Text {
            text:                "Graphics"
            color:               Qt.rgba(1, 1, 1, 0.4)
            font.pixelSize:      10
            font.capitalization: Font.AllUppercase
            leftPadding:         2
        }

        Rectangle {
            width:  parent.width
            height: 48
            radius: Theme.cornerRadius
            color:  Qt.rgba(1, 1, 1, 0.05)

            Row {
                anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                spacing: 8

                Text {
                    text:           root.dgpuEnabled ? "🖥️" : "💻"
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text:           root.dgpuEnabled ? "Hybrid" : "Integrated"
                        color:          Theme.text
                        font.pixelSize: 13
                        font.bold:      true
                    }

                    Text {
                        text:           root.dgpuEnabled ? "dGPU active" : "dGPU inactive"
                        color:          Qt.rgba(1, 1, 1, 0.45)
                        font.pixelSize: 10
                    }
                }
            }

            // Toggle switch
            Rectangle {
                id: toggle
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width:  44
                height: 24
                radius: 12
                color:  root.dgpuEnabled ? Theme.active : Qt.rgba(1, 1, 1, 0.15)
                Behavior on color { ColorAnimation { duration: 150 } }

                Rectangle {
                    width:  18; height: 18; radius: 9
                    color:  "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.dgpuEnabled ? parent.width - width - 3 : 3
                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                HoverHandler { cursorShape: Qt.PointingHandCursor }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // Display label is capitalised; CLI arg must be lowercase
                        var displayMode = root.dgpuEnabled ? "Integrated" : "Hybrid"
                        var cliMode     = displayMode.toLowerCase()
                        Popups.showConfirm(
                            "Switch Graphics Mode",
                            "Switching to <b>" + displayMode + "</b> mode requires saving your "
                            + "work and rebooting. Your system will restart immediately after "
                            + "the change is applied.",
                            "Switch & Reboot",
                            "gfx-switch",
                            cliMode
                        )
                    }
                }
            }
        }
    }
}
