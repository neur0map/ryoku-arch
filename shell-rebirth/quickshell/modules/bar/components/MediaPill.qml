import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services
import Quickshell.Io
import "../../../colors" as ColorsModule
import qs.components

Item {
    id: root

    implicitHeight: 32

    property int maxWidth: 200

    property var media: Media
    visible: media.activePlayer !== null

    implicitWidth: Math.min(pill.implicitWidth, maxWidth)

    Rectangle {
        id: pill
        anchors.fill: parent

        radius: height / 2
        height: 32
        color: ColorsModule.Colors.background

        clip: true

        implicitWidth: row.implicitWidth + 20

        RowLayout {
            id: row

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 10
                rightMargin: 10
            }

            spacing: 8
            z: 1

            Item {
                Layout.fillWidth: true
                Layout.preferredWidth: root.maxWidth - 20
                Layout.preferredHeight: mediaText.height
                clip: true

                Row {
                    id: marqueeRow
                    spacing: 50

                    Text {
                        id: mediaText
                        text: media.artist
                            ? media.title + " — " + media.artist
                            : media.title

                        color: ColorsModule.Colors.on_surface
                        font.pixelSize: 17
                    }

                    Text {
                        visible: mouseArea.containsMouse
                        text: mediaText.text
                        color: ColorsModule.Colors.on_surface
                        font.pixelSize: 17
                    }

                    SequentialAnimation {
                        id: marqueeAnimation
                        running: mouseArea.containsMouse
                        loops: Animation.Infinite

                        PauseAnimation { duration: 2000 }

                        NumberAnimation {
                            target: marqueeRow
                            property: "x"
                            from: 0
                            to: -(mediaText.implicitWidth + marqueeRow.spacing)
                            duration: (mediaText.implicitWidth + marqueeRow.spacing) * 20
                            easing.type: Easing.Linear
                        }

                        PropertyAction {
                            target: marqueeRow
                            property: "x"
                            value: 0
                        }
                    }

                    // Reset position when mouse leaves
                    Behavior on x {
                        enabled: !mouseArea.containsMouse
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }

        MouseArea {
            id: mouseArea
            onClicked: toggleProc.running = true
            onExited: marqueeRow.x = 0  // Reset position when mouse leaves
            anchors.fill: parent
            z: 2
            hoverEnabled: true
        }
    }

    Process {
        id: toggleProc
        command: ["qs", "ipc", "call", "mediaPanel", "toggle"]
    }
}