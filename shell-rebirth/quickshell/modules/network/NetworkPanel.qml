import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../colors" as ColorsModule
import qs.components

Item {
    id: networkPanel
    anchors.fill: parent
    visible: false

    property bool opened: false
    property int currentTab: 0

    onOpenedChanged: {
        if (opened) {
            visible = true
            panel.x = networkPanel.width
            scrim.opacity = 0
            openAnim.restart()
        } else {
            closeAnim.restart()
        }
    }

    function close() {
        opened = false
    }

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
            onClicked: networkPanel.close()
        }
    }

    // ── Panel ─────────────────────────────────────────────────────────────────

    Rectangle {
        id: panel
        width: 380
        height: 600
        anchors.bottom: parent.bottom
        x: networkPanel.width

        color: ColorsModule.Colors.surface_container
        border.color: ColorsModule.Colors.outline_variant
        border.width: 1

        layer.enabled: true
        layer.smooth: true

        FocusScope {
            anchors.fill: parent
            focus: networkPanel.opened

            Keys.onEscapePressed: networkPanel.close()

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 10
                    color: ColorsModule.Colors.surface_container_high

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: currentTab === 0
                                ? ColorsModule.Colors.primary
                                : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "󰖩  Wi-Fi"
                                font.family: "Material Design Icons"
                                color: currentTab === 0
                                    ? ColorsModule.Colors.on_primary
                                    : ColorsModule.Colors.on_surface
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: currentTab = 0
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: currentTab === 1
                                ? ColorsModule.Colors.primary
                                : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "  Bluetooth"
                                font.family: "Material Design Icons"
                                color: currentTab === 1
                                    ? ColorsModule.Colors.on_primary
                                    : ColorsModule.Colors.on_surface
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: currentTab = 1
                            }
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: currentTab === 0
                        ? wifiComponent
                        : bluetoothComponent
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
            to: networkPanel.width - panel.width
            duration: 320; easing.type: Easing.OutCubic
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
            to: networkPanel.width
            duration: 260; easing.type: Easing.InCubic
        }
        onFinished: networkPanel.visible = false
    }

    Component { id: wifiComponent;      WifiPanel      {} }
    Component { id: bluetoothComponent; BluetoothPanel {} }
}
