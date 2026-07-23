pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Recording (DESIGN.md section 11, SYSTEM). The quality knobs behind the bar's
// one-tap screen recorder, read by ryoku-cmd-screenrecord (env vars still
// override at record time). Constant framerate is the default because
// variable-framerate files often import or play back as ~30fps and look choppy.
//
// Self-contained full-bleed page: it owns its whole content region, so it draws
// its own head, the setting cells regrouped by meaning, the live UNDER THE HOOD
// backend readout, and -- because the shell hides its global action bar -- its
// own dirty status + Reset/Revert/Save bar. Nothing writes to disk until Save.
//
// This page is recording.json's ONLY writer, and cfg.writeAdapter() serialises
// the whole adapter, so every key the file carries is declared below or it would
// be dropped on the next save. The `fps` type trap is preserved deliberately:
// the adapter property is `int` and the Step control emits an int, so the file
// stays numeric ("fps": 60, not "60") for the consumer's `cfg_get '.fps' 60`.
// These six defaults are mirrored in the shell consumer's cfg_get/cfg_bool
// fallbacks (ryoku-cmd-screenrecord) and must not drift.
Item {
    id: pg

    property var hub
    readonly property bool fullBleed: true

    // factory defaults: the single source RESET walks back to; it mirrors the
    // JsonAdapter defaults below and the shell consumer's fallbacks.
    readonly property var factory: ({
        "fps": 60,
        "framerateMode": "cfr",
        "quality": "very_high",
        "codec": "h264",
        "encoder": "gpu",
        "cursor": true
    })

    // committed = what is on disk; draft = the live, previewed edit; dirty = they
    // differ. Both are plain maps, reassigned wholesale so the cells re-render.
    property var committed: null
    property var draft: null

    readonly property int dirtyCount: {
        if (!pg.draft || !pg.committed)
            return 0;
        var n = 0;
        for (var k in pg.factory)
            if (pg.draft[k] !== pg.committed[k])
                n++;
        return n;
    }
    // RESET is a no-op when the draft already equals stock, so gate it on that.
    readonly property bool offDefaults: {
        if (!pg.draft)
            return false;
        for (var k in pg.factory)
            if (pg.draft[k] !== pg.factory[k])
                return true;
        return false;
    }

    function clone(o) {
        var r = {};
        for (var k in o)
            r[k] = o[k];
        return r;
    }
    function fromAdapter() {
        return {
            "fps": cfgA.fps,
            "framerateMode": cfgA.framerateMode,
            "quality": cfgA.quality,
            "codec": cfgA.codec,
            "encoder": cfgA.encoder,
            "cursor": cfgA.cursor
        };
    }

    // adopt the on-disk state. First load seeds the draft too; a later external
    // edit rebases committed but keeps an in-flight draft (DESIGN.md section 8),
    // while a clean view simply follows the file.
    function adopt() {
        var wasClean = pg.draft === null || pg.dirtyCount === 0;
        pg.committed = pg.fromAdapter();
        if (wasClean)
            pg.draft = pg.clone(pg.committed);
    }

    function edit(k, v) {
        if (!pg.draft)
            return;
        var d = pg.clone(pg.draft);
        d[k] = v;
        pg.draft = d;
    }
    function revert() {
        if (pg.committed)
            pg.draft = pg.clone(pg.committed);
    }
    function reset() {
        pg.draft = pg.clone(pg.factory);
    }
    function save() {
        if (!pg.draft || !pg.committed)
            return;
        cfgA.fps = pg.draft.fps;
        cfgA.framerateMode = pg.draft.framerateMode;
        cfgA.quality = pg.draft.quality;
        cfgA.codec = pg.draft.codec;
        cfgA.encoder = pg.draft.encoder;
        cfgA.cursor = pg.draft.cursor;
        cfg.writeAdapter();
        pg.committed = pg.clone(pg.draft);
    }

    // span math for the section Flows: a cell's width comes from its control's
    // column count (Spans.of), never from a placement decision (DESIGN.md 6, 9).
    // With the camera poster in the right rail the left column is too narrow to
    // pack cells two-up without eliding their labels, so they run one per row
    // (full width) while it shows.
    function span(n, w) {
        if (recDecor.visible)
            return w;
        var cw = (w - (Spans.cols - 1) * Tokens.s2) / Spans.cols;
        return n * cw + (n - 1) * Tokens.s2;
    }

    Component.onCompleted: pg.adopt()

    // recording.json, this page's only writer. blockLoading makes the first read
    // synchronous; watchChanges + onFileChanged re-render on an external edit;
    // the seeding write materialises the file (populated with every default) when
    // it is absent, so the recorder always has a file to read.
    FileView {
        id: cfg
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/recording.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: pg.adopt()

        JsonAdapter {
            id: cfgA
            property int fps: 60
            property string framerateMode: "cfr"
            property string quality: "very_high"
            property string codec: "h264"
            property string encoder: "gpu"
            property bool cursor: true
        }

        Component.onCompleted: if (!cfg.text()) cfg.writeAdapter()
    }

    // live readout: which backend + hardware encoder the recorder resolves for
    // this machine right now (the gsr probe is time-boxed, so first open can take
    // a moment). Parse failures leave the readout on "Detecting...".
    property string infoBackend: ""
    property string infoEncoder: ""
    Process {
        id: info
        command: [(Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-screenrecord", "--info"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(this.text);
                    pg.infoBackend = j.backend || "";
                    pg.infoEncoder = j.encoder || "";
                } catch (e) {}
            }
        }
    }

    // ── head: eyebrow, Fraunces title, intro blurb (matches every settings page) ──
    Column {
        id: head
        anchors { left: parent.left; right: recDecor.visible ? recDecor.left : parent.right; top: parent.top }
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s6
        spacing: Tokens.s2

        Row {
            spacing: Tokens.s2
            Rectangle {
                width: 16; height: 1; color: Tokens.ink
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "力"; color: Tokens.ink; font.family: Tokens.jp
                font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: I18n.tr("TOOLS"); color: Tokens.inkMuted; font.family: Tokens.ui
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            text: I18n.tr("Recording"); color: Tokens.ink
            font.family: Tokens.display; font.pixelSize: Tokens.fTitle
        }
        Text {
            width: Math.min(parent.width, 720)
            text: I18n.tr("Ryoku records with gpu-screen-recorder, hardware-encoded on your GPU (it falls back to wf-recorder on multi-GPU machines). Start and stop from the bar's screen-capture Tools; these settings shape every recording. Files land in ~/Videos/Recordings.")
            color: Tokens.inkMuted; font.family: Tokens.ui
            font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap
        }
    }

    // ── the scroll region: three sections, grouped by meaning ──
    Flickable {
        id: flick
        anchors {
            left: parent.left; right: recDecor.visible ? recDecor.left : parent.right
            top: head.bottom; bottom: bar.top
            leftMargin: Tokens.s6; rightMargin: Tokens.s6
            topMargin: Tokens.s5; bottomMargin: Tokens.s4
        }
        contentWidth: width
        contentHeight: col.height + Tokens.s5
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: flick.width - Tokens.s3   // reserve a lane for the scroll rail
            spacing: Tokens.s5

            // ── QUALITY ──────────────────────────────────────────────────────
            Column {
                width: col.width
                spacing: Tokens.s3

                Item {
                    width: parent.width; height: 16
                    Row {
                        id: qHdr
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.s2
                        Rectangle { width: 4; height: 4; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: I18n.tr("QUALITY"); color: Tokens.ink; font.family: Tokens.ui
                            font.pixelSize: Tokens.fMicro; font.weight: Font.Medium
                            font.letterSpacing: Tokens.trackMark
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Rectangle {
                        anchors.left: qHdr.right; anchors.leftMargin: Tokens.s3
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        height: 1; color: Tokens.lineSoft
                    }
                }
                Text {
                    width: parent.width
                    text: I18n.tr("Higher framerate is smoother (120 gets closer to a high-refresh panel); higher quality and HEVC/AV1 are crisper but larger. Constant framerate plays and edits correctly everywhere; variable is smaller but can look choppy or import as 30fps.")
                    color: Tokens.inkMuted; font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap
                }

                Flow {
                    width: parent.width
                    spacing: Tokens.s2

                    Cell {
                        width: pg.span(Spans.of("step", 0), col.width)
                        height: Tokens.cellH
                        controlWidth: Spans.inlineWidth("step", 0, width)
                        label: I18n.tr("Framerate")
                        desc: I18n.tr("Frames captured per second; higher is smoother but files are larger.")
                        unit: "fps"
                        source: "recording.json"
                        value: pg.draft ? String(pg.draft.fps) : ""
                        def: pg.committed ? String(pg.committed.fps) : ""
                        changed: pg.draft && pg.committed ? pg.draft.fps !== pg.committed.fps : false
                        Step {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            value: pg.draft ? (Number(pg.draft.fps) || 60) : 60
                            from: 24; to: 120; stepBy: 1
                            onModified: (v) => pg.edit("fps", v)
                        }
                    }
                    Cell {
                        width: pg.span(Spans.of("seg", 2), col.width)
                        height: Tokens.cellH
                        controlWidth: Spans.inlineWidth("seg", 2, width)
                        label: I18n.tr("Framerate mode")
                        desc: I18n.tr("Constant plays everywhere; variable is smaller but may import as 30fps.")
                        source: "recording.json"
                        value: pg.draft ? String(pg.draft.framerateMode) : ""
                        def: pg.committed ? String(pg.committed.framerateMode) : ""
                        changed: pg.draft && pg.committed ? pg.draft.framerateMode !== pg.committed.framerateMode : false
                        Seg {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            options: ["cfr", "vfr"]
                            current: pg.draft ? String(pg.draft.framerateMode) : ""
                            onChose: (k) => pg.edit("framerateMode", k)
                        }
                    }
                    Cell {
                        width: pg.span(Spans.of("seg", 4), col.width)
                        height: Tokens.cellH
                        controlWidth: Spans.inlineWidth("seg", 4, width)
                        label: I18n.tr("Quality")
                        desc: I18n.tr("Higher settings look crisper but make larger files.")
                        source: "recording.json"
                        value: pg.draft ? String(pg.draft.quality) : ""
                        def: pg.committed ? String(pg.committed.quality) : ""
                        changed: pg.draft && pg.committed ? pg.draft.quality !== pg.committed.quality : false
                        Seg {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            options: ["medium", "high", "very_high", "ultra"]
                            current: pg.draft ? String(pg.draft.quality) : ""
                            onChose: (k) => pg.edit("quality", k)
                        }
                    }
                    Cell {
                        width: pg.span(Spans.of("seg", 3), col.width)
                        height: Tokens.cellH
                        controlWidth: Spans.inlineWidth("seg", 3, width)
                        label: I18n.tr("Codec")
                        desc: I18n.tr("H.264 plays anywhere; HEVC and AV1 are crisper, AV1 needs a newer GPU.")
                        source: "recording.json"
                        value: pg.draft ? String(pg.draft.codec) : ""
                        def: pg.committed ? String(pg.committed.codec) : ""
                        changed: pg.draft && pg.committed ? pg.draft.codec !== pg.committed.codec : false
                        Seg {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            options: ["h264", "hevc", "av1"]
                            current: pg.draft ? String(pg.draft.codec) : ""
                            onChose: (k) => pg.edit("codec", k)
                        }
                    }
                }
            }

            // ── ENCODER ──────────────────────────────────────────────────────
            Column {
                width: col.width
                spacing: Tokens.s3

                Item {
                    width: parent.width; height: 16
                    Row {
                        id: eHdr
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.s2
                        Rectangle { width: 4; height: 4; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: I18n.tr("ENCODER"); color: Tokens.ink; font.family: Tokens.ui
                            font.pixelSize: Tokens.fMicro; font.weight: Font.Medium
                            font.letterSpacing: Tokens.trackMark
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Rectangle {
                        anchors.left: eHdr.right; anchors.leftMargin: Tokens.s3
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        height: 1; color: Tokens.lineSoft
                    }
                }
                Text {
                    width: parent.width
                    text: I18n.tr("GPU encoding is fast and barely touches your CPU. CPU is a fallback if the GPU encoder misbehaves.")
                    color: Tokens.inkMuted; font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap
                }

                Flow {
                    width: parent.width
                    spacing: Tokens.s2

                    Cell {
                        width: pg.span(Spans.of("seg", 2), col.width)
                        height: Tokens.cellH
                        controlWidth: Spans.inlineWidth("seg", 2, width)
                        label: I18n.tr("Encoder")
                        desc: I18n.tr("GPU encoding barely loads the CPU; pick CPU if the GPU encoder fails.")
                        source: "recording.json"
                        value: pg.draft ? String(pg.draft.encoder) : ""
                        def: pg.committed ? String(pg.committed.encoder) : ""
                        changed: pg.draft && pg.committed ? pg.draft.encoder !== pg.committed.encoder : false
                        Seg {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            options: ["gpu", "cpu"]
                            current: pg.draft ? String(pg.draft.encoder) : ""
                            onChose: (k) => pg.edit("encoder", k)
                        }
                    }
                    Cell {
                        width: pg.span(Spans.of("sw", 0), col.width)
                        height: Tokens.cellH
                        controlWidth: Spans.inlineWidth("sw", 0, width)
                        label: I18n.tr("Show the cursor")
                        desc: I18n.tr("The mouse pointer is drawn into the video when on, hidden when off.")
                        source: "recording.json"
                        value: pg.draft ? (pg.draft.cursor ? "ON" : "OFF") : ""
                        def: pg.committed ? (pg.committed.cursor ? "ON" : "OFF") : ""
                        changed: pg.draft && pg.committed ? pg.draft.cursor !== pg.committed.cursor : false
                        Sw {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            on: pg.draft ? !!pg.draft.cursor : false
                            onToggled: (v) => pg.edit("cursor", v)
                        }
                    }
                }
            }

            // ── UNDER THE HOOD: the live backend/encoder readout (not a setting) ──
            Column {
                width: col.width
                spacing: Tokens.s3

                Item {
                    width: parent.width; height: 16
                    Row {
                        id: uHdr
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.s2
                        Rectangle { width: 4; height: 4; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: I18n.tr("UNDER THE HOOD"); color: Tokens.ink; font.family: Tokens.ui
                            font.pixelSize: Tokens.fMicro; font.weight: Font.Medium
                            font.letterSpacing: Tokens.trackMark
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    Rectangle {
                        anchors.left: uHdr.right; anchors.leftMargin: Tokens.s3
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        height: 1; color: Tokens.lineSoft
                    }
                }
                Text {
                    width: parent.width
                    text: I18n.tr("What the recorder resolves for this machine right now.")
                    color: Tokens.inkMuted; font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap
                }

                // machine-said strings (backend name, encoder, container spec) are
                // file-truth, so mono (DESIGN.md section 2). The Container line is
                // half fixed (MP4), half live-bound to the draft, so it re-renders
                // as the user turns the controls above.
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: pg.infoBackend === ""
                        ? I18n.tr("Detecting\u2026")
                        : (I18n.tr("Backend    ") + (pg.infoBackend === "gsr" ? I18n.tr("gpu-screen-recorder") : "wf-recorder")
                           + I18n.tr("\nEncoder    ") + pg.infoEncoder
                           + I18n.tr("\nContainer  MP4  \u00b7  ") + (pg.draft ? pg.draft.fps : "")
                           + "fps " + (pg.draft ? String(pg.draft.framerateMode).toUpperCase() : "")
                           + "  \u00b7  " + (pg.draft ? pg.draft.codec : "")
                           + "  \u00b7  " + (pg.draft ? pg.draft.quality : ""))
                    color: Tokens.inkMuted
                    font.family: Tokens.mono
                    font.pixelSize: 12
                    lineHeight: 1.5
                }
            }
        }
    }

    // the marked right rail: a camera specimen poster (the poster layer), from
    // the running head down to the action bar. The head and the settings form
    // are held to its left so text and cells reflow clear of it; it hides when
    // the window is too narrow to spare the column.
    Placard {
        id: recDecor
        anchors {
            right: parent.right; rightMargin: Tokens.s6
            top: head.top; bottom: bar.top
            bottomMargin: Tokens.s4
        }
        width: Math.round(pg.width * 0.30)
        visible: pg.width - width - Tokens.s7 >= 560
        code: "REC-02"
        title: "\u9332\u753b"
        sub: I18n.tr("ON THE RECORD")
        motto: I18n.tr("Without creativity and obsession, everything is boring.")
        chapter: "05"
        label: I18n.tr("TOOLS")
        quote: I18n.tr("THE SCREEN REMEMBERS EVERYTHING.")
        seal: "\u9332"
        art: "camera.png"
        seed: 5
    }

    // ── action bar: dirty status left, Reset / Revert / Save right ──
    // full-bleed hides the shell's global bar, so this is the only way to persist.
    // RESET walks every key to stock (creating dirt), REVERT drops the unsaved
    // draft, SAVE writes it to recording.json (env vars still override at record
    // time). Nothing here reaches hardware.
    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 60
        color: "transparent"

        // hairline lid, like the shell's action bar (DESIGN.md section 8).
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1; color: Tokens.line
        }

        // marginalia in the bar's dead centre, between the status and the verbs.
        Marginalia {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            kana: "録画"
            glyph: "column"; glyph2: "wave"
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.s6
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s3

            // filled ink while dirty, with a 600/600 heartbeat -- the one
            // perpetual animation allowed on an app surface; a hairline dot clean.
            Rectangle {
                id: dot
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                antialiasing: false
                readonly property bool lit: pg.dirtyCount > 0
                color: lit ? Tokens.ink : "transparent"
                border.width: lit ? 0 : Tokens.border
                border.color: Tokens.inkFaint

                SequentialAnimation on opacity {
                    running: pg.dirtyCount > 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    onStopped: dot.opacity = 1
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pg.dirtyCount > 0
                    ? (pg.dirtyCount + (pg.dirtyCount === 1 ? I18n.tr(" CHANGE") : I18n.tr(" CHANGES")) + I18n.tr(" \u00b7 PREVIEWING \u00b7 NOT SAVED"))
                    : I18n.tr("SAVED \u00b7 LIVE ON YOUR DESKTOP")
                color: pg.dirtyCount > 0 ? Tokens.ink : Tokens.inkMuted
                font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                font.capitalization: Font.AllUppercase
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Tokens.s6
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s3

            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("RESET TO DEFAULTS")
                armed: pg.offDefaults
                onAct: pg.reset()
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: 20; color: Tokens.line
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("REVERT")
                armed: pg.dirtyCount > 0
                onAct: pg.revert()
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("SAVE")
                primary: true
                armed: pg.dirtyCount > 0
                onAct: pg.save()
            }
        }
    }
}
