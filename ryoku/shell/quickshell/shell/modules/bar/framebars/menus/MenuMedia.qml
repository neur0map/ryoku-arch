pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import "../.." as Pill
import shell.services
import "../../../../components"

// Media player entry (contract 06 sec 2.10): a bordered now-playing card with a
// centered title and artist, a debounced seek scrubber flanked by elapsed and
// total time, and a centered transport row (shuffle, previous, play/pause, next,
// loop) whose buttons dim to their capability flags. With more than one real
// player a switcher header names the active one and steps between them, and the
// cards slide horizontally 200ms (contract 06 sec 5: gtk::Stack SlideLeftRight)
// through the shared 200ms ease-out envelope.
//
// The whole entry stays hidden (no reserved height) until a real player exists;
// the shared Media pick already drops the live-wallpaper player. There is no
// album art: the reference card intentionally shows only text, scrubber and
// transport (contract 06 sec 6/9).
//
// Position comes from the player's own position property (a stream), not a QML
// poll of an external tool: each card binds to player.position and nudges the
// binding with positionChanged() while playing, the standard Quickshell idiom
// (see launcher/NowPlaying.qml). Seek is debounced 300ms after the drag stops
// with a 3s post-seek window that ignores incoming positions; audio volume is
// not debounced (that lives on the audio rows).
Item {
    id: root

    property real s: 1
    required property bool open

    // Non-wallpaper players in service order (no client sort); the same pick the
    // rest of the shell shares, so Media.player is one of these when non-empty.
    readonly property var players: Mpris.players.values.filter(p => p && !Media.isWallpaper(p))
    // A local switcher pick overrides Media's auto-choice and falls back to it
    // once the picked player leaves the list.
    property var picked: null
    readonly property var player: (root.picked && root.players.indexOf(root.picked) !== -1) ? root.picked : Media.player
    readonly property int idx: root.player ? root.players.indexOf(root.player) : -1

    visible: root.players.length > 0
    implicitHeight: root.players.length > 0 ? content.implicitHeight : 0

    // "{h}:{mm}:{ss}" past an hour, else "{m}:{ss}".
    function fmtTime(sec) {
        sec = Math.max(0, Math.floor(sec));
        const h = Math.floor(sec / 3600);
        const m = Math.floor((sec % 3600) / 60);
        const r = sec % 60;
        const ss = (r < 10 ? "0" : "") + r;
        if (h >= 1)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + ss;
        return m + ":" + ss;
    }

    // A surface tile carrying one centered Material Symbols glyph; content dims to
    // the disabled tone through the shared MenuButton when its capability is off.
    component IconButton: MenuButton {
        id: ib
        property alias iconName: glyph.text
        minW: Theme.iconSm + ib.pad * 2
        minH: Theme.iconSm + ib.pad * 2
        MaterialIcon {
            id: glyph
            anchors.centerIn: parent
            font.pixelSize: Theme.iconSm
            color: ib.contentColor
        }
    }

    // One player's now-playing card: title/artist/scrubber/transport, self-
    // contained seek state, and its own position stream tick. Only the active,
    // playing card ticks; the rest hold their last position.
    component MediaCard: Rectangle {
        id: card
        property var player: null
        property bool active: false
        property bool cardOpen: false

        color: "transparent"
        radius: Theme.radiusWidget
        border.width: Theme.borderWidth
        border.color: Theme.outline
        implicitHeight: cardCol.implicitHeight + Theme.paddingMd * 2
        SumiEdge {}

        readonly property real posn: card.player ? card.player.position : 0
        readonly property real len: (card.player && card.player.length > 0) ? card.player.length : 0
        readonly property real liveFrac: card.len > 0 ? Math.max(0, Math.min(1, card.posn / card.len)) : 0
        // While a seek is armed the scrubber and elapsed label hold the target so
        // the thumb never snaps back to a stream position not caught up yet.
        property bool seekArmed: false
        property bool seekSent: false
        property real seekFrac: 0
        readonly property real shownFrac: card.seekArmed ? card.seekFrac : card.liveFrac

        // A track/player swap on a reused delegate abandons any pending seek.
        onPlayerChanged: {
            seekDebounce.stop();
            seekIgnore.stop();
            card.seekArmed = false;
            card.seekSent = false;
        }

        // Each scrub change previews immediately and restarts the debounce; the
        // real seek lands 300ms after the last change stops (contract 06 sec 4/5).
        function onScrub(frac) {
            card.seekFrac = Math.max(0, Math.min(1, frac));
            card.seekArmed = true;
            card.seekSent = false;
            seekDebounce.restart();
        }

        function iconShuffle() {
            return (card.player && card.player.shuffle) ? "shuffle_on" : "shuffle";
        }
        function iconLoop() {
            if (card.player) {
                if (card.player.loopState === MprisLoopState.Track)
                    return "repeat_one_on";
                if (card.player.loopState === MprisLoopState.Playlist)
                    return "repeat_on";
            }
            return "repeat";
        }
        // None -> Playlist -> Track -> None (contract 06 sec 4).
        function cycleLoop() {
            if (!card.player)
                return;
            if (card.player.loopState === MprisLoopState.None)
                card.player.loopState = MprisLoopState.Playlist;
            else if (card.player.loopState === MprisLoopState.Playlist)
                card.player.loopState = MprisLoopState.Track;
            else
                card.player.loopState = MprisLoopState.None;
        }

        // MPRIS never pushes position, so advance the binding while playing by
        // re-reading the stream; the standard Quickshell nudge (NowPlaying.qml).
        Timer {
            interval: 500
            repeat: true
            running: card.active && card.cardOpen && card.player !== null && card.player.isPlaying
            onTriggered: {
                card.player.positionChanged();
                // Resume live updates early once the stream reflects a sent seek.
                if (card.seekSent && Math.abs(card.posn - card.seekFrac * card.len) < 1.5) {
                    card.seekArmed = false;
                    card.seekSent = false;
                    seekIgnore.stop();
                }
            }
        }
        Timer {
            id: seekDebounce
            interval: 300
            onTriggered: {
                if (card.player && card.len > 0) {
                    card.player.position = card.seekFrac * card.len;
                    card.seekSent = true;
                    seekIgnore.restart();
                } else {
                    card.seekArmed = false;
                }
            }
        }
        // The stream never reflected the seek inside the window, so trust it again.
        Timer {
            id: seekIgnore
            interval: 3000
            onTriggered: {
                card.seekArmed = false;
                card.seekSent = false;
            }
        }

        Column {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.paddingMd
            spacing: Theme.paddingSm

            // Title (dimmer variant tone) and artist, both centered.
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: card.player ? (card.player.trackTitle || "") : ""
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: card.player ? Theme.joinArtists(card.player.trackArtists, card.player.trackArtist) : ""
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
                font.weight: Font.Bold
                elide: Text.ElideRight
            }

            // Time + scrubber row: elapsed | slider | total, 20px each side.
            Item {
                width: parent.width
                height: scrubber.implicitHeight

                Text {
                    id: curTime
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.fmtTime(card.shownFrac * card.len)
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm
                }
                Text {
                    id: totTime
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.fmtTime(card.len)
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm
                }
                RevealerRowSlider {
                    id: scrubber
                    anchors.left: curTime.right
                    anchors.right: totTime.left
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    rightMargin: 0
                    enabled: card.player ? card.player.canSeek : false
                    value: card.shownFrac
                    onMoved: frac => card.onScrub(frac)
                }
            }

            // Centered transport row; each button dims to its capability.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                IconButton {
                    iconName: card.iconShuffle()
                    enabled: card.player ? card.player.shuffleSupported : false
                    onClicked: if (card.player) card.player.shuffle = !card.player.shuffle
                }
                IconButton {
                    iconName: "skip_previous"
                    enabled: card.player ? card.player.canGoPrevious : false
                    onClicked: if (card.player) card.player.previous()
                }
                IconButton {
                    iconName: (card.player && card.player.isPlaying) ? "pause" : "play_arrow"
                    enabled: card.player ? card.player.canTogglePlaying : false
                    onClicked: if (card.player) card.player.togglePlaying()
                }
                IconButton {
                    iconName: "skip_next"
                    enabled: card.player ? card.player.canGoNext : false
                    onClicked: if (card.player) card.player.next()
                }
                IconButton {
                    iconName: card.iconLoop()
                    enabled: card.player ? card.player.loopSupported : false
                    onClicked: card.cycleLoop()
                }
            }
        }
    }

    Column {
        id: content
        width: parent.width
        spacing: Theme.paddingMd

        // --- switcher header (only with more than one player) ---------------
        Item {
            id: switcher
            width: parent.width
            visible: root.players.length > 1
            height: visible ? Math.max(swName.implicitHeight, switchBtns.implicitHeight) : 0

            Text {
                id: swName
                anchors.left: parent.left
                anchors.right: switchBtns.left
                anchors.rightMargin: Theme.paddingMd
                anchors.verticalCenter: parent.verticalCenter
                text: root.player ? (root.player.identity.length > 0 ? root.player.identity : root.player.dbusName) : ""
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
                font.weight: Font.Bold
                elide: Text.ElideRight
            }
            Row {
                id: switchBtns
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingMd

                IconButton {
                    iconName: "chevron_left"
                    enabled: root.idx > 0
                    onClicked: if (root.idx > 0) root.picked = root.players[root.idx - 1]
                }
                IconButton {
                    iconName: "chevron_right"
                    enabled: root.idx >= 0 && root.idx + 1 < root.players.length
                    onClicked: if (root.idx >= 0 && root.idx + 1 < root.players.length) root.picked = root.players[root.idx + 1]
                }
            }
        }

        // --- the sliding card stack -----------------------------------------
        // A clipped viewport over a strip of per-player cards; switching player
        // slides the strip 200ms on the shared ease-out envelope (contract 06
        // sec 5: gtk::Stack SlideLeftRight, GTK ease-out).
        Item {
            id: viewport
            width: parent.width
            height: strip.implicitHeight
            clip: true

            Row {
                id: strip
                height: parent.height
                x: -Math.max(0, root.idx) * viewport.width
                Behavior on x {
                    NumberAnimation { duration: Motion.rowReveal; easing.type: Motion.rowRevealCurve }
                }

                Repeater {
                    model: root.players
                    delegate: MediaCard {
                        required property var modelData
                        required property int index
                        width: viewport.width
                        player: modelData
                        active: index === root.idx
                        cardOpen: root.open
                    }
                }
            }
        }
    }
}
