import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.services as Services
import "../../colors" as ColorsModule

Item {
    id: root

    Layout.fillWidth: true
    Layout.preferredHeight: notifSection.height
    Layout.margins: 15
    Layout.topMargin: 10
    Layout.bottomMargin: 10

    readonly property var notifModel: Services.Notification.history

    function clearAll() {
        while (Services.Notification.data.length > 0)
            Services.Notification.data.splice(0, 1)
    }

    ColumnLayout {
        id: notifSection
        width: parent.width
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 2
            Layout.rightMargin: 2

            Text {
                text: "Notifications"
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: ColorsModule.Colors.on_surface
                Layout.fillWidth: true
            }

            Text {
                text: notifModel.length.toString()
                font.pixelSize: 12
                font.weight: Font.Medium
                color: ColorsModule.Colors.on_surface_variant
                visible: notifModel.length > 0
            }

            Button {
                text: "Clear All"
                font.pixelSize: 11
                visible: notifModel.length > 0
                onClicked: clearAll()

                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: ColorsModule.Colors.primary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    implicitWidth: 70
                    implicitHeight: 28
                    radius: 14

                    color: parent.pressed ?
                        Qt.rgba(ColorsModule.Colors.primary.r,
                            ColorsModule.Colors.primary.g,
                            ColorsModule.Colors.primary.b, 0.15)
                        : parent.hovered ?
                            Qt.rgba(ColorsModule.Colors.primary.r,
                                ColorsModule.Colors.primary.g,
                                ColorsModule.Colors.primary.b, 0.08)
                            : ColorsModule.Colors.surface_container_high

                    border.width: 1
                    border.color: ColorsModule.Colors.outline_variant
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: notifModel.length > 0
                ? Math.min(list.contentHeight + 16, 400)
                : 120

            radius: 16
            color: ColorsModule.Colors.surface_container
            border.width: 1
            border.color: ColorsModule.Colors.outline_variant

            Behavior on Layout.preferredHeight {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: notifModel.length === 0

                Text {
                    text: "🔕"
                    font.pixelSize: 32
                    Layout.alignment: Qt.AlignHCenter
                    opacity: 0.5
                }

                Text {
                    text: "No notifications"
                    font.pixelSize: 13
                    color: ColorsModule.Colors.on_surface_variant
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 8

                model: notifModel
                spacing: 8
                clip: true
                visible: notifModel.length > 0

                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    width: list.width - 16
                    height: contentColumn.implicitHeight + 20
                    radius: 12

                    color: ColorsModule.Colors.surface_container_high
                    border.width: 1
                    border.color: ColorsModule.Colors.outline_variant

                    required property var modelData

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: ColorsModule.Colors.primary
                        opacity: mouseArea.containsMouse ? 0.05 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    RowLayout {
                        id: contentColumn
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 12

                        Rectangle {
                            width: 32
                            height: 32
                            radius: 8
                            color: "transparent"
                            clip: true
                            Layout.alignment: Qt.AlignTop

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectFit
                                smooth: true

                                source: {
                                    const icon = modelData.appIcon;
                                    if (icon) {
                                        if (icon.startsWith("/"))
                                            return "file://" + icon;
                                        if (icon.includes("://"))
                                            return icon;
                                        return "image://icon/" + icon;
                                    }
                                    return "image://icon/dialog-information";
                                }

                                onStatusChanged: {
                                    if (status === Image.Error)
                                        source = "image://icon/dialog-information";
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: modelData.appName || "App"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    color: ColorsModule.Colors.primary
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: modelData.timeStr
                                    font.pixelSize: 10
                                    color: ColorsModule.Colors.on_surface_variant
                                    opacity: 0.7
                                }
                            }

                            Text {
                                text: modelData.summary
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                color: ColorsModule.Colors.on_surface
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                visible: text.length > 0
                            }

                            Text {
                                text: modelData.body
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                                color: ColorsModule.Colors.on_surface_variant
                                maximumLineCount: 4
                                elide: Text.ElideRight
                                visible: text.length > 0
                            }
                        }
                    }
                }
            }
        }
    }
}
