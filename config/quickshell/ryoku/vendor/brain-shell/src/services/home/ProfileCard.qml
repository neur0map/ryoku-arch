import QtQuick
import QtQuick.Effects
import Quickshell.Io
import "../../"
import "../../components"

// Profile card — circular avatar, username, window manager, uptime.

StatCard {
    id: root
    padding: 0

    property string avatarPath: ""
    readonly property bool compact: root.width <= 170
    readonly property int sideMargin: root.compact ? 14 : 16
    readonly property int rowSpacing: root.compact ? 12 : 18
    readonly property int avatarSize: root.compact ? 60 : 72
    readonly property int textSpacing: root.compact ? 8 : 10
    readonly property int nameSize: root.compact ? 15 : 17
    readonly property int metaSize: root.compact ? 11 : 12

    property string _user:   ""
    property string _wm:     ""
    property string _uptime: ""

    Process {
        command: ["bash", "-c", "echo $USER"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "") root._user = line.trim()
            }
        }
    }

    Process {
        command: ["bash", "-c", "echo ${XDG_CURRENT_DESKTOP:-Hyprland}"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "") root._wm = line.trim()
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["bash", "-c",
            "uptime -p | sed 's/up //' | sed 's/ hours\\?/h/' | " +
            "sed 's/ minutes\\?/m/' | sed 's/ days\\?/d/' | sed 's/, / /g'"]
        running: false
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() !== "") root._uptime = line.trim()
            }
        }
    }

    Timer {
        interval: 60000; running: true; repeat: true
        onTriggered: { uptimeProc.running = false; uptimeProc.running = true }
    }

    Component.onCompleted: uptimeProc.running = true

    Row {
        anchors {
            left:           parent.left;  leftMargin:  root.sideMargin
            right:          parent.right; rightMargin: root.sideMargin
            verticalCenter: parent.verticalCenter
        }
        spacing: root.rowSpacing

        // Circular avatar
        Item {
            width: root.avatarSize; height: root.avatarSize
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(166/255,208/255,247/255,0.22) }
                    GradientStop { position: 1.0; color: Qt.rgba(80/255,130/255,190/255,0.14) }
                }
                border.color: Qt.rgba(166/255,208/255,247/255,0.22)
                border.width: 1
            }

            Rectangle {
                id: photoMask
                anchors.fill: parent
                radius: width / 2
                visible: false
                layer.enabled: true
            }

            Image {
                anchors.fill: parent
                source:   root.avatarPath !== "" ? ("file://" + root.avatarPath) : ""
                fillMode: Image.PreserveAspectCrop
                smooth:   true
                visible:  root.avatarPath !== ""
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled:      true
                    maskSource:       photoMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin:  1.0
                }
            }

            Text {
                anchors.centerIn: parent
                text:           "󰀄"
                font.pixelSize: root.compact ? 24 : 28
                color:          Theme.active
                visible:        root.avatarPath === ""
            }
        }

        // Text stats
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - root.avatarSize - root.rowSpacing)
            spacing: root.textSpacing

            Text {
                width:          parent.width
                text:           root._user
                font.pixelSize: root.nameSize; font.weight: Font.DemiBold
                color:          Theme.active
                elide:          Text.ElideRight
            }

            Row {
                width: parent.width
                spacing: root.compact ? 6 : 8
                Text {
                    id: wmIcon
                    text: "󰣇"; font.pixelSize: root.metaSize; color: Theme.active
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    width: parent.width - wmIcon.width - parent.spacing
                    text: root._wm; font.pixelSize: root.metaSize
                    color: Qt.rgba(205/255,214/255,244/255,0.55)
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                }
            }

            Row {
                width: parent.width
                spacing: root.compact ? 6 : 8
                Text {
                    id: uptimeIcon
                    text: "󰔚"; font.pixelSize: root.metaSize; color: Theme.active
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    width: parent.width - uptimeIcon.width - parent.spacing
                    text: root._uptime; font.pixelSize: root.metaSize
                    font.family: "JetBrains Mono"
                    color: Qt.rgba(205/255,214/255,244/255,0.55)
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
