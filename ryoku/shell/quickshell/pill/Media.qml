pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "Singletons"

/**
 * Now-playing card in the carbon-dossier idiom. Album art sits on the left; to
 * its right a 力 MEDIA eyebrow leads the title, artist, and a mono source/time
 * line. A flat vermilion play seal flanked by chevron skips, the Ryoku wave as
 * the seek line (dry base stroke + painted progress stroke), and faint corner
 * registration ticks framing it. The painted head is where the pill's soul bead
 * docks. Reads the active MPRIS player.
 */
PillSurface {
    id: root

    /**
     * Pick order: playing > paused-with-track > controllable. Keeps a browser
     * that exposes an empty MPRIS endpoint from shadowing a paused player that
     * still has a track.
     */
    readonly property var player: {
        var list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        var withTrack = null;
        var controllable = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p)
                continue;
            if (p.isPlaying)
                return p;
            if (!withTrack && p.canControl && p.trackTitle && p.trackTitle.length > 0)
                withTrack = p;
            if (!controllable && p.canControl)
                controllable = p;
        }
        return withTrack ? withTrack : (controllable ? controllable : list[0]);
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.isPlaying
    readonly property string title: hasPlayer && player.trackTitle ? player.trackTitle : "Nothing playing"
    readonly property string artist: hasPlayer
        ? Theme.joinArtists(player.trackArtists, player.trackArtist) : ""
    readonly property string playerService: {
        if (!hasPlayer)
            return "";
        var n = player.identity ? player.identity : (player.desktopEntry ? player.desktopEntry : "");
        return n.toLowerCase();
    }
    readonly property string artUrl: hasPlayer && player.trackArtUrl ? player.trackArtUrl : ""
    readonly property bool hasArt: artUrl !== ""
        && (coverPair.front.status === Image.Ready || coverPair.back.status === Image.Ready)
    readonly property real lengthSec: hasPlayer && player.length > 0 ? player.length : 0
    readonly property real positionSec: hasPlayer ? player.position : 0
    readonly property real playFrac: lengthSec > 0 ? Math.max(0, Math.min(1, positionSec / lengthSec)) : 0
    property real dragFrac: 0
    property bool dragging: false
    readonly property real frac: dragging ? dragFrac : playFrac

    readonly property real textX: 134 * s
    readonly property real edgePad: 18 * s
    readonly property color washMid: mix(Theme.cardTop, Theme.cardBot, 0.5)
    property real sealPulse: 0

    /**
     * Where the soul bead docks: head of the painted stroke. mapToItem isn't
     * reactive, so the void reads force re-eval across morph resizes.
     */
    readonly property point seamHead: {
        void root.width;
        void root.height;
        void root.frac;
        void stroke.x;
        void stroke.width;
        return stroke.mapToItem(root, stroke.headX, stroke.headY);
    }
    readonly property real seamHeadX: seamHead.x
    readonly property real seamHeadY: seamHead.y

    ameForm: "seam"
    amePoint: Qt.point(seamHeadX, seamHeadY)

    function fmt(sec) {
        if (!(sec > 0))
            return "0:00";
        var t = Math.floor(sec);
        var m = Math.floor(t / 60);
        var ss = t % 60;
        return m + ":" + (ss < 10 ? "0" + ss : ss);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    /**
     * Art loads only while the surface is open. A 24/7 daemon shouldn't fetch
     * and decode remote cover URLs on every background track change, and the
     * 2026-06-12 segfault hit exactly here during a closed-surface Spotify
     * metadata update.
     */
    onArtUrlChanged: if (active) coverPair.load(artUrl)
    onActiveChanged: if (active) coverPair.load(artUrl)
    onTitleChanged: if (playing && active) pulseAnim.restart()

    Timer {
        interval: 500
        running: root.active && root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged();
    }

    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: root; property: "sealPulse"; to: 1; duration: Motion.fast; easing.type: Motion.easeStandard }
        NumberAnimation { target: root; property: "sealPulse"; to: 0; duration: Motion.standard; easing.type: Motion.easeStandard }
    }

    NumberAnimation {
        id: coverFade
        property: "opacity"
        to: 1
        duration: Motion.standard
        easing.type: Easing.OutCubic
        onFinished: coverPair.settle()
    }

    component KanjiSkip: Text {
        id: skip

        property bool can: false
        signal activated()

        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.font
        font.pixelSize: 13 * root.s
        color: skipArea.containsMouse ? Theme.cream : Theme.dim
        opacity: skip.can ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }

        MouseArea {
            id: skipArea
            anchors.fill: parent
            anchors.margins: -6 * root.s
            hoverEnabled: true
            enabled: skip.can
            cursorShape: Qt.PointingHandCursor
            onClicked: skip.activated()
        }
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: 22 * root.s
        color: "transparent"

        Image {
            id: bleedSrc
            anchors.fill: parent
            source: root.active ? root.artUrl : ""
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: bleedSrc
            scale: 1.12
            visible: root.active && root.artUrl !== "" && bleedSrc.status === Image.Ready
            blurEnabled: true
            blur: 0.95
            blurMax: 64
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Theme.cardTop, 0.88) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.cardBot, 0.93) }
            }
        }

        Item {
            id: coverPair
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 118 * root.s
            clip: true

            property var front: coverA
            property var back: coverB

            /** Stage `url` on the hidden back image; reveal() runs once it decodes. */
            function load(url) {
                coverFade.stop();
                back.opacity = 0;
                if (!url) {
                    front.source = "";
                    back.source = "";
                    return;
                }
                if (String(front.source) === url) {
                    back.source = "";
                    return;
                }
                back.source = url;
            }

            function reveal() {
                coverFade.target = back;
                coverFade.restart();
            }

            function settle() {
                const old = front;
                front = back;
                back = old;
                old.source = "";
                old.opacity = 0;
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.tileBg
                visible: !root.hasArt
            }

            Image {
                id: coverA
                anchors.fill: parent
                z: coverPair.back === this ? 1 : 0
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                onStatusChanged: if (status === Image.Ready && coverPair.back === this) coverPair.reveal()
            }

            Image {
                id: coverB
                anchors.fill: parent
                z: coverPair.back === this ? 1 : 0
                opacity: 0
                sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                onStatusChanged: if (status === Image.Ready && coverPair.back === this) coverPair.reveal()
            }

            GlyphIcon {
                z: 2
                anchors.centerIn: parent
                width: 40 * root.s
                height: width
                name: "music"
                color: Theme.subtle
                visible: !root.hasArt
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 62 * root.s
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 56 * root.s
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.alpha(root.washMid, 0) }
                GradientStop { position: 0.7; color: Qt.alpha(root.washMid, 0.8) }
                GradientStop { position: 1.0; color: root.washMid }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: root.textX
            anchors.right: parent.right
            anchors.rightMargin: root.edgePad
            anchors.top: parent.top
            anchors.topMargin: 14 * root.s
            spacing: 3 * root.s
            Row {
                spacing: 7 * root.s

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "力"
                    color: Theme.brand
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: 13 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "MEDIA"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.8 * root.s
                }
            }

            Marquee {
                anchors.left: parent.left
                anchors.right: parent.right
                text: root.title
                color: Theme.cream
                pixelSize: 17 * root.s
                weight: Font.DemiBold
                active: root.active
            }
            Marquee {
                anchors.left: parent.left
                anchors.right: parent.right
                text: root.artist
                color: Theme.dim
                pixelSize: 11.5 * root.s
                active: root.active
                visible: text.length > 0
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: root.textX
            anchors.right: transport.left
            anchors.rightMargin: 10 * root.s
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 44 * root.s
            elide: Text.ElideRight
            text: {
                const head = root.playerService.length > 0 ? root.playerService + " · " : "";
                const cur = root.fmt(root.dragging ? root.dragFrac * root.lengthSec : root.positionSec);
                return head + cur + " · " + root.fmt(root.lengthSec);
            }
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 9 * root.s
            font.features: { "tnum": 1 }
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1 * root.s
        }

        Row {
            id: transport
            anchors.right: parent.right
            anchors.rightMargin: root.edgePad
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 38 * root.s
            spacing: 14 * root.s

            KanjiSkip {
                text: "‹"
                can: root.hasPlayer && root.player.canGoPrevious
                onActivated: if (root.player) root.player.previous()
            }

            Rectangle {
                id: seal
                anchors.verticalCenter: parent.verticalCenter
                width: 30 * root.s
                height: 30 * root.s
                radius: 4 * root.s
                scale: 1 + 0.06 * root.sealPulse

                /** 1 while playing, eases to 0 when paused; dims the flat fill. */
                property real sat: root.playing ? 1 : 0
                Behavior on sat { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }

                opacity: sealArea.enabled ? 1 : 0.4
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                color: root.mix(Theme.verm, Theme.tileBg, 0.55 * (1 - seal.sat))
                border.width: 1
                border.color: Qt.alpha(Theme.vermLit, 0.5)

                Text {
                    anchors.centerIn: parent
                    text: root.playing ? "▶" : "Ⅱ"
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 15 * root.s
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: sealArea
                    anchors.fill: parent
                    anchors.margins: -4 * root.s
                    hoverEnabled: true
                    enabled: root.hasPlayer && root.player.canTogglePlaying
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player) root.player.togglePlaying()
                }
            }

            KanjiSkip {
                text: "›"
                can: root.hasPlayer && root.player.canGoNext
                onActivated: if (root.player) root.player.next()
            }
        }

        Canvas {
            id: stroke
            anchors.left: parent.left
            anchors.leftMargin: root.textX
            anchors.right: parent.right
            anchors.rightMargin: root.edgePad
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10 * root.s
            height: 18 * root.s

            readonly property real inset: 3 * root.s
            readonly property real usable: Math.max(1, width - 2 * inset)
            readonly property real amp: 2.2 * root.s
            readonly property real wavelength: 8 * root.s
            property real targetF: root.frac
            property real lastFrac: 0
            property real drawF: targetF
            readonly property real headX: inset + drawF * usable
            readonly property real headY: waveY(drawF)

            /**
             * Half-second chase between position ticks. Only enabled for small
             * advances, so seeks and track changes snap instead of gliding.
             */
            Behavior on drawF {
                enabled: Math.abs(root.frac - stroke.lastFrac) < 0.02
                NumberAnimation { duration: 500; easing.type: Easing.Linear }
            }
            onTargetFChanged: Qt.callLater(() => { stroke.lastFrac = root.frac; })

            onDrawFChanged: requestPaint()
            onWidthChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()

            /** A Ryoku wave: a uniform sine ripple across the stroke, the same
             * signature the WaveMeter draws, so the seek line reads as the house wave. */
            function waveY(u) {
                return height / 2 + amp * Math.sin(u * usable * (6.28318 / wavelength));
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (width <= 0 || height <= 0)
                    return;
                ctx.lineWidth = 2 * root.s;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                const steps = Math.max(8, Math.round(usable / 1.5));

                // Dim full-width base: the track the playback head has not reached.
                ctx.strokeStyle = Theme.border;
                ctx.beginPath();
                for (let i = 0; i <= steps; i++) {
                    const u = i / steps;
                    const x = inset + u * usable;
                    const y = waveY(u);
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.stroke();

                if (drawF <= 0.002)
                    return;

                // Bright crest from the tail to the playback head.
                ctx.strokeStyle = Theme.verm;
                ctx.beginPath();
                const lit = Math.max(2, Math.round(steps * drawF));
                for (let i = 0; i <= lit; i++) {
                    const u = (i / lit) * drawF;
                    const x = inset + u * usable;
                    const y = waveY(u);
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.stroke();

                // Head dot: the playback position, where the soul bead docks.
                ctx.fillStyle = Theme.verm;
                ctx.beginPath();
                ctx.arc(headX, headY, 2.6 * root.s, 0, 6.28318);
                ctx.fill();
            }

            Timer {
                id: dragWrite
                interval: 150
                repeat: true
                onTriggered: seekArea.commit()
            }

            MouseArea {
                id: seekArea
                anchors.fill: parent
                anchors.margins: -8 * root.s
                enabled: root.hasPlayer && root.player.canSeek && root.lengthSec > 0
                cursorShape: Qt.PointingHandCursor
                function fracAt(mx) {
                    return Math.max(0, Math.min(1, (mx - 8 * root.s - stroke.inset) / stroke.usable));
                }
                function commit() {
                    if (root.player)
                        root.player.position = root.dragFrac * root.lengthSec;
                }
                onPressed: (e) => {
                    root.dragFrac = fracAt(e.x);
                    root.dragging = true;
                    dragWrite.restart();
                }
                onPositionChanged: (e) => { if (pressed) root.dragFrac = fracAt(e.x); }
                onReleased: {
                    dragWrite.stop();
                    commit();
                    root.dragging = false;
                }
            }
        }

        CornerTicks {
            anchors.fill: parent
            anchors.margins: 9 * root.s
            s: root.s
        }
    }
}
