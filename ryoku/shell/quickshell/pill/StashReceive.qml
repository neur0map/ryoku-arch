pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * The LocalSend receive sheet. While it is up the shell runs a LocalSend server
 * that announces itself on the LAN and drops anything pushed to it straight into
 * the stash. It shows the name other devices will see, a live tally of what has
 * arrived, and a Stop. The server and all of its state live in the Stash
 * singleton; this only renders the waiting room.
 */
Rectangle {
    id: root

    property real s: 1

    readonly property bool active: Stash.recvState !== "idle"

    radius: Motion.rTile * s
    color: Qt.alpha(Theme.cardTop, 0.98)
    visible: active

    MouseArea { anchors.fill: parent; hoverEnabled: true }

    SheetBack {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 12 * root.s
        anchors.leftMargin: 14 * root.s
        s: root.s
        onBack: Stash.stopReceive()
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -8 * root.s
        width: parent.width - 48 * root.s
        spacing: 14 * root.s

        // Broadcasting halo around the receive glyph.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64 * root.s
            height: 64 * root.s

            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: 28 * root.s
                    height: 28 * root.s
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.5 * root.s
                    border.color: Theme.flameGlow
                    SequentialAnimation on opacity {
                        running: root.active
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 700 }
                        NumberAnimation { from: 0.5; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: (1 - index) * 700 }
                    }
                    SequentialAnimation on scale {
                        running: root.active
                        loops: Animation.Infinite
                        PauseAnimation { duration: index * 700 }
                        NumberAnimation { from: 0.7; to: 2.2; duration: 1400; easing.type: Easing.OutCubic }
                        PauseAnimation { duration: (1 - index) * 700 }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: 44 * root.s
                height: 44 * root.s
                radius: width / 2
                color: Qt.alpha(Theme.flameGlow, 0.14)
                border.width: 1
                border.color: Qt.alpha(Theme.flameGlow, 0.5)

                GlyphIcon {
                    anchors.centerIn: parent
                    width: 22 * root.s; height: 22 * root.s
                    name: "hotspot"
                    color: Theme.flameGlow
                    stroke: 1.7
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 3 * root.s

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Listening as " + (Stash.recvAlias.length > 0 ? Stash.recvAlias : "Ryoku Stash")
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12 * root.s
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Stash.recvCount > 0
                    ? ("Received " + Stash.recvCount + (Stash.recvCount === 1 ? " file" : " files"))
                    : "Other devices can send files here"
                color: Stash.recvCount > 0 ? Theme.flameGlow : Theme.subtle
                font.family: Theme.font
                font.pixelSize: 9.5 * root.s
                font.weight: Font.Medium
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Stash.recvLast.length > 0
                text: "↓ " + Stash.recvLast
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 9 * root.s
                elide: Text.ElideMiddle
                width: root.width - 60 * root.s
                horizontalAlignment: Text.AlignHCenter
                maximumLineCount: 1
                textFormat: Text.PlainText
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: stopRow.implicitWidth + 28 * root.s
            height: 30 * root.s
            radius: Motion.rSmall * root.s
            color: stopArea.containsMouse ? Theme.frameBg : Theme.tileBg
            border.width: 1
            border.color: stopArea.containsMouse ? Theme.frameBorder : Theme.border
            Behavior on color { ColorAnimation { duration: Motion.fast } }

            Row {
                id: stopRow
                anchors.centerIn: parent
                spacing: 6 * root.s
                GlyphIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 12 * root.s; height: 12 * root.s
                    name: "close"
                    color: stopArea.containsMouse ? Theme.cream : Theme.iconDim
                    stroke: 1.7
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Stop listening"
                    color: stopArea.containsMouse ? Theme.cream : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10.5 * root.s
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: stopArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Stash.stopReceive()
            }
        }
    }
}
