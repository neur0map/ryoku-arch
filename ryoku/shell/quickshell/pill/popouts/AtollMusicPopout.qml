pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Singletons"
import ".."

// atoll music popout content: ilyamiro's MusicPopup ported as transparent
// content on Ryoku's frame blob (the blob is the panel background, so the outer
// window/border/blur/orbit chrome is dropped). a spinning vinyl cover, the
// track sheet, a seekable rail with times, transport, then the 10-band EQ.
//
// the EQ is real DSP: there is no Eq singleton in the pill and ryolayer's Eq is
// a different quickshell config's module, so this replicates Eq.qml's protocol
// verbatim, gains persisted to ~/.config/ryoku/eq.json (this is the writer),
// live drags streamed to the running filter-chain over `ryoku-eq set` throttled
// to one process per 50ms, `ryoku-eq apply` on the enable toggle.
Item {
    id: root

    property real s: 1
    property bool open: false

    // ---- media (the pill Media.qml pattern, mirrors MediaPopout) ----
    readonly property var player: Media.player
    readonly property bool playing: Media.playing
    // a live radio has no honest position: swap the time row for a LIVE tally
    // and retire the scrubber while it broadcasts.
    readonly property bool radio: Media.radio
    readonly property real pos: player ? player.position : 0
    readonly property real len: (player && player.length > 0) ? player.length : 0
    readonly property real frac: len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0
    readonly property bool canPrev: player ? player.canGoPrevious : false
    readonly property bool canNext: player ? player.canGoNext : false
    readonly property bool canSeek: (player ? player.canSeek : false) && len > 0 && !radio

    // scrub-to-seek: drag/click the rail to preview a target, committed to
    // player.position on release.
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
    implicitWidth: 560 * s
    implicitHeight: body.implicitHeight + 40 * s

    // MPRIS never pushes position; poll it while open + playing so the rail fill
    // and elapsed label advance. the poll stops with the popout (open gate).
    Timer {
        interval: 500
        running: root.open && root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged()
    }

    // ======================================================================
    // EQ backend: replicates ryolayer Singletons/Eq.qml (same eq.json + ryoku-eq
    // protocol) so the faders are real DSP without depending on that module.
    // ======================================================================
    readonly property var eqPresetOrder: ["flat", "bass", "treble", "vocal", "pop", "rock", "jazz", "classic"]
    readonly property var eqPresets: ({
        flat:    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        bass:    [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
        treble:  [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6],
        vocal:   [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
        pop:     [2, 4, 2, 0, 1, 2, 4, 2, 1, 2],
        rock:    [5, 4, 2, -1, -2, -1, 2, 4, 5, 6],
        jazz:    [3, 3, 1, 1, 1, 1, 2, 1, 2, 3],
        classic: [0, 1, 2, 2, 2, 2, 1, 2, 3, 4]
    })
    readonly property var eqBands: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

    property alias eqEnabled: eqAdapter.enabled
    property alias eqPreset: eqAdapter.preset
    property alias eqGains: eqAdapter.gains

    FileView {
        id: eqFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/eq.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        JsonAdapter {
            id: eqAdapter
            property bool enabled: false
            property string preset: "flat"
            property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        }
    }

    function eqSave() { eqFile.writeAdapter(); }

    function eqSetEnabled(on) {
        root.eqEnabled = on;
        eqSave();
        Quickshell.execDetached(["ryoku-eq", "apply"]);
    }

    // live path: remember the latest value per band, flush on a short clock so a
    // fader sweep is one process every 50ms; the json write lands on release.
    property int _pendBand: -1
    property real _pendDb: 0
    Timer {
        id: eqFlush
        interval: 50
        onTriggered: {
            if (root._pendBand < 0)
                return;
            Quickshell.execDetached(["ryoku-eq", "set", String(root._pendBand + 1), root._pendDb.toFixed(1)]);
            root._pendBand = -1;
        }
    }

    function eqSetBand(i, db) {
        db = Math.max(-12, Math.min(12, db));
        var g = (root.eqGains || []).slice();
        while (g.length < 10)
            g.push(0);
        g[i] = Math.round(db * 10) / 10;
        root.eqGains = g;
        root.eqPreset = "custom";
        if (root.eqEnabled) {
            root._pendBand = i;
            root._pendDb = g[i];
            if (!eqFlush.running)
                eqFlush.start();
        }
    }

    function eqApplyPreset(name) {
        var p = root.eqPresets[name];
        if (!p)
            return;
        root.eqGains = p.slice();
        root.eqPreset = name;
        eqSave();
        if (root.eqEnabled)
            for (var i = 0; i < 10; i++)
                Quickshell.execDetached(["ryoku-eq", "set", String(i + 1), p[i].toFixed(1)]);
    }

    // one transport control: a Material glyph that lifts on hover, dims when the
    // player can't act on it. the accent one (play/pause) is the vermillion lead
    // (the popout's single warm signature moment).
    component Btn: MouseArea {
        id: btn
        property string glyph
        property bool on: true
        property bool accent: false
        signal act()
        width: (accent ? 44 : 32) * root.s
        height: (accent ? 44 : 32) * root.s
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
            font.pixelSize: (btn.accent ? 30 : 22) * root.s
            Behavior on color { ColorAnimation { duration: Motion.hover } }
        }
    }

    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 * root.s
        anchors.leftMargin: 20 * root.s
        anchors.rightMargin: 20 * root.s
        spacing: 18 * root.s

        // ---- top: vinyl cover + track sheet with rail + transport ----
        Row {
            width: parent.width
            spacing: 24 * root.s

            // circular cover as a spinning vinyl: the disc turns while playing
            // (paused otherwise), a dark spindle hole at the centre. album art
            // keeps its own colour, covers are data, not chrome.
            Item {
                id: cover
                width: 180 * root.s
                height: 180 * root.s

                Rectangle {
                    id: disc
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.cardTop
                    border.width: 3 * root.s
                    border.color: root.playing ? Theme.bright : Theme.hair
                    Behavior on border.color { ColorAnimation { duration: 400 } }

                    // static fallback when there is no art
                    MaterialIcon {
                        anchors.centerIn: parent
                        visible: !root.player || art.status !== Image.Ready
                        text: "music_note"
                        fill: 1
                        color: Theme.iconDim
                        font.pixelSize: 52 * root.s
                    }

                    // rotating leaf: the masked art + the vinyl hole spin together
                    Item {
                        id: spin
                        anchors.fill: parent
                        anchors.margins: 3 * root.s

                        Image {
                            id: art
                            anchors.fill: parent
                            source: root.player ? (root.player.trackArtUrl || "") : ""
                            sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: false
                        }
                        Rectangle {
                            id: artMask
                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                            layer.enabled: true
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: art
                            maskEnabled: true
                            maskSource: artMask
                            visible: art.status === Image.Ready
                        }

                        // vinyl spindle hole
                        Rectangle {
                            anchors.centerIn: parent
                            width: 34 * root.s
                            height: 34 * root.s
                            radius: width / 2
                            color: Theme.paper
                            border.width: 1
                            border.color: Theme.hair
                            Rectangle {
                                anchors.centerIn: parent
                                width: 6 * root.s
                                height: 6 * root.s
                                radius: width / 2
                                color: Theme.bright
                            }
                        }

                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 8000
                            loops: Animation.Infinite
                            running: root.open
                            paused: !root.playing
                        }
                    }
                }
            }

            // track sheet: title / artist / source, then rail + times + transport
            Column {
                id: info
                width: parent.width - cover.width - 24 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12 * root.s

                Marquee {
                    width: parent.width
                    text: root.player ? (root.player.trackTitle || "Nothing playing") : "Nothing playing"
                    color: Theme.bright
                    pixelSize: 20 * root.s
                    weight: Font.Bold
                    active: root.open
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: {
                        var a = root.player ? Theme.joinArtists(root.player.trackArtists, root.player.trackArtist) : "";
                        return a.length > 0 ? "BY " + a.toUpperCase() : "";
                    }
                    color: Theme.dim
                    elide: Text.ElideRight
                    font.family: Theme.mono
                    font.pixelSize: 12 * root.s
                    font.weight: Font.DemiBold
                }

                // source: the audio output device chip + the player it plays via
                Row {
                    width: parent.width
                    spacing: 6 * root.s
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Audio.nodeIcon(Audio.sink)
                        fill: 1
                        color: Theme.dim
                        font.pixelSize: 13 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, info.width * 0.5)
                        text: Audio.nodeLabel(Audio.sink)
                        color: Theme.subtle
                        elide: Text.ElideRight
                        font.family: Theme.mono
                        font.pixelSize: 11 * root.s
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, info.width * 0.42)
                        text: root.radio ? "· LIVE"
                            : (root.player && (root.player.identity || root.player.dbusName))
                              ? "· VIA " + (root.player.identity || root.player.dbusName) : ""
                        color: root.radio ? Theme.vermLit : Theme.faint
                        elide: Text.ElideRight
                        font.family: Theme.mono
                        font.italic: !root.radio
                        font.pixelSize: 11 * root.s
                    }
                }

                // times row
                Item {
                    width: parent.width
                    height: elapsed.implicitHeight
                    Text {
                        id: elapsed
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.radio ? "● LIVE" : root.fmt(root.scrubbing ? root.scrubFrac * root.len : root.pos)
                        color: root.radio ? Theme.vermLit : Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 11 * root.s
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.radio ? "24/7" : root.fmt(root.len)
                        color: Theme.dim
                        font.family: Theme.mono
                        font.pixelSize: 11 * root.s
                    }
                }

                // seek rail: fill eases between the 500ms polls, snaps to cursor
                // while scrubbing; a radio stays flat (its buffer length is not a
                // position).
                Item {
                    id: seek
                    width: parent.width
                    height: 12 * root.s
                    property real drawFrac: root.radio ? 0 : (root.scrubbing ? root.scrubFrac : root.frac)
                    Behavior on drawFrac { enabled: !root.scrubbing; NumberAnimation { duration: 480; easing.type: Easing.Linear } }

                    Rectangle {
                        id: railTrack
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: 3 * root.s
                        color: Qt.alpha(Theme.bright, 0.14)
                        Rectangle {
                            width: seek.drawFrac * railTrack.width
                            height: parent.height
                            color: Theme.brand
                        }
                    }
                    Rectangle {
                        width: 10 * root.s
                        height: 10 * root.s
                        radius: width / 2
                        color: Theme.brand
                        visible: root.canSeek
                        anchors.verticalCenter: parent.verticalCenter
                        x: seek.drawFrac * railTrack.width - width / 2
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.canSeek
                        cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                        preventStealing: true
                        function fracAt(x) { return Math.max(0, Math.min(1, x / railTrack.width)); }
                        onPressed: (m) => { root.scrubbing = true; root.scrubFrac = fracAt(m.x); }
                        onPositionChanged: (m) => { if (root.scrubbing) root.scrubFrac = fracAt(m.x); }
                        onReleased: (m) => { if (root.scrubbing && root.player) root.player.position = fracAt(m.x) * root.len; root.scrubbing = false; }
                        onCanceled: root.scrubbing = false
                    }
                }

                // transport
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 22 * root.s
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "skip_previous"
                        on: root.canPrev
                        onAct: if (root.player) root.player.previous()
                    }
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: root.playing ? "pause" : "play_arrow"
                        accent: true
                        on: root.player ? root.player.canTogglePlaying : false
                        onAct: if (root.player) root.player.togglePlaying()
                    }
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "skip_next"
                        on: root.canNext
                        onAct: if (root.player) root.player.next()
                    }
                }
            }
        }

        // ---- separator ----
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hair
        }

        // ======================================================================
        // EQUALIZER
        // ======================================================================
        Column {
            width: parent.width
            spacing: 16 * root.s

            // header: enable toggle + label, current preset name at the right
            Item {
                width: parent.width
                height: 24 * root.s
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10 * root.s
                    LinkToggle {
                        anchors.verticalCenter: parent.verticalCenter
                        s: root.s
                        on: root.eqEnabled
                        onToggled: root.eqSetEnabled(!root.eqEnabled)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "EQUALIZER"
                        color: root.eqEnabled ? Theme.bright : Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 13 * root.s
                        font.weight: Font.DemiBold
                        font.letterSpacing: 2
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: String(root.eqPreset || "flat").toUpperCase()
                    color: root.eqEnabled ? Theme.cream : Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 11 * root.s
                }
            }

            // ten vertical faders, -12..+12 dB. drag a knob to set a band; the
            // knob y maps the live gain from eq.json (so an external write or a
            // preset moves them too). dimmed + inert while the EQ is off.
            Item {
                id: eqField
                width: parent.width
                height: 168 * root.s
                visible: root.eqEnabled

                Row {
                    anchors.fill: parent
                    Repeater {
                        model: 10
                        delegate: Item {
                            id: band
                            required property int index
                            width: eqField.width / 10
                            height: eqField.height

                            readonly property real db: (root.eqGains && root.eqGains.length > index) ? root.eqGains[index] : 0
                            readonly property real labelH: 16 * root.s
                            readonly property real knobH: 8 * root.s
                            // dB -> y: +12 at the top of the run, -12 at the bottom.
                            readonly property real run: height - labelH - knobH
                            readonly property real knobCenter: (1 - (db + 12) / 24) * run + knobH / 2
                            readonly property real zeroCenter: 0.5 * run + knobH / 2

                            // rail
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: band.labelH
                                width: 2 * root.s
                                color: Theme.border
                            }
                            // 0 dB tick
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 14 * root.s
                                height: 1
                                y: band.zeroCenter - 0.5
                                color: Theme.hair
                            }
                            // deviation fill from 0 dB to the knob (bone accent)
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 2 * root.s
                                color: Qt.alpha(Theme.bright, root.eqEnabled ? 0.55 : 0.2)
                                y: Math.min(band.knobCenter, band.zeroCenter)
                                height: Math.abs(band.knobCenter - band.zeroCenter)
                            }
                            // knob
                            Rectangle {
                                id: knob
                                width: 26 * root.s
                                height: band.knobH
                                radius: 3 * root.s
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: (1 - (band.db + 12) / 24) * band.run
                                color: root.eqEnabled ? Theme.bright : Theme.faint
                                border.width: 1
                                border.color: Theme.paper
                                Behavior on y { enabled: !dragArea.pressed; NumberAnimation { duration: 240; easing.type: Easing.OutQuart } }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                anchors.bottomMargin: band.labelH + band.knobH
                                enabled: root.eqEnabled
                                cursorShape: root.eqEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                preventStealing: true
                                function push(yPos) {
                                    var f = Math.max(0, Math.min(1, yPos / band.run));
                                    root.eqSetBand(band.index, (1 - f) * 24 - 12);
                                }
                                onPressed: (m) => push(m.y)
                                onPositionChanged: (m) => { if (pressed) push(m.y); }
                                onReleased: root.eqSave()
                            }

                            Text {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root.eqBands[band.index]
                                color: root.eqEnabled ? Theme.dim : Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: 10 * root.s
                            }
                        }
                    }
                }
            }

            // preset chips: active = bone inversion (bone fill, dark ink).
            Grid {
                width: parent.width
                columns: 4
                rowSpacing: 8 * root.s
                columnSpacing: 8 * root.s
                visible: root.eqEnabled
                Repeater {
                    model: root.eqPresetOrder
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        readonly property bool current: root.eqPreset === modelData
                        width: (parent.width - 3 * 8 * root.s) / 4
                        height: 30 * root.s
                        radius: Theme.radius
                        color: chip.current ? Theme.bright : Theme.tileBg
                        border.width: 1
                        border.color: chip.current ? Theme.bright : Theme.hair
                        opacity: root.eqEnabled ? 1 : 0.4
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Text {
                            anchors.centerIn: parent
                            text: chip.modelData.toUpperCase()
                            color: chip.current ? Theme.paper : Theme.subtle
                            font.family: Theme.mono
                            font.pixelSize: 11 * root.s
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: root.eqEnabled
                            cursorShape: root.eqEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: root.eqApplyPreset(chip.modelData)
                        }
                    }
                }
            }
        }
    }
}
