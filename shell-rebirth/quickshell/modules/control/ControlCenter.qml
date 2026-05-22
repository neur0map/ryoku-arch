import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.services as Services
import "../../colors" as ColorsModule
import qs.components
import qs.modules.control

Item {
    id: controlCenter
    anchors.fill: parent
    visible: false

    property bool opened: false
    property int controlCenterWidth: 450

    function run(cmd) { proc.exec(cmd) }

    onOpenedChanged: {
        if (opened) {
            visible = true
            panel.x = -panel.width
            scrim.opacity = 0
            openAnim.restart()
        } else {
            closeAnim.restart()
        }
    }

    function close() {
        opened = false
    }

    Process { id: proc }

    // ── Scrim ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: ColorsModule.Colors.scrim
        opacity: 0
        enabled: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        MouseArea {
            anchors.fill: parent
            enabled: parent.enabled
            onClicked: controlCenter.close()
        }
    }

    // ── Panel ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: panel
        width: controlCenterWidth
        height: parent.height
        x: -width

        color: ColorsModule.Colors.surface_container_low
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.15) }
            }
        }

        Rectangle {
            width: 3
            height: parent.height
            anchors.left: parent.left
            gradient: Gradient {
                GradientStop { position: 0.0; color: ColorsModule.Colors.primary }
                GradientStop { position: 0.5; color: ColorsModule.Colors.secondary }
                GradientStop { position: 1.0; color: ColorsModule.Colors.tertiary }
            }
        }

        FocusScope {
            anchors.fill: parent
            focus: controlCenter.opened
            Keys.onEscapePressed: controlCenter.close()

            Flickable {
                id: flickable
                anchors.fill: parent
                contentHeight: mainColumn.height + 30
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: mainColumn
                    width: parent.width
                    spacing: 0

                    Header { }

                    QuickSettings { }

                    SliderSection { }

                    SinkSelector {
                        anchors.left: parent.left
                        anchors.right: parent.right
                    }

                    StatsSection { }

                    InfoSection { }

                    Notifications { }

                    PowerSection { }
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: 6
                width: 5
                radius: 2.5
                color: ColorsModule.Colors.surface_container_high
                opacity: flickable.moving ? 0.4 : 0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                Rectangle {
                    width: parent.width
                    height: Math.max(30, (flickable.height / flickable.contentHeight) * parent.height)
                    y: (flickable.contentY / flickable.contentHeight) * parent.height
                    radius: 2.5
                    color: ColorsModule.Colors.primary
                    opacity: 0.8
                    Behavior on y { NumberAnimation { duration: 100 } }
                }
            }
        }
    }

    // ── Animations ────────────────────────────────────────────────────────────

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: scrim; property: "opacity"
            to: 0.45; duration: 280; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: panel; property: "x"
            to: 0; duration: 320; easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation {
            target: scrim; property: "opacity"
            to: 0; duration: 200; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: panel; property: "x"
            to: -panel.width; duration: 260; easing.type: Easing.InCubic
        }
        onFinished: controlCenter.visible = false
    }
}
