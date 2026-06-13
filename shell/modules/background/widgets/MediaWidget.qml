pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Ryoku.Config
import Ryoku.Services
import qs.components
import qs.services

// Self-contained desktop now-playing card. The album art bleeds a blurred,
// colour-rich wash across the whole card (its `backdrop`), so the card adopts the
// cover's hue while playing; a crisp cover, flip-animated track text, a springy
// gradient progress bar and a morphing play/pause FAB sit on top.
WidgetCard {
    id: root

    readonly property real contentWidth: 300 * root.sizeScale
    readonly property var active: Players.active
    readonly property bool hasMedia: active ?? false
    readonly property bool hasArt: root.hasMedia && Players.getArtUrl(root.active) !== ""
    property real progress: active?.length ? (active.position % active.length) / active.length : 0

    Behavior on progress {
        Anim {
            type: Anim.StandardLarge
        }
    }

    Timer {
        running: root.active?.isPlaying ?? false
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: root.active?.positionChanged()
    }

    // Album-art ambient bleed: a blurred, slightly-zoomed copy of the cover fills
    // the card and a scrim keeps text legible.
    backdrop: Item {
        anchors.fill: parent
        visible: root.hasArt
        opacity: root.hasArt ? 1 : 0

        Behavior on opacity {
            Anim {}
        }

        Image {
            anchors.fill: parent
            anchors.margins: -parent.width * 0.25
            source: root.hasArt ? Players.getArtUrl(root.active) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 96
            sourceSize.height: 96
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: 1
                blurMax: 64
                saturation: 0.25
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3surface, Colours.light ? 0.4 : 0.5)
        }
    }

    ColumnLayout {
        width: root.contentWidth
        spacing: Tokens.spacing.normal * root.sizeScale

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal * root.sizeScale

            StyledClippingRect {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 60 * root.sizeScale
                implicitHeight: 60 * root.sizeScale
                radius: Tokens.rounding.normal * root.sizeScale
                color: Qt.alpha(Colours.palette.m3surfaceContainerHighest, 0.8)

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "music_note"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.extraLarge * root.sizeScale
                }

                Image {
                    anchors.fill: parent
                    source: Players.getArtUrl(root.active)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 120 * root.sizeScale
                    sourceSize.height: 120 * root.sizeScale
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1

                StyledText {
                    Layout.fillWidth: true
                    animate: true
                    text: (root.active?.trackTitle ?? "") || qsTr("Nothing playing")
                    color: Colours.palette.m3onSurface
                    font.pointSize: Tokens.font.size.normal * root.sizeScale
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    animate: true
                    visible: root.hasMedia
                    text: (root.active?.trackArtist ?? "") || qsTr("Unknown artist")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small * root.sizeScale
                    elide: Text.ElideRight
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 5 * root.sizeScale
            radius: Tokens.rounding.full
            color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
            clip: true

            StyledRect {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                implicitWidth: Math.max(parent.height, root.progress * parent.width)
                radius: Tokens.rounding.full
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: Colours.palette.m3primary
                    }
                    GradientStop {
                        position: 1
                        color: Qt.lighter(Colours.palette.m3primary, 1.3)
                    }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.large * root.sizeScale

            Control {
                icon: "skip_previous"
                canUse: root.active?.canGoPrevious ?? false
                onActivated: root.active?.previous()
            }

            Control {
                icon: root.active?.isPlaying ? "pause" : "play_arrow"
                canUse: root.active?.canTogglePlaying ?? false
                filled: true
                playing: root.active?.isPlaying ?? false
                onActivated: root.active?.togglePlaying()
            }

            Control {
                icon: "skip_next"
                canUse: root.active?.canGoNext ?? false
                onActivated: root.active?.next()
            }
        }
    }

    component Control: StyledRect {
        id: control

        required property string icon
        required property bool canUse
        property bool filled: false
        property bool playing: false
        signal activated

        implicitWidth: (control.filled ? 42 : 36) * root.sizeScale
        implicitHeight: implicitWidth
        // Play/pause FAB morphs from a circle (paused) to a rounded square (playing).
        radius: control.filled && control.playing ? Tokens.rounding.normal * root.sizeScale : width / 2
        color: control.filled && control.canUse ? Colours.palette.m3primary : "transparent"

        Behavior on radius {
            Anim {
                type: Anim.EmphasizedLarge
            }
        }

        StateLayer {
            disabled: !control.canUse
            radius: parent.radius
            color: control.filled ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: control.activated()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: control.icon
            fill: 1
            color: !control.canUse ? Colours.palette.m3outline : control.filled ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.large * root.sizeScale
        }
    }
}
