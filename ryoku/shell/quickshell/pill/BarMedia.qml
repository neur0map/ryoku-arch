pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// now-playing module: art thumb, ping-pong title, play state, all read from
// the shared Media pick (wallpaper-filtered). click toggles playback, wheel
// nudges the sink volume (the OSD panel narrates the change). hidden with no
// player, so the plate only exists when there is music. a vertical bar keeps
// only the art thumb (state tinted), the noctalia idiom.
Row {
    id: media

    property real s: 1
    property bool vertical: false

    readonly property var player: Media.player
    readonly property bool playing: Media.playing
    readonly property bool present: Media.present
    readonly property string line: Media.line

    function toggle() {
        Media.toggle();
    }

    spacing: 8 * s
    // art thumb: the noctalia circle, hairline edge; a music glyph while
    // artless. carries the play state alone on a vertical bar (accent ring
    // while sounding).
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: (media.vertical ? 20 : 18) * media.s
        height: (media.vertical ? 20 : 18) * media.s
        radius: width / 2
        color: Qt.alpha(Theme.bright, 0.05)
        border.width: 1
        border.color: media.playing ? Qt.alpha(Theme.verm, 0.8) : Theme.hair
        clip: true
        Image {
            anchors.fill: parent
            anchors.margins: 1
            source: media.player ? (media.player.trackArtUrl || "") : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
        MaterialIcon {
            anchors.centerIn: parent
            visible: !media.player || !(media.player.trackArtUrl || "").length
            text: "music_note"
            color: Theme.iconDim
            font.pixelSize: 10 * media.s
        }
    }

    Marquee {
        visible: !media.vertical
        id: title
        anchors.verticalCenter: parent.verticalCenter
        readonly property real natW: titleMetrics.advanceWidth
        width: Math.min(natW + 2, 170 * media.s)
        active: media.playing
        text: media.line
        color: media.playing ? Theme.cream : Theme.dim
        pixelSize: 10.5 * media.s
        weight: Font.Medium

        TextMetrics {
            id: titleMetrics
            text: media.line
            font.family: Theme.font
            font.pixelSize: 10.5 * media.s
            font.weight: Font.Medium
        }
    }

    // state glyph: filled play while sounding, pause otherwise.
    MaterialIcon {
        visible: !media.vertical
        anchors.verticalCenter: parent.verticalCenter
        text: media.playing ? "play_arrow" : "pause"
        fill: 1
        color: media.playing ? Theme.verm : Theme.dim
        font.pixelSize: 13 * media.s
    }
}
