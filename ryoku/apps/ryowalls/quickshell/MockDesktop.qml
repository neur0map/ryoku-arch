import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons
import "Singletons"
import Ryoku.FrameBars

// The selected wallpaper under the user's live look, recoloured by the
// candidate palette. The frame-bar preview follows shell.json; the
// terminal keeps its fastfetch card and colour strip, and cava keeps its motion.
Item {
    id: mock
    clip: true

    readonly property real s: Math.max(0.7, height / 300)

    readonly property bool selVideo: !!(Wallhaven.selected && Wallhaven.selected.video && ("" + Wallhaven.selected.video).length > 0)
    readonly property bool selRemote: mock.selVideo && ("" + Wallhaven.selected.video).startsWith("http")
    // the preview auto-plays the selected clip so you see it move. a remote clip
    // re-streams on every loop, so after 15s it pauses on the current frame: you
    // get the motion, but a clip left selected does not drain data forever.
    readonly property bool wantPreview: mock.selVideo
    Timer {
        interval: 15000
        running: mock.selRemote && liveMp.playbackState === MediaPlayer.PlayingState
        onTriggered: liveMp.pause()
    }

    // the candidate scheme, read straight off the live palette with graceful
    // fallbacks so the mock is never blank while the palette loads.
    readonly property color cBg:     Wallhaven.col(0, "#101010")
    readonly property color cFg:     Wallhaven.col(15, Wallhaven.col(7, "#e8e8e8"))
    readonly property color cRed:    Wallhaven.col(1, "#c1564b")
    readonly property color cGreen:  Wallhaven.col(2, "#8a9a6b")
    readonly property color cYellow: Wallhaven.col(3, "#d6a85f")
    readonly property color cBlue:   Wallhaven.col(4, "#5a7a9a")
    readonly property color cMag:    Wallhaven.col(5, "#9a6f8a")

    FileView {
        id: shellCfg
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: shell
            property var frameBars: FrameBars.defaultConfig()
        }
    }

    readonly property var frameBars: FrameBars.normalize(shell.frameBars, BarCatalog, MenuCatalog)
    function railThickness(edge) { return frameBars.rails[edge].size * mock.s; }
    function railMaterial() {
        return frameBars.style === "ryoku-frame"
            ? Qt.rgba(cBg.r, cBg.g, cBg.b, 0.92)
            : Qt.rgba(cBg.r, cBg.g, cBg.b, 0.76);
    }

    // the user's real visualizer config, so the mock's cava is their cava (bars,
    // shape, mirror, position) and not a generic meter. Recoloured by candidate.
    FileView {
        id: vizCfg
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/visualizer.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: viz
            property bool enabled: true
            property real bars: 64
            property string shape: "rounded"
            property bool mirror: false
            property string position: "bottom"
            property real height: 0.42
            property real reflection: 0.1
        }
    }

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
        Behavior on opacity { NumberAnimation { duration: Tokens.swap } }
    }
    // graded overlay: an Adjust edit renders to a rotating temp slot and shows on
    // top, so the rice preview is exactly what Set will bake.
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
        visible: liveMp.playbackState === MediaPlayer.PlayingState || liveMp.playbackState === MediaPlayer.PausedState
    }

    // a whisper of shade so light module fills keep their edge on a bright wall.
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.16) }

    Repeater {
        model: ["top", "left", "bottom", "right"]

        delegate: Rectangle {
            required property string modelData
            readonly property var rail: mock.frameBars.rails[modelData]
            readonly property bool horizontal: modelData === "top" || modelData === "bottom"

            visible: rail.enabled
            z: 1
            width: horizontal ? parent.width : Math.min(parent.width, mock.railThickness(modelData))
            height: horizontal ? Math.min(parent.height, mock.railThickness(modelData)) : parent.height
            anchors.top: modelData === "top" ? parent.top : undefined
            anchors.bottom: modelData === "bottom" ? parent.bottom : undefined
            anchors.left: modelData === "left" ? parent.left : undefined
            anchors.right: modelData === "right" ? parent.right : undefined
            color: mock.railMaterial()
            border.width: mock.frameBars.style === "slate-frame" ? 1 : 0
            border.color: Qt.rgba(mock.cFg.r, mock.cFg.g, mock.cFg.b, 0.45)
        }
    }

    // ── terminal: fastfetch card + the 8-colour neofetch strip ────────────────
    Rectangle {
        id: term
        z: 1
        anchors.left: parent.left
        anchors.leftMargin: 16 * mock.s
        anchors.top: parent.top
        anchors.topMargin: 54 * mock.s
        width: parent.width * 0.54
        height: parent.height * 0.46
        radius: Tokens.radius
        color: Qt.rgba(mock.cBg.r, mock.cBg.g, mock.cBg.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(mock.cFg.r, mock.cFg.g, mock.cFg.b, 0.16)
        Behavior on color { ColorAnimation { duration: Tokens.swap } }

        Column {
            anchors.fill: parent
            anchors.margins: 11 * mock.s
            spacing: 6 * mock.s

            // the traffic lights are content: a terminal window's dots are round.
            Row {
                spacing: 6 * mock.s
                Repeater {
                    model: [mock.cRed, mock.cYellow, mock.cGreen]
                    delegate: Rectangle {
                        required property var modelData
                        width: 8 * mock.s; height: 8 * mock.s; radius: 4 * mock.s
                        color: modelData
                        Behavior on color { ColorAnimation { duration: Tokens.swap } }
                    }
                }
            }

            Row {
                spacing: 0
                Text { text: "ryoku"; color: mock.cGreen; font.family: Tokens.mono; font.pixelSize: 11 * mock.s; font.weight: Font.DemiBold; Behavior on color { ColorAnimation { duration: Tokens.swap } } }
                Text { text: "@arch"; color: mock.cMag; font.family: Tokens.mono; font.pixelSize: 11 * mock.s; Behavior on color { ColorAnimation { duration: Tokens.swap } } }
                Text { text: " ~ "; color: mock.cBlue; font.family: Tokens.mono; font.pixelSize: 11 * mock.s; Behavior on color { ColorAnimation { duration: Tokens.swap } } }
                Text { text: "❯ fastfetch"; color: mock.cFg; font.family: Tokens.mono; font.pixelSize: 11 * mock.s; Behavior on color { ColorAnimation { duration: Tokens.swap } } }
            }

            Repeater {
                model: ["OS    Ryoku Linux", "WM    Hyprland", "SH    fish"]
                delegate: Row {
                    required property var modelData
                    spacing: 0
                    Text { text: modelData.substring(0, 6); color: mock.cYellow; font.family: Tokens.mono; font.pixelSize: 10 * mock.s; Behavior on color { ColorAnimation { duration: Tokens.swap } } }
                    Text { text: modelData.substring(6); color: Qt.rgba(mock.cFg.r, mock.cFg.g, mock.cFg.b, 0.85); font.family: Tokens.mono; font.pixelSize: 10 * mock.s; Behavior on color { ColorAnimation { duration: Tokens.swap } } }
                }
            }

            // the scheme as a neofetch-style colour strip.
            Row {
                spacing: 3 * mock.s
                Repeater {
                    model: 8
                    delegate: Rectangle {
                        required property int index
                        width: 11 * mock.s; height: 9 * mock.s; radius: Tokens.radius
                        color: Wallhaven.col(index + 1, Qt.rgba(mock.cFg.r, mock.cFg.g, mock.cFg.b, 0.2))
                        Behavior on color { ColorAnimation { duration: Tokens.swap } }
                    }
                }
            }
        }
    }

    // ── cava visualiser: the user's real visualizer.json, recoloured by the
    // candidate scheme (amendment 2 keeps the motion). Dense, mirrored, rounded
    // bars positioned per the config, so it reads as their actual shell.
    readonly property int cavaN: Math.max(8, Math.min(Math.round(viz.bars), 90))
    property var levels: []
    property real phase: 0
    function retick() {
        var n = mock.cavaN;
        var half = viz.mirror ? Math.ceil(n / 2) : n;
        var h = [];
        for (var i = 0; i < half; i++) {
            var base = Math.abs(Math.sin(mock.phase + i * 0.5));
            var env = viz.mirror ? (0.4 + 0.6 * (1 - i / half)) : 1;
            h.push(Math.max(0.05, base * (0.5 + 0.5 * Math.random()) * env));
        }
        var arr = [];
        if (viz.mirror) {
            for (var j = 0; j < n; j++) {
                var k = j < half ? (half - 1 - j) : (j - half);
                arr.push(h[Math.min(k, half - 1)]);
            }
        } else {
            arr = h;
        }
        mock.levels = arr;
        mock.phase += 0.32;
    }
    // The spectrum specimen, coloured exactly as the desktop visualiser will
    // colour it on Set: each band is a tone off the previewed image's own
    // primary / secondary ramp (never its error or tertiary), lit against the
    // patch of picture behind that bar. Mirrors visualizer/Singletons/Scheme.qml
    // + Ui.Ink, reading the daemon's tonal ramps and 8x8 L* map for THIS image.
    readonly property var cavaRamps: ["secondary", "primary", "primary", "primary", "primary", "secondary"]

    // One direction for the whole spectrum (mean L* of the picture's bottom
    // band), so neighbouring bars never flip over a mid-tone picture.
    readonly property real cavaFieldL: {
        var g = Wallhaven.previewGrid, cols = Wallhaven.previewCols | 0, rows = Wallhaven.previewRows | 0;
        if (!g || cols <= 0 || rows <= 0 || g.length < cols * rows)
            return Wallhaven.previewLstar;
        var sum = 0;
        for (var x = 0; x < cols; x++)
            sum += g[(rows - 1) * cols + x];
        return sum / cols;
    }
    readonly property int cavaDir: mock.cavaFieldL >= 50 ? -1 : 1

    // L* under the bar at normalised x (the map's bottom row); mid when absent.
    function cavaLstar(t) {
        var g = Wallhaven.previewGrid, cols = Wallhaven.previewCols | 0, rows = Wallhaven.previewRows | 0;
        if (!g || cols <= 0 || rows <= 0 || g.length < cols * rows)
            return mock.cavaFieldL;
        var x = Math.max(0, Math.min(cols - 1, Math.floor(t * cols)));
        return g[(rows - 1) * cols + x];
    }
    // Nearest published tone off a ramp, "" when no ramps were sent.
    function cavaTone(ramp, tv) {
        var r = Wallhaven.previewTones ? Wallhaven.previewTones[ramp] : null;
        if (!r)
            return "";
        var best = "", bestD = Infinity;
        for (var k in r) {
            var d = Math.abs(Number(k) - tv);
            if (d < bestD) { bestD = d; best = r[k]; }
        }
        return best;
    }
    // Each band: primary across the middle, secondary at the edges, each held to
    // where the ramp still carries chroma (30..88) and moved off the picture by
    // the visualiser's 45 L* bar delta.
    function bandColor(t) {
        var bgL = mock.cavaLstar(t);
        var tv = Math.max(30, Math.min(88, bgL + mock.cavaDir * 45));
        var edge = Math.abs(t - 0.5) * 2;   // 0 centre, 1 edges
        var h = mock.cavaTone(edge > 0.75 ? "secondary" : "primary", tv);
        return h.length ? h : mock.cGreen;  // fallback: image primary (or default)
    }
    Component.onCompleted: retick()
    Timer { interval: 55; running: mock.visible; repeat: true; onTriggered: mock.retick() }

    Item {
        id: cava
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16 * mock.s
        anchors.rightMargin: 16 * mock.s
        anchors.top: viz.position === "top" ? parent.top : undefined
        anchors.bottom: viz.position === "top" ? undefined : parent.bottom
        anchors.topMargin: viz.position === "top" ? 46 * mock.s : 0
        anchors.bottomMargin: viz.position === "top" ? 0 : 12 * mock.s
        height: parent.height * Math.max(0.12, viz.height * 0.42)
        readonly property real slotW: mock.cavaN > 0 ? width / mock.cavaN : width
        readonly property real barW: Math.max(1.5, slotW * 0.72)

        Repeater {
            model: mock.cavaN
            delegate: Rectangle {
                required property int index
                readonly property color c: mock.bandColor(mock.cavaN > 1 ? index / (mock.cavaN - 1) : 0)
                readonly property real lv: mock.levels.length > index ? mock.levels[index] : 0.1
                width: cava.barW
                x: index * cava.slotW + (cava.slotW - cava.barW) / 2
                height: Math.max(1.5, cava.height * lv)
                y: viz.position === "top" ? 0 : cava.height - height
                radius: viz.shape === "rounded" ? width / 2 : 0
                antialiasing: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(c, 1.25) }
                    GradientStop { position: 0.55; color: c }
                    GradientStop { position: 1.0; color: Qt.alpha(c, 0.35) }
                }
                Behavior on height { NumberAnimation { duration: Tokens.flap; easing.type: Tokens.ease } }
            }
        }
    }
}
