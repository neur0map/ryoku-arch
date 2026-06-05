pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import qs.ambxst.modules.theme
import qs.ambxst.modules.components
import qs.ambxst.modules.services
import qs.ambxst.config

Item {
    id: root

    required property PwNode node
    property string icon: ""
    property bool isMainDevice: false

    implicitHeight: 56
    implicitWidth: parent?.width ?? 300

    PwObjectTracker {
        objects: [root.node]
    }

    readonly property bool isMuted: root.node?.audio?.muted ?? false
    readonly property real volume: root.node?.audio?.volume ?? 0
    property real lastSetVolume: volume

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                id: muteButton
                flat: true
                implicitWidth: 32
                implicitHeight: 32
                Layout.preferredWidth: 32
                Layout.maximumWidth: 32
                Layout.fillWidth: false

                background: StyledRect {
                    variant: muteButton.hovered ? "focus" : "common"
                    radius: Styling.radius(4)
                }

                contentItem: Item {
                    Text {
                        anchors.centerIn: parent
                        text: {
                            if (root.isMuted)
                                return Icons.speakerSlash;
                            if (root.icon)
                                return root.icon;
                            return Icons.speakerHigh;
                        }
                        font.family: Icons.font
                        font.pixelSize: 16
                        color: root.isMuted ? Colors.error : Colors.overBackground

                        Behavior on color {
                            enabled: Config.animDuration > 0
                            ColorAnimation {
                                duration: Config.animDuration / 2
                            }
                        }
                    }
                }

                onClicked: {
                    if (root.node?.audio) {
                        root.node.audio.muted = !root.node.audio.muted;
                    }
                }

                StyledToolTip {
                    visible: muteButton.hovered
                    tooltipText: root.isMuted ? "Unmute" : "Mute"
                }
            }

            StyledSlider {
                id: volumeSlider
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                value: root.volume
                scroll: false
                progressColor: {
                    if (root.isMuted)
                        return Colors.outline;
                    if (Audio.protectionTriggered && root.isMainDevice)
                        return Colors.warning;
                    return Styling.srItem("overprimary");
                }

                onValueChanged: {
                    if (root.node?.audio && Math.abs(value - root.volume) > 0.001) {
                        Audio.setNodeVolume(root.node, value);
                    }
                }

                Behavior on progressColor {
                    enabled: Config.animDuration > 0
                    ColorAnimation {
                        duration: Config.animDuration / 2
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: root.isMainDevice ? Audio.friendlyDeviceName(root.node) : Audio.appNodeDisplayName(root.node)
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
            }

            Separator {
                Layout.fillWidth: true
            }

            Text {
                visible: Audio.protectionTriggered && root.isMainDevice
                text: Icons.shieldCheck
                font.family: Icons.font
                font.pixelSize: 12
                color: Colors.warning

                StyledToolTip {
                    visible: parent.visible && protectionIndicatorMa.containsMouse
                    tooltipText: "Volume protection active"
                }

                MouseArea {
                    id: protectionIndicatorMa
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }

            Text {
                text: `${Math.round(root.volume * 100)}%`
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
