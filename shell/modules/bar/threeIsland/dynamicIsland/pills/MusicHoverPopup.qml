import qs.modules.common
import qs.modules.common.widgets
import qs.modules.bar
import qs.services
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

// Hover-only rich tooltip for the music pill. Shows album art (with a
// soft fallback) plus title / artist / album. Works for any MPRIS source
// including browser players (Firefox / Chrome via plasma-browser-integration
// expose trackArtUrl as an https thumbnail URL).
StyledPopup {
    id: root

    // M3 rich tooltip: 16dp horizontal clears the rounded corner arc.
    horizontalPadding: 12
    verticalPadding: 12

    readonly property var track: MprisController.activeTrack
    readonly property string title:  track?.title  ?? ""
    readonly property string artist: track?.artist ?? ""
    readonly property string album:  track?.album  ?? ""
    readonly property string artUrl: MprisController.sanitizeArtUrl(track?.artUrl ?? "")

    readonly property color colPrimary: Appearance.ryokuEverywhere
        ? (Appearance.ryoku.colPrimary ?? Appearance.colors.colPrimary)
        : Appearance.colors.colPrimary

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12

        // Album art frame — fixed 64x64. Falls back to a music_note icon
        // on a tinted square when the player provides no art.
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 64
            implicitHeight: 64

            Rectangle {
                id: artBg
                anchors.fill: parent
                radius: 8
                color: Qt.rgba(root.colPrimary.r, root.colPrimary.g, root.colPrimary.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.06)

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: artImg.status !== Image.Ready
                    text: "music_note"
                    iconSize: 30
                    color: root.colPrimary
                    fill: 1
                }
            }

            Image {
                id: artImg
                anchors.fill: parent
                anchors.margins: 1
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                cache: true
                visible: false  // visible via the masked layer below
            }

            // Round the image corners to match artBg's 8px radius.
            MultiEffect {
                anchors.fill: artImg
                source: artImg
                visible: artImg.status === Image.Ready
                maskEnabled: true
                maskSource: maskRect
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }
            Item {
                id: maskRect
                anchors.fill: artImg
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    radius: 7
                    color: "white"
                }
            }
        }

        // Right column: title (bold) + artist + album, each elided.
        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 200
            spacing: 2

            // "Now playing" pill at the very top, only when actively playing.
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: MprisController.isPlaying

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: root.colPrimary

                    SequentialAnimation on opacity {
                        running: MprisController.isPlaying && Appearance.animationsEnabled
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 700; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                    }
                }
                StyledText {
                    text: Translation.tr("Now playing")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.colPrimary
                    Layout.fillWidth: true
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title || Translation.tr("Unknown title")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.artist.length > 0
                text: root.artist
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.album.length > 0 && root.album !== root.artist
                text: root.album
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                opacity: 0.75
                elide: Text.ElideRight
                wrapMode: Text.NoWrap
            }
        }
    }
}
