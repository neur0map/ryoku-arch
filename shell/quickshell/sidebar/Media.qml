import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import "Singletons"

Rectangle {
    id: root
    property real s: 1
    property bool opened: false

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

    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.isPlaying

    readonly property string trackTitle: {
        if (!player)
            return "";
        return player.trackTitle ? player.trackTitle : "";
    }
    readonly property string trackArtist: {
        if (!player)
            return "";
        if (player.trackArtists && player.trackArtists.length > 0)
            return player.trackArtists;
        return player.trackArtist ? player.trackArtist : "";
    }
    readonly property string artUrl: {
        if (!player)
            return "";
        return player.trackArtUrl ? player.trackArtUrl : "";
    }
    readonly property real lengthSec: hasPlayer && player.length > 0 ? player.length : 0
    readonly property real positionSec: hasPlayer ? player.position : 0

    function fmt(sec) {
        if (!(sec > 0))
            return "0:00";
        var t = Math.floor(sec);
        var m = Math.floor(t / 60);
        var ss = t % 60;
        return m + ":" + (ss < 10 ? "0" + ss : ss);
    }

    Timer {
        interval: 1000
        running: root.opened && root.playing
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged()
    }

    radius: 16 * s
    color: "transparent"
    border.width: 1
    border.color: Theme.border
    implicitHeight: col.implicitHeight
    clip: true
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.panelTop }
        GradientStop { position: 1.0; color: Theme.panelBot }
    }

    component TBtn: Item {
        property string icon: ""
        property real box: 20
        property color tint: Theme.subtle
        width: box * root.s; height: box * root.s
        signal clicked()
        Image {
            id: tImg
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/icons/" + icon + ".svg")
            sourceSize.width: 64; sourceSize.height: 64
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true; visible: false
        }
        MultiEffect {
            anchors.fill: tImg
            source: tImg
            colorization: 1.0
            colorizationColor: tint
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    Column {
        id: col
        width: parent.width

        Row {
            width: parent.width
            leftPadding: 14 * root.s
            rightPadding: 14 * root.s
            topPadding: 14 * root.s
            bottomPadding: 14 * root.s
            spacing: 13 * root.s

            Rectangle {
                id: art
                width: 76 * root.s; height: 76 * root.s; radius: 12 * root.s
                clip: true
                border.width: 1
                border.color: Theme.border
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#3a2118" }
                    GradientStop { position: 1.0; color: "#1c1410" }
                }
                Rectangle {
                    anchors.centerIn: parent
                    visible: root.artUrl.length === 0
                    width: 22 * root.s; height: 22 * root.s; radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(230/255, 214/255, 203/255, 0.22)
                }
                Image {
                    id: artImg
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: root.artUrl.length > 0
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    mipmap: true
                    cache: false
                    asynchronous: true
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: artMask
                    }
                }
                Item {
                    id: artMask
                    anchors.fill: parent
                    anchors.margins: 1
                    layer.enabled: true
                    visible: false
                    Rectangle {
                        anchors.fill: parent
                        radius: 11 * root.s
                    }
                }
            }

            Column {
                width: parent.width - 76 * root.s - 13 * root.s - 28 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2 * root.s
                Text {
                    text: "Now Playing"
                    color: root.hasPlayer ? Theme.vermLit : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.5 * root.s
                    bottomPadding: 5 * root.s
                }
                Text {
                    width: parent.width
                    text: root.hasPlayer ? (root.trackTitle.length > 0 ? root.trackTitle : "Unknown") : "Nothing playing"
                    color: root.hasPlayer ? Theme.cream : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 14 * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: root.trackArtist.length > 0
                    text: root.trackArtist
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }
        }

        Column {
            width: parent.width
            leftPadding: 14 * root.s
            rightPadding: 14 * root.s
            bottomPadding: 4 * root.s
            spacing: 7 * root.s

            Rectangle {
                width: parent.width - 28 * root.s
                height: 4 * root.s
                radius: 99
                color: Theme.trackBg
                Rectangle {
                    width: parent.width * (root.lengthSec > 0 ? Math.max(0, Math.min(1, root.positionSec / root.lengthSec)) : 0)
                    height: parent.height
                    radius: 99
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.verm }
                        GradientStop { position: 1.0; color: Theme.vermLit }
                    }
                }
            }
            Item {
                width: parent.width - 28 * root.s
                implicitHeight: 12 * root.s
                Text {
                    anchors.left: parent.left
                    text: root.fmt(root.positionSec)
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.right: parent.right
                    text: root.fmt(root.lengthSec)
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                }
            }
        }

        Item {
            width: parent.width
            implicitHeight: 42 * root.s + 24 * root.s

            Row {
                anchors.centerIn: parent
                spacing: 18 * root.s

                TBtn {
                    icon: "prev"
                    box: 20
                    tint: root.hasPlayer && root.player.canGoPrevious ? Theme.subtle : Theme.disabled
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 42 * root.s; height: 42 * root.s; radius: width / 2
                    opacity: root.hasPlayer ? 1 : 0.45
                    border.width: 1
                    border.color: Theme.vermLit
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.vermLit }
                        GradientStop { position: 1.0; color: Theme.verm }
                    }
                    Image {
                        id: playImg
                        anchors.centerIn: parent
                        width: 18 * root.s; height: 18 * root.s
                        source: Qt.resolvedUrl("assets/icons/" + (root.playing ? "pause" : "play") + ".svg")
                        sourceSize.width: 64; sourceSize.height: 64
                        fillMode: Image.PreserveAspectFit
                        smooth: true; mipmap: true; visible: false
                    }
                    MultiEffect {
                        anchors.fill: playImg
                        source: playImg
                        colorization: 1.0
                        colorizationColor: Theme.onAccent
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
                    }
                }
                TBtn {
                    icon: "next"
                    box: 20
                    tint: root.hasPlayer && root.player.canGoNext ? Theme.subtle : Theme.disabled
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: if (root.player && root.player.canGoNext) root.player.next()
                }
            }
        }
    }
}
