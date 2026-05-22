import QtQuick
import Quickshell
import qs.components
import Quickshell.Io
import Quickshell.Wayland
import qs.services as Services

Rectangle {
    id: mediaPanel
    property bool opened: false

    color: "transparent"
    focus: true
    implicitWidth: 520
    property int popoutHeight: 320
    implicitHeight: popoutHeight
    visible: implicitHeight > 1
    y: opened ? 0 : -(popoutHeight + 20)  // Use dynamic height instead of fixed -340
    anchors.horizontalCenter: parent.horizontalCenter

    Behavior on y {
        NumberAnimation {
            duration: 500
            easing.type: Easing.OutCubic
        }
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: mediaPanel.opened = false
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: mediaPanel.opened
        layer.enabled: true
        layer.smooth: true

        Keys.onEscapePressed: {
            mediaPanel.opened = false
        }

        Popout {
            anchors.fill: parent
            alignment: 0
            MediaControl {
                id: panel
                anchors.horizontalCenter: parent.horizontalCenter

                y: opened ? 0 : -implicitHeight - 30

                opened: mediaPanel.opened

                Behavior on y {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutCubic
                    }
                }

                scale: opened ? 1.0 : 0.95

                Behavior on scale {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }
}