pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import Ryoku.Config
import ".."
import qs.components
import qs.components.controls
import qs.services

// RYOKU: draggable gaming-overlay now-playing widget. Reuses the shared Players
// service (active MprisPlayer + getArtUrl) for album art, title/artist and the
// prev / play-pause / next transport. Renders nothing when there is no active
// player so it stays out of the way until media starts.
OverlayWidget {
    id: root

    widgetId: "music"

    readonly property MprisPlayer player: Players.active

    StyledRect {
        anchors.fill: parent
        visible: root.player !== null

        implicitWidth: 280
        implicitHeight: contentRow.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.small
        color: Qt.alpha(Colours.palette.m3surface, 0.7)

        Row {
            id: contentRow

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.normal

            StyledClippingRect {
                id: cover

                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 48
                implicitHeight: 48
                radius: Tokens.rounding.small
                color: Colours.tPalette.m3surfaceContainerHigh

                // Placeholder shown behind the cover when there is no art, mirroring
                // the dashboard media handling.
                MaterialIcon {
                    anchors.centerIn: parent
                    text: "art_track"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.large
                }

                Image {
                    anchors.fill: parent
                    source: root.player ? Players.getArtUrl(root.player) : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(width, height)
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.spacing.small

                StyledText {
                    width: 150
                    text: (root.player?.trackTitle ?? "") || qsTr("Unknown title")
                    color: Colours.palette.m3primary
                    elide: Text.ElideRight
                }

                StyledText {
                    width: 150
                    text: root.player?.trackArtist ?? ""
                    elide: Text.ElideRight
                    opacity: 0.7
                    font.pointSize: Tokens.font.size.small
                }

                Row {
                    spacing: Tokens.spacing.small

                    IconButton {
                        icon: "skip_previous"
                        type: IconButton.Tonal
                        font.pointSize: Tokens.font.size.large
                        disabled: !(root.player?.canGoPrevious ?? false)
                        onClicked: root.player?.previous()
                    }

                    IconButton {
                        icon: root.player?.isPlaying ? "pause" : "play_arrow"
                        font.pointSize: Tokens.font.size.large
                        disabled: !(root.player?.canTogglePlaying ?? false)
                        onClicked: root.player?.togglePlaying()
                    }

                    IconButton {
                        icon: "skip_next"
                        type: IconButton.Tonal
                        font.pointSize: Tokens.font.size.large
                        disabled: !(root.player?.canGoNext ?? false)
                        onClicked: root.player?.next()
                    }
                }
            }
        }
    }
}
