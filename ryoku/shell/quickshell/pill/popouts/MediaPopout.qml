pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../Singletons"

// media popout content: a compact now-playing transport that grows from the
// bar's media module on hover. an elapsed / total line (scrub-to-seek) over a
// prev / play-pause / next cluster. plain transparent Item -- the frame blob
// behind it IS the surface; Popout melts it open to the reported implicit size.
// MPRIS never pushes position, so poll it while open + playing to advance the
// fill and elapsed label (the pill Media.qml pattern); the poll stops with the
// popout so a closed panel costs nothing.
Item {
    id: root

    property real s: 1
    property bool open: false
    // rich mode gives the washi warp-surface an art + title header above the
    // transport (the pill warps into a full now-playing panel); the framed
    // skins keep the bare hover transport (rich stays false).
    property bool rich: false

    readonly property var player: Media.player
    readonly property bool playing: Media.playing
    // the live radio has no honest position: the panel swaps the time row for
    // a LIVE tally and retires the scrubber while it broadcasts.
    readonly property bool radio: Media.radio
    readonly property real pos: player ? player.position : 0
    readonly property real len: (player && player.length > 0) ? player.length : 0
    readonly property real frac: len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0
    readonly property bool canPrev: player ? player.canGoPrevious : false
    readonly property bool canNext: player ? player.canGoNext : false
    readonly property bool canSeek: (player ? player.canSeek : false) && len > 0 && !radio

    // scrub-to-seek: drag/click the line to preview a target (fill + elapsed
    // label follow the cursor), committed to player.position on release.
    property bool scrubbing: false
    property real scrubFrac: 0

    function fmt(sec) {
        if (!(sec > 0))
            return "0:00";
        var t = Math.floor(sec);
        var m = Math.floor(t / 60);
        var r = t % 60;
        return m + ":" + (r < 10 ? "0" + r : r);
    }

    anchors.fill: parent
    implicitWidth: (rich ? 330 : 220) * s
    implicitHeight: body.implicitHeight + 28 * s

    Timer {
        interval: 500
        running: root.open && root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged()
    }

    // one transport control: a Material glyph that lifts on hover, dims when the
    // player can't act on it. the accent one (play/pause) is the vermillion lead.
    component Btn: MouseArea {
        id: btn
        property string glyph
        property bool on: true
        property bool accent: false
        signal act()
        width: 30 * root.s
        height: 30 * root.s
        enabled: btn.on
        hoverEnabled: true
        cursorShape: btn.on ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: btn.act()
        MaterialIcon {
            anchors.centerIn: parent
            text: btn.glyph
            fill: 1
            color: !btn.on ? Theme.dim
                 : btn.accent ? (btn.containsMouse ? Theme.vermLit : Theme.brand)
                 : (btn.containsMouse ? Theme.bright : Theme.cream)
            font.pixelSize: (btn.accent ? 22 : 18) * root.s
            Behavior on color { ColorAnimation { duration: Motion.hover } }
        }
    }

    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 14 * root.s
        anchors.leftMargin: 16 * root.s
        anchors.rightMargin: 16 * root.s
        spacing: 9 * root.s
        // ---- rich header: art specimen + track lines (washi surface) ----
        Row {
            width: parent.width
            visible: root.rich
            spacing: 12 * root.s
            Rectangle {
                width: 52 * root.s
                height: 52 * root.s
                radius: 8 * root.s
                color: Qt.alpha(Theme.bright, 0.05)
                border.width: 1
                border.color: Theme.hair
                clip: true
                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: root.player ? (root.player.trackArtUrl || "") : ""
                    sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !root.player || !(root.player.trackArtUrl || "").length
                    text: "\u97f3"
                    color: Theme.iconDim
                    font.family: Theme.fontJp
                    font.pixelSize: 24 * root.s
                }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 52 * root.s - 12 * root.s
                spacing: 3 * root.s
                Text {
                    width: parent.width
                    text: root.player ? (root.player.trackTitle || "Nothing playing") : "Nothing playing"
                    color: Theme.cream
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 14 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: root.player ? Theme.joinArtists(root.player.trackArtists, root.player.trackArtist) : ""
                    color: Theme.dim
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                }
            }
        }


        Item {
            width: parent.width
            height: elapsed.implicitHeight
            Text {
                id: elapsed
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: root.radio ? "● LIVE" : root.fmt(root.scrubbing ? root.scrubFrac * root.len : root.pos)
                // dim, not faint: position/duration is information, and faint
                // drops below reading contrast on the wallust-matched surfaces.
                color: root.radio ? Theme.vermLit : Theme.dim
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                SequentialAnimation on opacity {
                    running: root.radio && root.open && root.playing
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
                    onStopped: elapsed.opacity = 1
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.radio ? "24/7" : root.fmt(root.len)
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
            }
        }

        Item {
            id: seek
            width: parent.width
            height: 12 * root.s
            // the drawn fill eases between the 500ms position polls so playback
            // advances smoothly; snaps to the cursor while scrubbing. A radio
            // stays flat: whatever length its buffer claims is not a position.
            property real drawFrac: root.radio ? 0 : (root.scrubbing ? root.scrubFrac : root.frac)
            Behavior on drawFrac { enabled: !root.scrubbing; NumberAnimation { duration: 480; easing.type: Easing.Linear } }

            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 3 * root.s
                color: Qt.alpha(Theme.bright, 0.14)
                Rectangle {
                    width: seek.drawFrac * track.width
                    height: parent.height
                    color: Theme.brand
                }
            }
            Rectangle {
                width: 8 * root.s
                height: 8 * root.s
                radius: width / 2
                color: Theme.brand
                visible: root.canSeek
                anchors.verticalCenter: parent.verticalCenter
                x: seek.drawFrac * track.width - width / 2
            }
            MouseArea {
                anchors.fill: parent
                enabled: root.canSeek
                cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                preventStealing: true
                function fracAt(x) { return Math.max(0, Math.min(1, x / track.width)); }
                onPressed: (m) => { root.scrubbing = true; root.scrubFrac = fracAt(m.x); }
                onPositionChanged: (m) => { if (root.scrubbing) root.scrubFrac = fracAt(m.x); }
                onReleased: (m) => { if (root.scrubbing && root.player) root.player.position = fracAt(m.x) * root.len; root.scrubbing = false; }
                onCanceled: root.scrubbing = false
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20 * root.s
            Btn { glyph: "skip_previous"; on: root.canPrev; onAct: if (root.player) root.player.previous() }
            Btn { glyph: root.playing ? "pause" : "play_arrow"; accent: true; on: root.player ? root.player.canTogglePlaying : false; onAct: if (root.player) root.player.togglePlaying() }
            Btn { glyph: "skip_next"; on: root.canNext; onAct: if (root.player) root.player.next() }
        }
    }
}
