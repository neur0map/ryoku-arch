import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.components
import "../colors" as ColorsModule

Popout {
    id: root
    alignment: 3
    property bool opened: false
    visible: true
    property int currentTab: 0
    focus: true

    property int headerHeight: 48
    property color backgroundColor: ColorsModule.Colors.surface
    property color surfaceColor: ColorsModule.Colors.surface_container_highest
    property color accentColor: ColorsModule.Colors.primary
    property color textColor: ColorsModule.Colors.on_surface
    property color closeButtonColor: ColorsModule.Colors.error
    property color closeButtonHoverColor: ColorsModule.Colors.error_container

    implicitHeight: 500
    implicitWidth: opened ? 850 : 0

    opacity: 1

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundColor
        radius: 12

        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 16

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.headerHeight
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        TabButton {
                            text: "GitHub"
                            active: currentTab === 0
                            onClicked: currentTab = 0
                        }

                        TabButton {
                            text: "Timer"
                            active: currentTab === 1
                            onClicked: currentTab = 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            id: closeButton
                            implicitWidth: 32
                            implicitHeight: 32
                            radius: 16
                            color: closeMouseArea.containsMouse ? root.closeButtonHoverColor : "transparent"

                            Behavior on color {
                                ColorAnimation { duration: 150 }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                color: closeMouseArea.containsMouse ?
                                    ColorsModule.Colors.on_error_container :
                                    root.closeButtonColor
                                font.pixelSize: 16
                                font.bold: true
                            }

                            MouseArea {
                                id: closeMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.opened = false
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.surfaceColor
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 8

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    sourceComponent: currentTab === 0 ? ghCalendar : timerComponent

                    opacity: 1
                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }
            }
        }
    }

    Component {
        id: ghCalendar
        GhCalendar {}
    }

    Component {
        id: timerComponent
        TimerComponent {}
    }

    Timer {
        running: root.autoHide && root.opened
        interval: root.hideDelay
        onTriggered: root.opened = false
    }
}