import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "Singletons"
import "lib/wave.js" as Wave

// Now-playing detail: album art with a blurred bleed backdrop, title/artist, and
// the signature wavy seekbar (the filled portion is a moving sine while playing,
// flat when paused). Reads the active MPRIS player. The FrameAnimation that
// drives the wave repaints only while playing, so an idle launcher costs nothing.
Item {
    id: root

    property real s: 1
    property var player: null

    readonly property bool playing: player && player.isPlaying
    readonly property string title: player && player.trackTitle ? player.trackTitle : "Nothing playing"
    readonly property string artist: player ? Theme.joinArtists(player.trackArtists, player.trackArtist) : ""
    readonly property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property real frac: player && player.length > 0 ? Math.max(0, Math.min(1, player.position / player.length)) : 0

    implicitHeight: 132 * s

    ClippingRectangle {
        anchors.fill: parent
        radius: Metrics.radiusRow * root.s
        color: Theme.cardBot

        Image {
            id: bleed
            anchors.fill: parent
            source: root.artUrl
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bleed
            scale: 1.12
            visible: root.artUrl !== "" && bleed.status === Image.Ready
            blurEnabled: true
            blur: 0.95
            blurMax: 48
            saturation: 0.1
        }
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Theme.cardBot.r, Theme.cardBot.g, Theme.cardBot.b, 0.78)
        }

        ClippingRectangle {
            id: cover
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 12 * root.s
            width: height
            radius: 8 * root.s
            color: Theme.tileBg

            Image {
                anchors.fill: parent
                source: root.artUrl
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready
            }
            GlyphIconFallback {
                anchors.centerIn: parent
                visible: root.artUrl === ""
                s: root.s
            }
        }

        Column {
            anchors.left: cover.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 14 * root.s
            anchors.rightMargin: 14 * root.s
            anchors.topMargin: 18 * root.s
            spacing: 4 * root.s

            Text {
                width: parent.width
                text: "力 NOW PLAYING"
                color: Theme.vermLit
                font.family: Theme.font
                font.pixelSize: Metrics.fontEyebrow * root.s
                font.letterSpacing: 1.5
            }
            Text {
                width: parent.width
                text: root.title
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: Metrics.fontTitle * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.artist
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: Metrics.fontSubtitle * root.s
                elide: Text.ElideRight
                visible: root.artist.length > 0
            }
        }

        // The wavy seekbar: dry base stroke + the painted progress wave.
        Canvas {
            id: seek
            anchors.left: cover.right
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 14 * root.s
            anchors.rightMargin: 14 * root.s
            anchors.bottomMargin: 18 * root.s
            height: 14 * root.s

            property real phase: 0

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var w = width;
                var cy = height / 2;
                var fillW = w * root.frac;

                // base (unfilled) flat line
                ctx.strokeStyle = Theme.faint;
                ctx.lineWidth = 2 * root.s;
                ctx.beginPath();
                ctx.moveTo(fillW, cy);
                ctx.lineTo(w, cy);
                ctx.stroke();

                // filled portion: a sine while playing, flat when paused
                var amp = root.playing ? 3 * root.s : 0;
                var pts = Wave.samplePoints(fillW, cy, amp, Math.max(1, Math.round(fillW / (24 * root.s))), seek.phase, 48);
                ctx.strokeStyle = Theme.vermLit;
                ctx.lineWidth = 2.5 * root.s;
                ctx.beginPath();
                for (var i = 0; i < pts.length; i++) {
                    if (i === 0) ctx.moveTo(pts[i].x, pts[i].y);
                    else ctx.lineTo(pts[i].x, pts[i].y);
                }
                ctx.stroke();
            }
        }

        FrameAnimation {
            running: root.playing && root.visible
            onTriggered: {
                seek.phase = Wave.phaseFor(Date.now());
                seek.requestPaint();
            }
        }

        // repaint on position/frac change even when paused (seek bar position).
        Connections {
            target: root
            function onFracChanged() { seek.requestPaint(); }
            function onPlayingChanged() { seek.requestPaint(); }
        }
    }

    // music-note placeholder when there's no art, kept inline so NowPlaying has no
    // external glyph dependency.
    component GlyphIconFallback: Text {
        property real s: 1
        text: "\u266a"
        color: Theme.subtle
        font.pixelSize: 28 * s
    }
}
