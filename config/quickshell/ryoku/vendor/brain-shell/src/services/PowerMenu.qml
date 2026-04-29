import QtQuick
import Quickshell.Io
import "../"

// Power menu — vertical list of power action buttons.

Column {
    id: root
    spacing: 4
    width: parent.width

    readonly property var actions: [
        {
            label:   "Shutdown",
            icon:    "⏻",
            danger:  true,
            confirm: true,
            title:   "Shut Down?",
            message: "Your computer will power off. Save your work before continuing.",
            label2:  "Shut Down",
            action:  "shutdown"
        },
        {
            label:   "Reboot     ",
            icon:    "↺",
            danger:  true,
            confirm: true,
            title:   "Reboot?",
            message: "Your computer will restart. Save your work before continuing.",
            label2:  "Reboot",
            action:  "reboot"
        },
        {
            label:   "Log Out  ",
            icon:    "󰍃",
            danger:  true,
            confirm: true,
            title:   "Log Out?",
            message: "You will be logged out of your session. Save your work before continuing.",
            label2:  "Log Out",
            action:  "logout" 
        },
        {
            label:   "Lock        ",
            icon:    "󰌾",
            danger:  false,
            confirm: false,
            action:  "lock"
        },
        {
            label:   "Suspend ",
            icon:    "⏾",
            danger:  false,
            confirm: false,
            action:  "suspend"
        },
    ]

    // Direct runner for non-confirm actions
    Process {
        id: runner
        property var pendingCmd: []
        command: pendingCmd
        onRunningChanged: if (!running) pendingCmd = []
    }

    function runDirect(action) {
        switch (action) {
            case "lock":    runner.pendingCmd = ["loginctl", "lock-session"];    break
            case "suspend": runner.pendingCmd = ["systemctl", "suspend"];        break
        }
        runner.running = true
        Popups.archMenuOpen = false
    }

    Repeater {
        model: root.actions

        delegate: Rectangle {
            width:  root.width
            height: 44
            radius: Theme.cornerRadius
            color:  hov.hovered
                        ? (modelData.danger ? "#4d2020" : Theme.active)
                        : "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }

            Row {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text:           modelData.icon
                    font.pixelSize: 16
                    color:          modelData.danger && hov.hovered ? "#ff6b6b" : hov.hovered?"#000000":Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text:           modelData.label
                    font.pixelSize: 13
                    color:          modelData.danger && hov.hovered ? "#ff6b6b" : hov.hovered?"#000000":Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (modelData.confirm) {
                        // Close menu first, then show confirm dialog
                        Popups.closeAll()
                        Popups.showConfirm(
                            modelData.title,
                            modelData.message,
                            modelData.label2,
                            modelData.action
                        )
                    } else {
                        root.runDirect(modelData.action)
                    }
                }
            }
        }
    }
}
