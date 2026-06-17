import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import "Singletons"

Item {
    id: mpris

    property real s: 1

    readonly property var player: {
        var list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        var controllable = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p)
                continue;
            if (p.isPlaying)
                return p;
            if (!controllable && p.canControl)
                controllable = p;
        }
        return controllable ? controllable : list[0];
    }

    readonly property string label: {
        if (!player)
            return "";
        var artist = player.trackArtist ? player.trackArtist : "";
        var title = player.trackTitle ? player.trackTitle : "";
        if (artist.length > 0 && title.length > 0)
            return artist + " · " + title;
        if (title.length > 0)
            return title;
        if (artist.length > 0)
            return artist;
        return "";
    }

    readonly property real maxTextWidth: 170 * s

    visible: player !== null && label.length > 0
    implicitWidth: visible ? note.width + 7 * s + textClip.width : 0
    implicitHeight: 28 * s

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: {
            if (mpris.player && mpris.player.canTogglePlaying)
                mpris.player.togglePlaying();
        }
        onWheel: (wheel) => {
            if (!mpris.player)
                return;
            if (wheel.angleDelta.y > 0) {
                if (mpris.player.canGoPrevious)
                    mpris.player.previous();
            } else if (wheel.angleDelta.y < 0) {
                if (mpris.player.canGoNext)
                    mpris.player.next();
            }
        }
    }

    Image {
        id: noteSrc
        source: Qt.resolvedUrl("assets/icons/music.svg")
        sourceSize.width: 64
        sourceSize.height: 64
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: false
    }

    MultiEffect {
        id: note
        anchors.verticalCenter: parent.verticalCenter
        width: 15 * mpris.s
        height: 15 * mpris.s
        source: noteSrc
        colorization: 1.0
        colorizationColor: Theme.vermLit
    }

    Item {
        id: textClip
        anchors.left: note.right
        anchors.leftMargin: 7 * mpris.s
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        width: Math.min(scroller.textWidth, mpris.maxTextWidth)
        clip: true

        readonly property bool overflowing: scroller.textWidth > mpris.maxTextWidth

        Text {
            id: scroller
            anchors.verticalCenter: parent.verticalCenter
            x: 0
            text: mpris.label
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * mpris.s
            font.weight: Font.Medium
            elide: textClip.overflowing ? Text.ElideNone : Text.ElideRight
            width: textClip.overflowing ? implicitWidth : textClip.width

            readonly property real textWidth: implicitWidth

            SequentialAnimation {
                id: marquee
                running: textClip.overflowing && mpris.visible
                loops: Animation.Infinite
                PauseAnimation { duration: 1600 }
                NumberAnimation {
                    target: scroller
                    property: "x"
                    from: 0
                    to: -(scroller.textWidth - textClip.width)
                    duration: Math.max(1, (scroller.textWidth - textClip.width)) * 22
                    easing.type: Easing.InOutSine
                }
                PauseAnimation { duration: 1600 }
                NumberAnimation {
                    target: scroller
                    property: "x"
                    from: -(scroller.textWidth - textClip.width)
                    to: 0
                    duration: Math.max(1, (scroller.textWidth - textClip.width)) * 22
                    easing.type: Easing.InOutSine
                }
            }

            onTextChanged: {
                marquee.stop();
                x = 0;
                if (textClip.overflowing && mpris.visible)
                    marquee.start();
            }
        }
    }
}
