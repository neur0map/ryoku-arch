import QtQuick
import Quickshell.Io
import "../"
import "../../components"

Item {
    id: root

    readonly property int colW:     166
    readonly property int centerW:  300
    readonly property int railW:    190
    readonly property int gap:        6
    readonly property int profileH: 140
    readonly property int clockH:   188

    property string _avatarPath: ""
    property string _staticJpg:  ""

    Process {
        command: ["bash", "-c", "echo $HOME"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var h = line.trim()
                if (h === "") return
                root._staticJpg  = h + "/.curr_wall_static.jpg"
                root._avatarPath = root._staticJpg
            }
        }
    }

    Connections {
        target: WallpaperService
        function onWallpaperApplied(path) {
            root._avatarPath = ""
            reloadTimer.restart()
        }
    }

    Timer {
        id: reloadTimer
        interval: 0
        repeat:   false
        onTriggered: root._avatarPath = root._staticJpg
    }

    Row {
        id: mainRow
        anchors {
            top:              parent.top
            bottom:           parent.bottom
            topMargin:        root.gap
            horizontalCenter: parent.horizontalCenter
        }
        spacing: root.gap
        width: leftCol.width + centerCol.width + rail.width + root.gap * 2

        Item {
            id: leftCol
            width: root.colW
            height: parent.height

            ProfileCard {
                id: profileCard
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: root.profileH
                avatarPath: root._avatarPath
            }

            CalendarCard {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: profileCard.bottom
                    topMargin: root.gap
                    bottom: parent.bottom
                }
            }
        }

        Item {
            id: centerCol
            width: root.centerW
            height: parent.height

            ClockCard {
                id: clockCard
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: root.clockH
            }

            PlayerCard {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: clockCard.bottom
                    topMargin: root.gap
                    bottom: parent.bottom
                }
            }
        }

        TelemetryRail {
            id: rail
            width:  root.railW
            height: parent.height
        }
    }
}
