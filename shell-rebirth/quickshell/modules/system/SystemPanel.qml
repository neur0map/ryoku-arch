import QtQuick
import Quickshell
import qs.components
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: systemPanel
    property bool opened: false
    property int currentTab: 0
    focus: true
    implicitWidth: 550
    implicitHeight: opened ? 200 : 0
    anchors.horizontalCenter: parent.horizontalCenter

    Behavior on implicitHeight {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        MouseArea {
            anchors.fill: parent
            onClicked: systemPanel.opened = false
        }
    }

    FocusScope {
        anchors.fill: parent
        focus: systemPanel.opened

        Keys.onEscapePressed: systemPanel.opened = false

        Popout {
            anchors.fill: parent
            alignment: 0

            Column {
                anchors.fill: parent
                spacing: 8

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    TabButton {
                        text: "System"
                        active: currentTab === 0
                        onClicked: currentTab = 0
                    }

                    TabButton {
                        text: "Screen"
                        active: currentTab === 1
                        onClicked: currentTab = 1
                    }
                }

                Loader {
                    anchors.horizontalCenter: parent.horizontalCenter
                    sourceComponent: currentTab === 0 ? systemTab : screenTab
                }
            }
        }
    }

    Component {
        id: systemTab
        SystemGraphs { }
    }

    Component {
        id: screenTab
        ScreenTools { }
    }

    IpcHandler {
        target: "systemPanel"
        function toggle(): void {
            systemPanel.opened = !systemPanel.opened
        }
    }
}
