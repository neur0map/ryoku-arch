import QtQuick
import "Singletons"

// The machine "screen": a carbon stage with the guest's mark, a soft radial
// glow and slow scanlines that wake when the VM runs (dim and still when off).
// The visual hero of the detail pane, in the same holographic spirit as the
// hub's GpuCard but quieter.
Item {
    id: stage

    property string guest: "linux"
    property string os: ""
    property bool running: false
    property string mode: "gtk"
    property string ssh: ""
    property string spice: ""

    Rectangle {
        anchors.fill: parent
        radius: 14
        clip: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#211912" }
            GradientStop { position: 1.0; color: "#120d09" }
        }
        border.width: 1
        border.color: stage.running ? Qt.alpha(Theme.ember, 0.45) : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.medium } }

        // radial wake glow.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.4
            height: width
            radius: width / 2
            opacity: stage.running ? 0.5 : 0.16
            Behavior on opacity { NumberAnimation { duration: Theme.slow } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Theme.ember, 0.22) }
                GradientStop { position: 0.5; color: "transparent" }
            }
        }

        // grid texture.
        Row {
            anchors.fill: parent
            spacing: 22
            opacity: 0.05
            Repeater {
                model: Math.ceil(stage.width / 22) + 1
                delegate: Rectangle { width: 1; height: stage.height; color: Theme.cream }
            }
        }

        // scanline sweep when running.
        Rectangle {
            id: scan
            visible: stage.running
            width: parent.width
            height: 2
            color: Qt.alpha(Theme.ember, 0.5)
            y: 0
            SequentialAnimation on y {
                running: stage.running
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: stage.height; duration: 2600; easing.type: Easing.InOutSine }
                NumberAnimation { from: stage.height; to: 0; duration: 2600; easing.type: Easing.InOutSine }
            }
        }

        // the mark.
        Column {
            anchors.centerIn: parent
            spacing: 14
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96
                height: 96
                Rectangle {
                    anchors.fill: parent
                    radius: 22
                    color: Qt.alpha(Theme.cream, 0.04)
                    border.width: 1
                    border.color: stage.running ? Qt.alpha(Theme.ember, 0.4) : Theme.line
                    Behavior on border.color { ColorAnimation { duration: Theme.medium } }
                }
                OsIcon {
                    anchors.centerIn: parent
                    width: 56
                    height: 56
                    size: 56
                    slug: stage.os
                    label: stage.os.length > 0 ? stage.os : stage.guest
                    glyphTint: stage.running ? Theme.ember : Theme.subtle
                }
            }
            // a power pulse ring under the mark when running.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: powerRow.implicitWidth + 22
                height: 26
                radius: 13
                color: stage.running ? Qt.alpha(Theme.ok, 0.12) : Qt.alpha(Theme.cream, 0.04)
                border.width: 1
                border.color: stage.running ? Qt.alpha(Theme.ok, 0.5) : Theme.line
                Behavior on color { ColorAnimation { duration: Theme.medium } }
                Behavior on border.color { ColorAnimation { duration: Theme.medium } }
                Row {
                    id: powerRow
                    anchors.centerIn: parent
                    spacing: 7
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7; radius: 3.5
                        color: stage.running ? Theme.ok : Theme.faint
                        SequentialAnimation on opacity {
                            running: stage.running
                            loops: Animation.Infinite
                            NumberAnimation { from: 1; to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.3; to: 1; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: stage.running ? "POWERED ON" : "POWERED OFF"
                        color: stage.running ? Theme.ok : Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.5
                    }
                }
            }
        }

        // live ports footer when running.
        Row {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.margins: 12
            spacing: 14
            visible: stage.running
            Text {
                text: "MODE " + ({ "gtk": "WINDOW", "spice": "SPICE", "none": "HEADLESS" })[stage.mode] || stage.mode
                color: Theme.subtle; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Text {
                visible: stage.spice.length > 0
                text: "SPICE :" + stage.spice
                color: Theme.subtle; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
            Text {
                visible: stage.ssh.length > 0
                text: "SSH :" + stage.ssh
                color: Theme.subtle; font.family: Theme.mono; font.pixelSize: 10; font.letterSpacing: 1
            }
        }
    }
}
