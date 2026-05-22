import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services as Services
import "../../colors" as ColorsModule

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: 0

    Item {
        Layout.fillWidth: true
        Layout.topMargin: 8
        implicitHeight: 36

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: "Audio Output"
            color: ColorsModule.Colors.on_surface_variant
            font.pixelSize: 11
            font.letterSpacing: 1.2
            font.weight: Font.Medium
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        Layout.bottomMargin: 12
        spacing: 3

        Repeater {
            model: Services.Volume.sinks

            delegate: Item {
                id: delegate

                required property var modelData
                property bool isDefault: modelData === Services.Volume.defaultSink
                property string sinkName: modelData?.name ?? ""
                property string displayName: {
                    let name = sinkName
                    name = name.replace(/^alsa_output\./, "")
                    name = name.replace(/\.(analog-stereo|stereo|mono|surround.*)$/, "")
                    name = name.replace(/\./g, " ")
                    return name.charAt(0).toUpperCase() + name.slice(1)
                }
                property string description: modelData?.audio?.description ?? modelData?.description ?? ""
                property string label: description !== "" ? description : displayName

                Layout.fillWidth: true
                implicitHeight: 48

                Process {
                    id: pactlSetSink
                    command: ["pactl", "set-default-sink", delegate.sinkName]
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 8

                    color: delegate.isDefault
                        ? Qt.rgba(
                            ColorsModule.Colors.primary_container.r,
                            ColorsModule.Colors.primary_container.g,
                            ColorsModule.Colors.primary_container.b,
                            0.85
                        )
                        : hoverHandler.hovered
                            ? ColorsModule.Colors.surface_container_high
                            : ColorsModule.Colors.surface_container

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Rectangle {
                        width: 3
                        height: parent.height * 0.55
                        radius: 1.5
                        anchors.left: parent.left
                        anchors.leftMargin: 0
                        anchors.verticalCenter: parent.verticalCenter
                        color: ColorsModule.Colors.primary
                        opacity: delegate.isDefault ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: delegate.label
                                color: delegate.isDefault
                                    ? ColorsModule.Colors.on_primary_container
                                    : ColorsModule.Colors.on_surface
                                font.pixelSize: 13
                                font.weight: delegate.isDefault ? Font.Medium : Font.Normal
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: delegate.sinkName
                                color: delegate.isDefault
                                    ? Qt.rgba(
                                        ColorsModule.Colors.on_primary_container.r,
                                        ColorsModule.Colors.on_primary_container.g,
                                        ColorsModule.Colors.on_primary_container.b,
                                        0.55
                                    )
                                    : ColorsModule.Colors.on_surface_variant
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                visible: delegate.description !== ""
                                opacity: 0.85

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }
                            }
                        }

                        Text {
                            text: "✓"
                            color: ColorsModule.Colors.primary
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            opacity: delegate.isDefault ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }
                        }
                    }

                    HoverHandler {
                        id: hoverHandler
                    }

                    TapHandler {
                        onTapped: {
                            if (!delegate.isDefault) {
                                pactlSetSink.running = true
                                Services.Volume.setDefaultSink(delegate.modelData)
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        height: 1
        color: ColorsModule.Colors.outline_variant
        opacity: 0.4
    }
}
