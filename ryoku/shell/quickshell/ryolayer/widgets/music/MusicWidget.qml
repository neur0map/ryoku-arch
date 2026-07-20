pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The layer's sound-out instrument: MPRIS transport (reverse / play-pause /
// skip), a seekable position rail, the track sheet, art as a framed specimen,
// and the equalizer drawer below (EqPanel). Art keeps its own colour: album
// covers are data, not chrome (docs/ui-ux.md).
Item {
    id: music

    property var slot: null
    property bool active: false

    property var player: Players.active
    // chip-picked override; cleared when that player vanishes.
    property var picked: null
    readonly property var shown: picked && Players.list.indexOf(picked) !== -1 ? picked : player

    // position poll, gated: only while shown playing and the slot is live.
    property real posn: 0
    Timer {
        interval: 1000
        running: music.active && music.shown && music.shown.isPlaying
        repeat: true
        triggeredOnStart: true
        onTriggered: music.posn = music.shown.position
    }

    function fmt(s) {
        s = Math.max(0, Math.round(s));
        var m = Math.floor(s / 60);
        var r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    Column {
        anchors.fill: parent
        spacing: Tokens.s3

        // ── player chips, only when there is a choice ────────────────────
        Row {
            spacing: Tokens.s1
            visible: Players.list.length > 1
            Repeater {
                model: Players.list
                delegate: Rectangle {
                    id: pchip
                    required property var modelData
                    readonly property bool current: modelData === music.shown
                    width: pt.implicitWidth + Tokens.s2 * 2
                    height: Tokens.ctlH - 6
                    radius: Tokens.radius
                    color: current ? Tokens.bone : "transparent"
                    border { width: Tokens.border; color: current ? Tokens.bone : Tokens.line }
                    Text {
                        id: pt
                        anchors.centerIn: parent
                        text: pchip.modelData.identity || pchip.modelData.dbusName
                        color: pchip.current ? Tokens.inkOnBone : Tokens.inkFaint
                        font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
                    }
                    TapHandler { onTapped: music.picked = pchip.modelData }
                }
            }
        }

        // ── the sheet: art specimen + track lines ────────────────────────
        Row {
            width: parent.width
            spacing: Tokens.s4

            Item {
                id: artFrame
                width: 84; height: 84
                Rectangle { anchors.fill: parent; color: Tokens.paperLift; border { width: Tokens.border; color: Tokens.line } }
                Image {
                    anchors { fill: parent; margins: Tokens.border }
                    source: music.shown ? (music.shown.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !music.shown || !music.shown.trackArtUrl
                    text: "\u97f3"
                    color: Tokens.inkFaint
                    font { family: Tokens.jp; pixelSize: Tokens.fHero }
                }
                Ticks { anchors.fill: parent }
            }

            Column {
                width: parent.width - artFrame.width - Tokens.s4
                anchors.verticalCenter: artFrame.verticalCenter
                spacing: Tokens.s1
                Text {
                    width: parent.width
                    text: music.shown ? (music.shown.trackTitle || "Nothing playing") : "Nothing playing"
                    color: Tokens.ink
                    elide: Text.ElideRight
                    font { family: Tokens.ui; pixelSize: Tokens.fRow; weight: Font.DemiBold }
                }
                Text {
                    width: parent.width
                    text: music.shown ? (music.shown.trackArtist || "") : ""
                    color: Tokens.inkMuted
                    elide: Text.ElideRight
                    font { family: Tokens.ui; pixelSize: Tokens.fSmall }
                }
                Text {
                    visible: music.shown && music.shown.length > 0
                    text: music.shown ? music.fmt(music.posn) + " / " + music.fmt(music.shown.length) : ""
                    color: Tokens.inkFaint
                    font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
                }
            }
        }

        // ── seek rail ────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: Tokens.s3
            visible: music.shown !== null
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: Tokens.border
                color: Tokens.line
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: music.shown && music.shown.length > 0 ? parent.width * Math.min(1, music.posn / music.shown.length) : 0
                height: 2
                color: Tokens.ink
            }
            MouseArea {
                anchors.fill: parent
                enabled: music.shown && music.shown.canSeek
                onClicked: (e) => {
                    var t = (e.x / width) * music.shown.length;
                    music.shown.position = t;
                    music.posn = t;
                }
            }
        }

        // ── transport ────────────────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Tokens.s4

            component TransportBtn: Rectangle {
                id: tbtn
                property string label: ""
                property bool big: false
                property bool enabledBtn: true
                signal pressed()
                width: big ? Tokens.rowH : Tokens.ctlH + 8
                height: width
                radius: width / 2
                color: tHover.hovered && enabledBtn ? Tokens.tint10 : "transparent"
                border { width: Tokens.border; color: big ? Tokens.lineStrong : Tokens.line }
                opacity: enabledBtn ? 1 : 0.35
                Text {
                    anchors.centerIn: parent
                    text: tbtn.label
                    color: Tokens.ink
                    font { family: Tokens.ui; pixelSize: tbtn.big ? Tokens.fRow : Tokens.fSmall }
                }
                HoverHandler { id: tHover }
                TapHandler { enabled: tbtn.enabledBtn; onTapped: tbtn.pressed() }
                Behavior on color { ColorAnimation { duration: Motion.fast } }
            }

            TransportBtn {
                label: "\u23ee"
                enabledBtn: music.shown && music.shown.canGoPrevious
                onPressed: music.shown.previous()
            }
            TransportBtn {
                big: true
                label: music.shown && music.shown.isPlaying ? "\u23f8" : "\u25b6"
                enabledBtn: music.shown && music.shown.canTogglePlaying
                onPressed: music.shown.togglePlaying()
            }
            TransportBtn {
                label: "\u23ed"
                enabledBtn: music.shown && music.shown.canGoNext
                onPressed: music.shown.next()
            }
        }

        EqPanel {
            width: parent.width
            activeFeed: music.active && music.shown && music.shown.isPlaying
            onImplicitHeightChanged: if (music.slot) music.slot.requestHeight(implicitHeight + 320)
        }
    }
}
