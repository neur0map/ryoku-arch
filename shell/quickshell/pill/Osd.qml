import QtQuick
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "Singletons"

Item {
    id: root

    property real s: 1
    property bool suppressed: false
    property bool flashing: false
    property string kind: "volume"
    property bool armed: false
    property string shownTrackLine: ""
    property bool shownPlaying: false
    property string shownArtUrl: ""
    property string lastTrackLine: ""
    property bool lastPlaying: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real volume: sink && sink.audio ? Math.max(0, Math.min(1, sink.audio.volume)) : 0

    property var stickyPlayer: null
    readonly property var player: {
        var list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].isPlaying)
                return list[i];
        }
        if (stickyPlayer && list.indexOf(stickyPlayer) >= 0)
            return stickyPlayer;
        return list[0];
    }
    readonly property bool playing: player !== null && player.isPlaying
    readonly property string trackLine: {
        if (!player)
            return "";
        var t = player.trackTitle ? player.trackTitle : "";
        var a = Theme.joinArtists(player.trackArtists, player.trackArtist);
        return a.length > 0 ? t + " · " + a : t;
    }

    readonly property real desiredW: kind === "track" ? 332 * s : 248 * s
    readonly property real desiredH: kind === "track" ? 56 * s : 44 * s

    function trackEvent() {
        var line = trackLine;
        var p = playing;
        if (line === lastTrackLine && p === lastPlaying)
            return;
        lastTrackLine = line;
        lastPlaying = p;
        flash("track");
    }

    function flash(which) {
        if (!armed || suppressed || cooldownTimer.running)
            return;
        if (which === "track") {
            shownTrackLine = trackLine;
            shownPlaying = playing;
            shownArtUrl = player && player.trackArtUrl ? player.trackArtUrl : "";
        }
        kind = which;
        flashing = true;
        hideTimer.restart();
    }

    onSuppressedChanged: {
        if (suppressed) {
            hideTimer.stop();
            flashing = false;
        } else {
            cooldownTimer.restart();
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: root.flashing = false
    }

    Timer {
        id: cooldownTimer
        interval: 200
    }

    PwObjectTracker {
        objects: [root.sink].filter(Boolean)
    }

    Connections {
        target: root.sink && root.sink.audio ? root.sink.audio : null
        function onVolumesChanged() { root.flash("volume"); }
        function onMutedChanged() { root.flash("volume"); }
    }

    onPlayerChanged: {
        Qt.callLater(function() {
            if (stickyPlayer !== player)
                stickyPlayer = player;
        });
        trackEvent();
    }

    Connections {
        target: root.player
        function onTrackTitleChanged() { root.trackEvent(); }
        function onPlaybackStateChanged() { root.trackEvent(); }
    }

    Item {
        id: volRow
        anchors.fill: parent
        opacity: root.kind === "volume" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        GlyphIcon {
            id: volGlyph
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 17 * root.s
            height: 17 * root.s
            name: root.muted ? "speaker-off" : "speaker"
            color: root.muted ? Theme.dim : Theme.iconDim
            stroke: 1.7
        }

        Text {
            id: volPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 32 * root.s
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.volume * 100) + "%"
            color: root.muted ? Theme.dim : Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * root.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.left: volGlyph.right
            anchors.leftMargin: 12 * root.s
            anchors.right: volPct.left
            anchors.rightMargin: 12 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 4 * root.s
            radius: 2 * root.s
            color: Theme.threadBg

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.volume
                radius: parent.radius
                color: root.muted ? Theme.vermDim : Theme.vermLit
                Behavior on width { NumberAnimation { duration: Motion.fast } }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }
        }
    }

    Item {
        id: trackRow
        anchors.fill: parent
        opacity: root.kind === "track" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 150 } }

        ClippingRectangle {
            id: coverBox
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 30 * root.s
            height: 30 * root.s
            radius: 8 * root.s
            color: Theme.tileBg

            Image {
                id: cover
                anchors.fill: parent
                source: root.shownArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: status === Image.Ready && root.shownArtUrl !== ""
            }
            GlyphIcon {
                anchors.centerIn: parent
                width: parent.width * 0.45
                height: width
                name: "music"
                color: Theme.subtle
                visible: !cover.visible
            }
        }

        GlyphIcon {
            id: trackGlyph
            anchors.left: coverBox.right
            anchors.leftMargin: 11 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s
            name: root.shownPlaying ? "play-s" : "pause-s"
            color: Theme.iconDim
            stroke: 1.7
        }

        Text {
            anchors.left: trackGlyph.right
            anchors.leftMargin: 10 * root.s
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.shownTrackLine
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11.5 * root.s
            font.weight: Font.DemiBold
            maximumLineCount: 1
            elide: Text.ElideRight
        }
    }
}
