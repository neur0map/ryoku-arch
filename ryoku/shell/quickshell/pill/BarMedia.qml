pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Mpris
import "Singletons"

// now-playing module: art thumb, ping-pong title, play state. click toggles
// playback, wheel nudges the sink volume (the OSD panel narrates the change).
// hidden with no player, so the plate only exists when there is music.
Row {
    id: media

    property real s: 1

    // the live wallpaper (mpvpaper) registers on MPRIS too; a bare video
    // filename is scenery, not music, so it never counts as a player here.
    function isWallpaper(p) {
        return /\.(mp4|webm|mkv|gif)$/i.test(p.trackTitle || "");
    }
    readonly property var player: {
        var l = Mpris.players.values.filter((p) => p && !isWallpaper(p));
        for (var i = 0; i < l.length; i++)
            if (l[i].isPlaying)
                return l[i];
        return l.length > 0 ? l[0] : null;
    }
    readonly property bool playing: player !== null && player.isPlaying
    readonly property bool present: player !== null && (player.trackTitle || "").length > 0
    readonly property string line: {
        if (!player)
            return "";
        var t = player.trackTitle || "";
        var a = Theme.joinArtists(player.trackArtists, player.trackArtist);
        return a.length > 0 ? t + " · " + a : t;
    }

    function toggle() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }

    spacing: 8 * s

    // art thumb: sharp square, hairline edge; kanji seal while artless.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 17 * media.s
        height: 17 * media.s
        color: Qt.alpha(Theme.bright, 0.05)
        border.width: 1
        border.color: Theme.hair
        clip: true

        Image {
            anchors.fill: parent
            anchors.margins: 1
            source: media.player ? (media.player.trackArtUrl || "") : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
        }
        Text {
            anchors.centerIn: parent
            visible: !media.player || !(media.player.trackArtUrl || "").length
            text: "音"
            color: Theme.iconDim
            font.family: Theme.fontJp
            font.pixelSize: 9 * media.s
        }
    }

    Marquee {
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

    // state tick: a vermilion play wedge while sounding, a paused hairline pair.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 8 * media.s
        height: 9 * media.s

        Canvas {
            anchors.fill: parent
            visible: media.playing
            onPaint: {
                var c = getContext("2d");
                c.reset();
                c.fillStyle = Theme.verm;
                c.beginPath();
                c.moveTo(0, 0);
                c.lineTo(width, height / 2);
                c.lineTo(0, height);
                c.closePath();
                c.fill();
            }
        }
        Row {
            anchors.centerIn: parent
            visible: !media.playing
            spacing: 2.5 * media.s
            Rectangle { width: 2 * media.s; height: 9 * media.s; color: Theme.dim }
            Rectangle { width: 2 * media.s; height: 9 * media.s; color: Theme.dim }
        }
    }
}
