import QtQuick
import QtMultimedia
import "Singletons"

// Live rice preview: the picked wallpaper under a recoloured pill, terminal and
// cava bars, all painted from the wallust scheme.
Item {
    id: mock
    clip: true

    readonly property real s: Math.max(0.7, height / 300)

    readonly property bool selVideo: !!(Wallhaven.selected && Wallhaven.selected.video && ("" + Wallhaven.selected.video).length > 0)
    readonly property bool selRemote: mock.selVideo && ("" + Wallhaven.selected.video).startsWith("http")
    // the preview auto-plays the selected clip so you see it move. a remote clip
    // re-streams on every loop, so after a while it pauses on the current frame:
    // you get the motion, but a clip left selected does not drain data forever.
    readonly property bool wantPreview: mock.selVideo
    Timer {
        interval: 15000
        running: mock.selRemote && liveMp.playbackState === MediaPlayer.PlayingState
        onTriggered: liveMp.pause()
    }

    readonly property color cBg:     Wallhaven.col(0, "#16140f")
    readonly property color cFg:     Wallhaven.col(15, Wallhaven.col(7, "#e8e8e8"))
    readonly property color cRed:    Wallhaven.col(1, "#c1564b")
    readonly property color cGreen:  Wallhaven.col(2, "#8a9a6b")
    readonly property color cYellow: Wallhaven.col(3, "#d6a85f")
    readonly property color cBlue:   Wallhaven.col(4, "#5a7a9a")
    readonly property color cMag:    Wallhaven.col(5, "#9a6f8a")
    readonly property color cCyan:   Wallhaven.col(6, "#6f9aa0")
    readonly property color cAccent: cBlue

    // wallpaper backdrop. a quick thumb shows instantly; the full image fades in
    // on top at a capped decode size, so the preview is crisp, never upscaled.
    Image {
        anchors.fill: parent
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(width), Math.ceil(height))
        source: Wallhaven.selected ? (Wallhaven.selected.large || Wallhaven.selected.thumb || "") : ""
    }
    Image {
        anchors.fill: parent
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(width * 2), Math.ceil(height * 2))
        source: Wallhaven.selected ? (Wallhaven.selected.path || "") : ""
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.medium } }
    }
    // graded overlay: when an Adjust edit is live, the engine renders the graded
    // image to a rotating temp slot and we show it on top, so the rice preview is
    // exactly what Set will bake. cache off + the rotating name force a reload.
    Image {
        anchors.fill: parent
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
        visible: Wallhaven.adjustActive && Wallhaven.adjustPreview.length > 0
        source: visible ? Wallhaven.adjustPreview : ""
    }

    // a live wallpaper loops as the backdrop instead of a still frame.
    MediaPlayer {
        id: liveMp
        source: mock.wantPreview ? Wallhaven.selected.video : ""
        loops: MediaPlayer.Infinite
        videoOutput: liveOut
        onSourceChanged: source != "" ? play() : stop()
    }
    VideoOutput {
        id: liveOut
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
        // keep the last frame up once a heavy clip pauses, instead of snapping back.
        visible: liveMp.playbackState === MediaPlayer.PlayingState || liveMp.playbackState === MediaPlayer.PausedState
    }

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.16) }

    // top pill, the shell island in miniature.
    Rectangle {
        id: pill
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 11 * mock.s
        width: parent.width * 0.66
        height: 24 * mock.s
        radius: height / 2
        color: Qt.rgba(mock.cBg.r, mock.cBg.g, mock.cBg.b, 0.82)
        border.width: 1
        border.color: Qt.alpha(mock.cFg, 0.14)
        Behavior on color { ColorAnimation { duration: Theme.medium } }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 12 * mock.s
            anchors.verticalCenter: parent.verticalCenter
            text: "力"
            color: mock.cAccent
            font.family: Theme.fontJp
            font.pixelSize: 13 * mock.s
            Behavior on color { ColorAnimation { duration: Theme.medium } }
        }
        Row {
            anchors.centerIn: parent
            spacing: 5 * mock.s
            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    width: (index === 1 ? 14 : 6) * mock.s
                    height: 6 * mock.s
                    radius: Theme.radius
                    color: index === 1 ? mock.cAccent : Qt.alpha(mock.cFg, 0.4)
                    Behavior on color { ColorAnimation { duration: Theme.medium } }
                }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 12 * mock.s
            anchors.verticalCenter: parent.verticalCenter
            text: "9:41"
            color: mock.cFg
            font.family: Theme.mono
            font.pixelSize: 10 * mock.s
            Behavior on color { ColorAnimation { duration: Theme.medium } }
        }
    }

    // terminal window.
    Rectangle {
        id: term
        anchors.left: parent.left
        anchors.leftMargin: 16 * mock.s
        anchors.top: pill.bottom
        anchors.topMargin: 14 * mock.s
        width: parent.width * 0.54
        height: parent.height * 0.46
        radius: Theme.radius
        color: Qt.rgba(mock.cBg.r, mock.cBg.g, mock.cBg.b, 0.92)
        border.width: 1
        border.color: Qt.alpha(mock.cFg, 0.16)
        Behavior on color { ColorAnimation { duration: Theme.medium } }

        Column {
            anchors.fill: parent
            anchors.margins: 11 * mock.s
            spacing: 6 * mock.s

            Row {
                spacing: 6 * mock.s
                Repeater {
                    model: [mock.cRed, mock.cYellow, mock.cGreen]
                    delegate: Rectangle {
                        required property var modelData
                        width: 8 * mock.s; height: 8 * mock.s; radius: 4 * mock.s
                        color: modelData
                        Behavior on color { ColorAnimation { duration: Theme.medium } }
                    }
                }
            }

            Row {
                spacing: 0
                Text { text: "ryoku"; color: mock.cGreen; font.family: Theme.mono; font.pixelSize: 11 * mock.s; font.weight: Font.DemiBold; Behavior on color { ColorAnimation { duration: Theme.medium } } }
                Text { text: "@arch"; color: mock.cMag; font.family: Theme.mono; font.pixelSize: 11 * mock.s; Behavior on color { ColorAnimation { duration: Theme.medium } } }
                Text { text: " ~ "; color: mock.cBlue; font.family: Theme.mono; font.pixelSize: 11 * mock.s; Behavior on color { ColorAnimation { duration: Theme.medium } } }
                Text { text: "❯ fastfetch"; color: mock.cFg; font.family: Theme.mono; font.pixelSize: 11 * mock.s; Behavior on color { ColorAnimation { duration: Theme.medium } } }
            }

            Repeater {
                model: ["OS    Ryoku Linux", "WM    Hyprland", "SH    fish"]
                delegate: Row {
                    required property var modelData
                    spacing: 0
                    Text { text: modelData.substring(0, 6); color: mock.cYellow; font.family: Theme.mono; font.pixelSize: 10 * mock.s; Behavior on color { ColorAnimation { duration: Theme.medium } } }
                    Text { text: modelData.substring(6); color: Qt.alpha(mock.cFg, 0.85); font.family: Theme.mono; font.pixelSize: 10 * mock.s; Behavior on color { ColorAnimation { duration: Theme.medium } } }
                }
            }

            // the scheme as a neofetch-style colour strip.
            Row {
                spacing: 3 * mock.s
                Repeater {
                    model: 8
                    delegate: Rectangle {
                        required property int index
                        width: 11 * mock.s; height: 9 * mock.s; radius: Theme.radius
                        color: Wallhaven.col(index + 1, Theme.surfaceLo)
                        Behavior on color { ColorAnimation { duration: Theme.medium } }
                    }
                }
            }
        }
    }

    // cava visualiser along the bottom.
    property var levels: []
    property real phase: 0

    function retick() {
        var n = 30;
        var arr = [];
        for (var i = 0; i < n; i++) {
            var base = Math.abs(Math.sin(mock.phase + i * 0.42));
            var jit = 0.55 + 0.45 * Math.random();
            arr.push(Math.max(0.06, base * jit));
        }
        mock.levels = arr;
        mock.phase += 0.35;
    }
    Component.onCompleted: retick()
    Timer { interval: 60; running: mock.visible; repeat: true; onTriggered: mock.retick() }

    Row {
        id: cava
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16 * mock.s
        anchors.rightMargin: 16 * mock.s
        anchors.bottomMargin: 12 * mock.s
        height: parent.height * 0.2
        spacing: 3 * mock.s

        Repeater {
            model: 30
            delegate: Item {
                required property int index
                width: (cava.width - 29 * cava.spacing) / 30
                height: cava.height
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    radius: width / 2
                    height: Math.max(2, parent.height * (mock.levels.length > index ? mock.levels[index] : 0.1))
                    Behavior on height { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: mock.cAccent }
                        GradientStop { position: 1.0; color: mock.cMag }
                    }
                }
            }
        }
    }
}
