pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Progress overlay for the stash rail's install / compress / download actions.
 * It covers the grid while Stash.task runs, spins through the work, then shows
 * the helper's final line as the result until dismissed. Pure status; the heavy
 * lifting lives in the helper scripts behind the Stash singleton.
 */
Rectangle {
    id: root

    property real s: 1

    readonly property bool running: Stash.taskState === "running"
    readonly property bool ok: Stash.taskState === "done"

    readonly property string title: Stash.task === "install" ? "Install"
        : Stash.task === "compress" ? "Compress"
        : Stash.task === "download" ? "Download" : ""

    radius: Motion.rTile * s
    color: Qt.alpha(Theme.cardTop, 0.97)
    visible: Stash.task !== "" && Stash.taskState !== "idle"

    // Absorb clicks/hover so the grid beneath stays inert.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 44 * root.s
        spacing: 12 * root.s

        // Orbiting dot while running; a status ring once finished.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 30 * root.s
            height: 30 * root.s

            Item {
                anchors.fill: parent
                visible: root.running

                Rectangle {
                    width: 6 * root.s
                    height: 6 * root.s
                    radius: width / 2
                    color: Theme.flameGlow
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                }

                RotationAnimation on rotation {
                    running: root.running
                    from: 0
                    to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }

            Rectangle {
                anchors.centerIn: parent
                visible: !root.running
                width: 26 * root.s
                height: 26 * root.s
                radius: width / 2
                color: "transparent"
                border.width: 2 * root.s
                border.color: root.ok ? Theme.flameGlow : Theme.vermLit

                Text {
                    anchors.centerIn: parent
                    text: root.ok ? "✓" : "✕"
                    color: root.ok ? Theme.flameGlow : Theme.vermLit
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.Bold
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.running ? (root.title + "…") : root.title
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.DemiBold
        }

        Text {
            width: parent.width
            visible: !root.running && Stash.taskMsg.length > 0
            text: Stash.taskMsg
            color: Theme.subtle
            font.family: Theme.font
            font.pixelSize: 10 * root.s
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !root.running
            width: 84 * root.s
            height: 26 * root.s
            radius: Motion.rSmall * root.s
            color: doneArea.containsMouse ? Theme.frameBg : Theme.tileBg
            border.width: 1
            border.color: doneArea.containsMouse ? Theme.frameBorder : Theme.border

            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Text {
                anchors.centerIn: parent
                text: "Done"
                color: doneArea.containsMouse ? Theme.cream : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
            }

            MouseArea {
                id: doneArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Stash.dismissTask()
            }
        }
    }
}
