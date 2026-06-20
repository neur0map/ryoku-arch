import QtQuick
import QtQuick.Controls
import "Singletons"

// The live update log: a header (state + progress) over a terminal-style surface
// that streams the run. Each line is coloured by its level (step / info / ok /
// bad). The view sticks to the newest line as the log grows.
Item {
    id: root

    property string phase: "running"   // running | success | failed
    property real progress: 0
    property var logModel: null
    property string targetVersion: ""

    Item {
        id: head
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 40

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Spinner {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.phase === "running"
                size: 18
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.phase === "success"
                name: "check"
                size: 18
                weight: 2.2
                tint: Theme.ok
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.phase === "failed"
                name: "close"
                size: 16
                weight: 2.2
                tint: Theme.bad
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.phase === "running" ? "Applying update"
                    : root.phase === "success" ? "Update complete"
                    : "Update failed"
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 16
                font.weight: Font.DemiBold
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.phase === "running" ? (Math.round(root.progress * 100) + "%")
                : root.phase === "success" ? ("now on " + root.targetVersion)
                : "see log below"
            color: root.phase === "failed" ? Theme.bad : Theme.dim
            font.family: Theme.mono
            font.pixelSize: 12
        }
    }

    WaveMeter {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 4
        height: 12
        visible: root.phase === "running"
        frac: root.progress
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: head.bottom
        anchors.topMargin: 26
        anchors.bottom: parent.bottom
        radius: 12
        color: Theme.surfaceLo
        border.width: 1
        border.color: Theme.line

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 16
            clip: true
            model: root.logModel
            spacing: 3
            boundsBehavior: Flickable.StopAtBounds
            onCountChanged: positionViewAtEnd()

            ScrollBar.vertical: ScrollBar {
                id: sb
                policy: ScrollBar.AsNeeded
                width: 7
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Theme.line
                    opacity: sb.pressed ? 0.9 : (sb.hovered ? 0.7 : 0.4)
                    Behavior on opacity { NumberAnimation { duration: Theme.quick } }
                }
            }

            delegate: Text {
                required property string level
                required property string line
                width: ListView.view.width
                text: line
                color: level === "step" ? Theme.ember
                    : level === "ok" ? Theme.ok
                    : level === "bad" ? Theme.bad
                    : level === "dim" ? Theme.faint
                    : Theme.subtle
                font.family: Theme.mono
                font.pixelSize: 13
                font.weight: level === "step" ? Font.DemiBold : Font.Medium
                wrapMode: Text.NoWrap
                elide: Text.ElideRight
            }
        }
    }
}
