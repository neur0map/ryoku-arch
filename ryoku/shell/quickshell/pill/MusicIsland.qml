pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import "Singletons"

Item {
    id: root

    property real s: 1
    property bool live: true
    property bool open: false
    property real reveal: 0
    readonly property bool hovered: hover.hovered

    containmentMask: QtObject {
        function contains(point: point) : bool {
            return root.insideRounded(point.x, point.y, root.width, root.height, root.height / 2);
        }
    }

    signal activated()

    readonly property var player: {
        var list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (p && p.isPlaying)
                return p;
        }
        return null;
    }
    readonly property bool playing: player !== null && player.isPlaying
    readonly property bool controlsOpen: hovered && playing && reveal > 0.98
    readonly property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""

    width: (controlsOpen ? 136 : 74) * s
    height: 34 * s
    visible: open && reveal > 0.01
    opacity: 1
    clip: true

    onPlayingChanged: {
        AudioBars.active = playing;
        revealAnim.to = playing ? 1 : 0;
        revealAnim.duration = playing ? 420 : 320;
        revealAnim.restart();
    }
    Component.onCompleted: {
        AudioBars.active = playing;
        reveal = playing ? 1 : 0;
    }
    Component.onDestruction: AudioBars.active = false

    NumberAnimation {
        id: revealAnim
        target: root
        property: "reveal"
        easing.type: Easing.OutCubic
    }

    function insideRounded(px, py, w, h, r) {
        if (px < 0 || py < 0 || px > w || py > h)
            return false;
        var rr = Math.max(0, Math.min(r, w / 2, h / 2));
        var cx = px < rr ? rr : (px > w - rr ? w - rr : px);
        var cy = py < rr ? rr : (py > h - rr ? h - rr : py);
        var dx = px - cx;
        var dy = py - cy;
        return dx * dx + dy * dy <= rr * rr + 0.01;
    }

    Behavior on width {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Item {
        anchors.fill: parent
        clip: true
        opacity: Math.max(0, Math.min(1, (root.reveal - 0.4) / 0.4))

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 9 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7 * root.s

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 24 * root.s
                height: 24 * root.s
                radius: 6 * root.s
                clip: true
                color: Theme.tileBg

                Image {
                    id: art
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    text: "力"
                    color: Theme.brand
                    font.family: Theme.fontJp
                    font.pixelSize: 13 * root.s
                    font.weight: Font.Medium
                }
            }

            Item {
                id: bars
                anchors.verticalCenter: parent.verticalCenter
                width: 31 * root.s
                height: 20 * root.s

                Repeater {
                    model: 6
                    Rectangle {
                        required property int index
                        readonly property real v: index === 0 ? AudioBars.b0
                            : (index === 1 ? AudioBars.b1
                            : (index === 2 ? AudioBars.b2
                            : (index === 3 ? AudioBars.b3
                            : (index === 4 ? AudioBars.b4 : AudioBars.b5))))
                        readonly property real halfH: Math.max(1.2 * root.s, bars.height * 0.5 * v)

                        x: index * 5.2 * root.s
                        width: 3 * root.s
                        radius: width / 2
                        y: bars.height / 2 - halfH
                        height: halfH * 2
                        color: index === 0 || index === 5 ? Theme.dim
                            : (index === 1 || index === 4 ? Theme.brand : Theme.flameGlow)
                        opacity: root.playing ? 1 : 0.35

                        Behavior on height { NumberAnimation { duration: 70; easing.type: Easing.Linear } }
                        Behavior on y { NumberAnimation { duration: 70; easing.type: Easing.Linear } }
                        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                    }
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.controlsOpen
                spacing: 2 * root.s
                opacity: root.controlsOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                component MusicButton: Rectangle {
                    id: button
                    property string label: ""
                    signal pressed()
                    width: 18 * root.s
                    height: 18 * root.s
                    radius: width / 2
                    color: buttonHover.hovered ? Qt.alpha(Theme.brand, 0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Text {
                        anchors.centerIn: parent
                        text: button.label
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 11 * root.s
                        font.weight: Font.Bold
                    }
                    HoverHandler { id: buttonHover }
                    TapHandler { onTapped: button.pressed() }
                }

                MusicButton { label: "‹"; onPressed: if (root.player && root.player.canGoPrevious) root.player.previous() }
                MusicButton { label: root.playing ? "Ⅱ" : "▶"; onPressed: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying() }
                MusicButton { label: "›"; onPressed: if (root.player && root.player.canGoNext) root.player.next() }
            }
        }
    }

    HoverHandler {
        id: hover
        enabled: root.live && root.playing
        cursorShape: root.controlsOpen ? Qt.ArrowCursor : Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.live && root.playing && !root.controlsOpen
        onTapped: root.activated()
    }
}
