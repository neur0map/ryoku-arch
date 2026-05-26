pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import Ryoku.Services
import qs.components
import qs.services

// Self-contained desktop now-playing card: album art, track text, transport
// controls and a thin progress bar. Compact and legible standalone.
StyledRect {
    id: root

    readonly property var active: Players.active
    readonly property bool hasMedia: active ?? false
    property real progress: active?.length ? (active.position % active.length) / active.length : 0

    implicitWidth: 320
    implicitHeight: col.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.large
    color: Qt.alpha(Colours.palette.m3surfaceContainer, 0.78)
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

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

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal

            StyledClippingRect {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 60
                implicitHeight: 60
                radius: Tokens.rounding.normal
                color: Colours.palette.m3surfaceContainerHighest

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "music_note"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.extraLarge
                }

                Image {
                    anchors.fill: parent
                    source: Players.getArtUrl(root.active)
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 120
                    sourceSize.height: 120
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
                    font.pointSize: Tokens.font.size.normal
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    animate: true
                    visible: root.hasMedia
                    text: (root.active?.trackArtist ?? "") || qsTr("Unknown artist")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    elide: Text.ElideRight
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 4
            radius: Tokens.rounding.full
            color: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

            StyledRect {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                implicitWidth: Math.max(parent.height, root.progress * parent.width)
                radius: Tokens.rounding.full
                color: Colours.palette.m3primary
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.large

            Control {
                icon: "skip_previous"
                canUse: root.active?.canGoPrevious ?? false
                onActivated: root.active?.previous()
            }

            Control {
                icon: root.active?.isPlaying ? "pause" : "play_arrow"
                canUse: root.active?.canTogglePlaying ?? false
                filled: true
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
        signal activated

        implicitWidth: 36
        implicitHeight: 36
        radius: Tokens.rounding.full
        color: filled && canUse ? Colours.palette.m3primary : "transparent"

        StateLayer {
            disabled: !control.canUse
            radius: Tokens.rounding.full
            color: control.filled ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: control.activated()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: control.icon
            color: !control.canUse ? Colours.palette.m3outline : control.filled ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.large
        }
    }
}
