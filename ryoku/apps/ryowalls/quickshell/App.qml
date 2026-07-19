pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Dialogs
import Quickshell
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// ryowalls: pick a wallpaper and see what it does to your whole rice before you
// commit. The left column browses (or grades / tunes the palette); the right
// column is the preview stack, pinned across every lane because it is the
// feedback loop. Paper and ink, one grain layer over everything.
Rectangle {
    id: app

    implicitWidth: 1180
    implicitHeight: 760
    color: Tokens.paper
    focus: true

    // ── lanes + overlays ─────────────────────────────────────────────────────
    property string lane: "browse"        // browse | grade | palette
    property bool settingsOpen: false
    property bool sourceOpen: false
    property bool confirmOpen: false
    property bool quitArmed: false

    readonly property var builtins: [
        { key: "wallhaven", label: "Wallhaven" },
        { key: "live",      label: "Live" },
        { key: "local",     label: "Local" },
        { key: "moewalls",  label: "MoeWalls" },
        { key: "motionbgs", label: "motionbgs" },
        { key: "ryoku",     label: "Ryoku" }
    ]
    readonly property int sourceCount: builtins.length + Wallhaven.libraries.length
    readonly property string sourceLabel: {
        if (Wallhaven.source === "lib") return Wallhaven.libraryName;
        for (var i = 0; i < builtins.length; i++)
            if (builtins[i].key === Wallhaven.source) return builtins[i].label;
        return "Wallhaven";
    }
    readonly property bool fitOn: Wallhaven.ratios.length > 0
    readonly property bool busyNow: Wallhaven.busy || Wallhaven.enhancing

    // nearest wallhaven aspect for the primary monitor, for the Fit toggle.
    readonly property string screenRatio: {
        var s = (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null;
        if (!s || !s.width || !s.height) return "16x9";
        var a = s.width / s.height;
        var t = [["9x16", 0.5625], ["10x16", 0.625], ["1x1", 1], ["5x4", 1.25], ["4x3", 1.333],
            ["3x2", 1.5], ["16x10", 1.6], ["16x9", 1.777], ["21x9", 2.333], ["32x9", 3.555]];
        var best = "16x9", bd = 1e9;
        for (var i = 0; i < t.length; i++) {
            var d = Math.abs(t[i][1] - a);
            if (d < bd) { bd = d; best = t[i][0]; }
        }
        return best;
    }

    // ── the applied-desktop baseline (2.6) ───────────────────────────────────
    // The singleton exposes no `current`, so the diff is against what this
    // session last set on the desktop: SET WALLPAPER captures the candidate, and
    // any later divergence reads as pending. Before the first set the desktop is
    // unknown, so a pick is armed and the card says it is not yet on the desktop.
    property var desktop: ({ valid: false, name: "", image: "", paletteName: "dark16", frame: 1, colours: [], sig: "" })

    function candImage() {
        var s = Wallhaven.selected;
        if (!s) return "";
        if (s.video && ("" + s.video).length > 0) return "" + s.video;
        return "" + (s.path || s.large || s.thumb || "");
    }
    function candSetPath() {
        var p = candImage();
        if (Wallhaven.adjustActive && !Wallhaven.isVideoPath(p)) {
            var slash = p.lastIndexOf("/"), dot = p.lastIndexOf(".");
            return dot > slash ? p.slice(0, dot) + ".edit" + p.slice(dot) : p + ".edit";
        }
        return p;
    }
    function adjustSig() {
        var a = Wallhaven.adjust;
        return a.brightness + "," + a.contrast + "," + a.saturation + "," + a.warmth + "," + (a.vignette ? 1 : 0);
    }
    // the palette colours reload on every preview, so the signature keys off the
    // stable names, not the swatches: a palette re-extract must not flip dirty.
    function candSig() {
        return candSetPath() + "|" + Wallhaven.paletteName + "|" + Wallhaven.settings.frame + "|" + adjustSig();
    }
    readonly property bool armed: Wallhaven.selected !== null && (!desktop.valid || desktop.sig !== candSig())
    readonly property bool clean: desktop.valid && desktop.sig === candSig()

    function captureDesktop() {
        app.desktop = {
            valid: true,
            name: Wallhaven.selected ? ("" + (Wallhaven.selected.name || Wallhaven.selected.id || "")) : "",
            image: candSetPath(),
            paletteName: Wallhaven.paletteName,
            frame: Wallhaven.settings.frame,
            colours: (Wallhaven.palette || []).slice(),
            sig: candSig()
        };
    }

    // re-probe the upscaler tools when the window regains focus (e.g. after the
    // gpk install terminal closes), so Install clears to the toggle on its own.
    readonly property bool windowActive: Window.active
    onWindowActiveChanged: if (windowActive) Wallhaven.refreshCaps()

    Connections {
        target: Wallhaven
        // SET WALLPAPER is the only path that reports "Wallpaper set"; that is the
        // moment the candidate becomes the desktop baseline.
        function onStatusChanged() { if (Wallhaven.status === "Wallpaper set") app.captureDesktop(); }
    }

    Component.onCompleted: {
        if (Wallhaven.results.length === 0) Wallhaven.searchLatest("");
        app.forceActiveFocus();
    }

    // ── keyboard, on ryovm's grammar ─────────────────────────────────────────
    function peel() {
        if (settingsOpen) { settingsOpen = false; return; }
        if (sourceOpen) { sourceOpen = false; return; }
        if (confirmOpen) { confirmOpen = false; return; }
        if (Wallhaven.query.length > 0) { search.clear(); Wallhaven.searchLatest(""); return; }
        if (lane !== "browse") { lane = "browse"; return; }
        // Esc never quits.
    }
    function tryQuit() {
        if (busyNow) {
            if (quitArmed) Qt.quit();
            else { quitArmed = true; quitTimer.restart(); }
        } else Qt.quit();
    }
    function walk(delta) {
        var r = Wallhaven.results;
        if (!r || r.length === 0) return;
        var idx = 0;
        if (Wallhaven.selected)
            for (var i = 0; i < r.length; i++) if (r[i].id === Wallhaven.selected.id) { idx = i; break; }
        Wallhaven.select(r[Math.max(0, Math.min(r.length - 1, idx + delta))]);
    }
    Timer { id: quitTimer; interval: 3000; onTriggered: app.quitArmed = false }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape) { app.peel(); e.accepted = true; return; }
        if (e.key === Qt.Key_Q && (e.modifiers & Qt.ControlModifier)) { app.tryQuit(); e.accepted = true; return; }
        if (e.key === Qt.Key_K && (e.modifiers & Qt.ControlModifier)) { search.grabFocus(); e.accepted = true; return; }
        if (e.key === Qt.Key_Slash) { search.grabFocus(); e.accepted = true; return; }
        if (app.lane === "browse") {
            if (e.key === Qt.Key_Left) { app.walk(-1); e.accepted = true; }
            else if (e.key === Qt.Key_Right) { app.walk(1); e.accepted = true; }
            else if (e.key === Qt.Key_Up) { app.walk(-grid.cols); e.accepted = true; }
            else if (e.key === Qt.Key_Down) { app.walk(grid.cols); e.accepted = true; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                if (Wallhaven.selected && !Wallhaven.busy) Wallhaven.apply();
                e.accepted = true;
            }
        }
    }

    // ── head ─────────────────────────────────────────────────────────────────
    Item {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.s6
        anchors.rightMargin: Tokens.s6
        anchors.topMargin: Tokens.s5
        height: 132

        Column {
            id: headCol
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s2

            // eyebrow: 16x1 rule, 力, app mark in micro caps.
            Row {
                spacing: Tokens.s2
                Rectangle { width: 16; height: 1; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "力"; color: Tokens.inkMuted; font.family: Tokens.jp; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "RYOKU WALLS"
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: 9
                    font.weight: Font.Medium
                    font.letterSpacing: Tokens.trackMark
                    anchors.verticalCenter: parent.verticalCenter
                }
                // the source switcher, up in the identity band: a bordered chip,
                // so it reads as a real control, not a glyph lost beside the title.
                Item { width: Tokens.s4; height: 1 }
                Rectangle {
                    id: srcChip
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: srcInner.width + Tokens.s3 * 2
                    implicitHeight: srcInner.implicitHeight + Tokens.s2
                    radius: Tokens.radius
                    color: openHover.hovered ? Tokens.tint10 : Tokens.tint5
                    border.width: Tokens.border
                    border.color: openHover.hovered ? Tokens.ink : Tokens.lineStrong
                    Behavior on color { ColorAnimation { duration: Tokens.snap } }
                    Behavior on border.color { ColorAnimation { duration: Tokens.snap } }
                    Row {
                        id: srcInner
                        anchors.centerIn: parent
                        spacing: Tokens.s2
                        Text {
                            text: "SOURCE"
                            color: openHover.hovered ? Tokens.ink : Tokens.inkDim
                            font.family: Tokens.ui
                            font.pixelSize: 9
                            font.weight: Font.Medium
                            font.letterSpacing: Tokens.trackLabel
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: Tokens.snap } }
                        }
                        Text {
                            text: app.sourceCount + " ▾"
                            color: openHover.hovered ? Tokens.ink : Tokens.inkMuted
                            font.family: Tokens.mono
                            font.pixelSize: 11
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: Tokens.snap } }
                        }
                    }
                    HoverHandler { id: openHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: app.sourceOpen = true }
                }
            }

            // the page title — the current source, set in the serif.
            Row {
                spacing: Tokens.s3
                Text {
                    id: title
                    text: app.sourceLabel
                    color: Tokens.ink
                    font.family: Tokens.display
                    font.pixelSize: Tokens.fTitle
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Text {
                text: "Find a wallpaper, preview the rice, set it."
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: 12
            }
        }

        // the head's dead right band: a decorative masthead strip in the hub's
        // noir register (a living specimen + editorial type), giving the top of
        // the window a face. Pure decoration; right-click to reframe / swap.
        Decor {
            id: masthead
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: headCol.right
            anchors.leftMargin: Tokens.s7
            anchors.right: winBtns.left
            anchors.rightMargin: Tokens.s5
            boxId: "ryowalls.masthead"
            code: "RYOKU · WALLS"
            title: "壁紙"
            sub: "画廊"
            tate: "壁を選ぶ"
            caption: "Every wall this machine can wear — preview the whole rice, then commit."
            seal: "壁"
            images: ["wave.gif", "compass.gif", "disc.gif", "torus.gif", "render.gif", "sphere.gif", "cube.gif"]
            seed: 0
        }

        Row {
            id: winBtns
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: Tokens.s1
            IconBtn { glyph: "⚙"; onAct: app.settingsOpen = true }
            IconBtn { glyph: "✕"; onAct: Qt.quit() }
        }
    }

    // ── toolbar ──────────────────────────────────────────────────────────────
    Item {
        id: toolbar
        anchors.top: head.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Tokens.s6
        anchors.rightMargin: Tokens.s6
        anchors.topMargin: Tokens.s4
        height: 40

        Seg {
            id: laneSeg
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            options: ["BROWSE", "GRADE", "PALETTE"]
            current: app.lane.toUpperCase()
            onChose: (k) => app.lane = k.toLowerCase()
        }

        Field {
            id: search
            anchors.left: laneSeg.right
            anchors.leftMargin: Tokens.s3
            anchors.verticalCenter: parent.verticalCenter
            width: 260
            toolbar: true
            enabled: Wallhaven.source !== "live"
            opacity: Wallhaven.source === "live" ? 0.4 : 1
            placeholder: Wallhaven.source === "local" ? "Search saved wallpapers"
                : (Wallhaven.source === "moewalls" ? "Search MoeWalls anime"
                : (Wallhaven.source === "motionbgs" ? "Search motionbgs"
                : (Wallhaven.source === "ryoku" ? "Search Ryoku wallpapers"
                : (Wallhaven.source === "lib" ? "Search " + Wallhaven.libraryName
                : (Wallhaven.source === "live" ? "Live wallpapers are local" : "Search wallhaven")))))
            onCommitted: (v) => { app.lane = "browse"; Wallhaven.searchLatest(v); }
        }

        // per-lane controls: browse gets the source-specific toolbar; the sheets
        // carry their own controls, so grade/palette leave the toolbar clean.
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s2
            visible: app.lane === "browse"

            Seg {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallhaven.source === "wallhaven"
                options: ["Latest", "Week", "Month"]
                current: Wallhaven.topRange === "1w" ? "Week" : (Wallhaven.topRange === "1M" ? "Month" : "Latest")
                onChose: (k) => Wallhaven.searchTop(k === "Week" ? "1w" : (k === "Month" ? "1M" : ""))
            }
            Seg {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallhaven.source === "lib" || Wallhaven.source === "local"
                options: ["All", "Images", "Live"]
                current: Wallhaven.libraryType === "images" ? "Images" : (Wallhaven.libraryType === "live" ? "Live" : "All")
                onChose: (k) => Wallhaven.setLibraryType(k.toLowerCase())
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallhaven.source === "wallhaven"
                text: "FIT SCREEN"
                primary: app.fitOn
                onAct: Wallhaven.setRatios(app.fitOn ? "" : app.screenRatio)
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallhaven.source === "live"
                text: "ADD MP4"
                onAct: addDialog.open()
            }

            // pagination, for the paged sources.
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.s2
                visible: Wallhaven.source !== "live" && Wallhaven.source !== "ryoku" && Wallhaven.source !== "local"
                IconBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "‹"
                    armed: Wallhaven.page > 1 && !Wallhaven.searching
                    onAct: Wallhaven.prevPage()
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "" + Wallhaven.page
                    color: Wallhaven.searching ? Tokens.ink : Tokens.inkDim
                    font.family: Tokens.mono
                    font.pixelSize: 12
                }
                IconBtn {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "›"
                    armed: !Wallhaven.searching
                    onAct: Wallhaven.nextPage()
                }
            }

            // local bulk select + delete.
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallhaven.source === "local"
                text: Wallhaven.localSelection.length > 0 ? "CLEAR" : "SELECT ALL"
                onAct: Wallhaven.localSelection.length > 0 ? Wallhaven.clearLocalSelection() : Wallhaven.selectAllLocal()
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallhaven.source === "local" && Wallhaven.localSelection.length > 0
                text: "DELETE " + Wallhaven.localSelection.length
                onAct: app.confirmOpen = true
            }
        }
    }

    // ── the split: left collection, seam, pinned preview stack ───────────────
    Item {
        id: split
        anchors.top: toolbar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomBar.top
        anchors.leftMargin: Tokens.s6
        anchors.rightMargin: Tokens.s6
        anchors.topMargin: Tokens.s4
        anchors.bottomMargin: Tokens.s3

        readonly property real gutter: Tokens.s5
        readonly property real leftW: (width - gutter) * 5 / 12
        readonly property real rightW: (width - gutter) * 7 / 12

        Item {
            id: leftCol
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: split.leftW

            WallGrid {
                id: grid
                anchors.fill: parent
                opacity: app.lane === "browse" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Tokens.swap } }
            }
            GradeSheet {
                anchors.fill: parent
                opacity: app.lane === "grade" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Tokens.swap } }
            }
            PaletteSheet {
                anchors.fill: parent
                opacity: app.lane === "palette" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Tokens.swap } }
            }
        }

        Rectangle {
            x: split.leftW + split.gutter / 2
            width: 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Tokens.line
        }

        PreviewStack {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: split.leftW + split.gutter
            width: split.rightW
            clean: app.clean
            desktopValid: app.desktop.valid
            desktopName: app.desktop.name
            desktopColours: app.desktop.colours
            desktopPaletteName: app.desktop.paletteName
            desktopImage: app.desktop.image
            desktopFrame: app.desktop.frame
            candImage: app.candSetPath()
            isVideo: Wallhaven.selectedVideo
        }
    }

    // ── bottom bar ───────────────────────────────────────────────────────────
    Item {
        id: bottomBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 60

        Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Tokens.line }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.s6
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s3

            Rectangle {
                id: pulseDot
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: Tokens.ink
                readonly property bool pending: app.armed || app.busyNow
                // a heartbeat, not an alarm: 600ms each way while pending; solid
                // otherwise. The animation is a value source, so reset on stop.
                onPendingChanged: if (!pending) opacity = 1
                SequentialAnimation on opacity {
                    running: pulseDot.pending
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 600 }
                    NumberAnimation { to: 1.0; duration: 600 }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: app.quitArmed ? "PRESS CTRL+Q AGAIN TO QUIT"
                    : (Wallhaven.enhancing ? "ENHANCING"
                    : (Wallhaven.busy ? (Wallhaven.status.length ? Wallhaven.status.toUpperCase() : "WORKING")
                    : (app.clean ? "WALLPAPER SET · LIVE ON YOUR DESKTOP"
                    : (Wallhaven.selected ? "PREVIEWING · NOT SET" : "NO PICK"))))
                color: app.armed || app.busyNow ? Tokens.ink : Tokens.inkDim
                font.family: Tokens.ui
                font.pixelSize: 11
                font.weight: Font.Medium
                font.letterSpacing: 1.6
            }
        }

        // backend identity: file truth, mono, the far-right corner.
        Text {
            id: backendTag
            anchors.right: parent.right
            anchors.rightMargin: Tokens.s6
            anchors.verticalCenter: parent.verticalCenter
            text: Wallhaven.source === "moewalls" ? "moewalls.com"
                : (Wallhaven.source === "motionbgs" ? "motionbgs.com"
                : (Wallhaven.source === "ryoku" ? "ryoku-extras"
                : (Wallhaven.source === "live" ? "~/Pictures/livewalls"
                : (Wallhaven.source === "local" ? "~/Pictures"
                : (Wallhaven.source === "lib" ? "github.com/" + Wallhaven.libraryRepo : "wallhaven.cc")))))
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: 9
        }

        Row {
            anchors.right: backendTag.left
            anchors.rightMargin: Tokens.s5
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s3

            Btn {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallhaven.source === "wallhaven"
                text: "SAVE COPY"
                armed: Wallhaven.selected !== null && !Wallhaven.busy
                onAct: Wallhaven.download()
            }
            Rectangle {
                width: 1; height: 22
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallhaven.source === "wallhaven"
                color: Tokens.line
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallhaven.source !== "live" && Wallhaven.source !== "local"
                text: "OPEN"
                armed: Wallhaven.selected !== null
                onAct: Wallhaven.openWeb()
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: "SET WALLPAPER"
                primary: true
                armed: app.armed && !Wallhaven.busy
                onAct: Wallhaven.apply()
            }
        }
    }

    // ── overlays ─────────────────────────────────────────────────────────────
    SourcePicker {
        anchors.fill: parent
        z: 40
        open: app.sourceOpen
        builtins: app.builtins
        onDismissed: app.sourceOpen = false
    }

    SettingsPanel {
        anchors.fill: parent
        z: 40
        open: app.settingsOpen
        onClosed: app.settingsOpen = false
    }

    // destructive confirm: a bone plate with a 2px border and an unambiguous
    // verb, never red (2.4).
    Item {
        anchors.fill: parent
        z: 50
        visible: opacity > 0
        opacity: app.confirmOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            TapHandler { onTapped: app.confirmOpen = false }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 380
            height: cCol.implicitHeight + 2 * Tokens.s5
            radius: Tokens.radius
            color: Tokens.bone
            border.width: 2
            border.color: Tokens.ink
            TapHandler {}
            Column {
                id: cCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.s5
                spacing: Tokens.s4
                Text {
                    text: "Delete wallpapers"
                    color: Tokens.inkOnBone
                    font.family: Tokens.ui
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Remove " + Wallhaven.localSelection.length + " wallpaper(s) from disk. This cannot be undone."
                    color: Tokens.inkOnBoneDim
                    font.family: Tokens.ui
                    font.pixelSize: 12
                }
                Row {
                    anchors.right: parent.right
                    spacing: Tokens.s3
                    // buttons drawn in-line: the module Btn is built for black
                    // surfaces and would vanish on a bone plate.
                    Rectangle {
                        width: cancelT.width + 30; height: 32
                        radius: Tokens.radius
                        color: cancelH.hovered ? Qt.rgba(0, 0, 0, 0.08) : "transparent"
                        border.width: Tokens.border
                        border.color: Tokens.lineOnBone
                        Text { id: cancelT; anchors.centerIn: parent; text: "CANCEL"; color: Tokens.inkOnBone; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel }
                        HoverHandler { id: cancelH; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: app.confirmOpen = false }
                    }
                    Rectangle {
                        width: delT.width + 30; height: 32
                        radius: Tokens.radius
                        color: delH.hovered ? Qt.rgba(0, 0, 0, 0.12) : "transparent"
                        border.width: 2
                        border.color: Tokens.inkOnBone
                        Text { id: delT; anchors.centerIn: parent; text: "DELETE " + Wallhaven.localSelection.length + " FILES"; color: Tokens.inkOnBone; font.family: Tokens.ui; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: Tokens.trackLabel }
                        HoverHandler { id: delH; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { Wallhaven.removeLocalSelected(); app.confirmOpen = false; } }
                    }
                }
            }
        }
    }

    // add a live wallpaper (mp4) into ~/Pictures/livewalls.
    FileDialog {
        id: addDialog
        title: "Add a live wallpaper"
        nameFilters: ["Video (*.mp4 *.mkv *.mov)"]
        onAccepted: Wallhaven.importLive(selectedFile)
    }

    // one grain layer, topmost over everything including the overlays.
    Grain { anchors.fill: parent }
}
