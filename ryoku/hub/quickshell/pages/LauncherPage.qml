pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons

// App Launcher (DESIGN.md section 8, DESKTOP). The editor for the command
// palette opened with Super+Space, rebuilt as the monochrome instrument. It is
// a full-bleed page: it owns the whole content region, so it draws its own
// head, its own pinned live preview of the launcher home card, its own settings
// grid, and -- because the shell hides its global action bar for full-bleed
// pages -- its own Save/Revert bar. Settings live in ~/.config/ryoku/launcher.json
// (a flat file this page owns end to end); nothing is written until Save, and
// the launcher watches the file, so a save retunes the palette the next time it
// opens. Every value is a Token; the backdrop and thumbnails are genuine image
// specimens, the one place colour is allowed on the sheet.
Item {
    id: pg

    property var hub
    readonly property bool fullBleed: true

    // ── config: the flat launcher.json keys and their canonical factory
    // defaults (mirrored from the launcher's LauncherConfig singleton, the
    // source of truth), used for reset-to-defaults and the struck default.
    readonly property var keys: [
        "radius", "bgBlur", "weatherUnit", "heroImage",
        "heroStrength", "heroPosX", "heroPosY", "showWeather", "showGreeting"
    ]
    readonly property var factory: ({
            "radius": 16, "bgBlur": 12, "weatherUnit": "auto", "heroImage": "",
            "heroStrength": 0.6, "heroPosX": 0.5, "heroPosY": 0.5,
            "showWeather": true, "showGreeting": true
        })

    // draft is the live, in-memory edit; committed is the on-disk baseline.
    // both seed to factory so a binding never reads undefined before the file
    // has loaded, and the page reads clean until the first real edit.
    property var draft: pg.clone(pg.factory)
    property var committed: pg.clone(pg.factory)
    property bool loaded: false

    function clone(o) {
        var r = {};
        for (var k in o)
            r[k] = o[k];
        return r;
    }
    function same(a, b) { return String(a) === String(b); }
    function clamp01(v) { return Math.max(0, Math.min(1, v)); }
    function basename(p) { return ("" + p).replace(/^.*\//, ""); }
    function pad2(n) { return (n < 10 ? "0" : "") + n; }

    // dirty is per-key draft-vs-disk; the count drives the action bar and the
    // pulsing dot. Nothing here computes against factory: the struck default in
    // a cell is the on-disk value, so "changed" and "dirty" are the same fact.
    readonly property int dirtyCount: {
        if (!pg.loaded)
            return 0;
        var n = 0;
        for (var i = 0; i < pg.keys.length; i++)
            if (!pg.same(pg.draft[pg.keys[i]], pg.committed[pg.keys[i]]))
                n++;
        return n;
    }
    readonly property bool dirty: pg.dirtyCount > 0

    // ── draft ops (model on the wire-probe FileView pattern) ────────────────
    // an edit rebuilds the map so the var reassignment re-fires every binding
    // that reads draft (the preview, the cells, the dirty count).
    function edit(k, v) {
        var d = pg.clone(pg.draft);
        d[k] = v;
        pg.draft = d;
    }
    // pull the whole file into draft + baseline; first load only.
    function adopt() {
        var d = {}, c = {};
        for (var i = 0; i < pg.keys.length; i++) {
            var k = pg.keys[i];
            d[k] = cfgA[k];
            c[k] = cfgA[k];
        }
        pg.draft = d;
        pg.committed = c;
    }
    // a later external write landed on disk: rebase every key the user has not
    // locally edited, and rebase the baseline of edited keys so the diff stays
    // honest, but keep the user's unsaved value.
    function adoptExternal() {
        var d = {}, c = {};
        for (var i = 0; i < pg.keys.length; i++) {
            var k = pg.keys[i];
            if (pg.same(pg.draft[k], pg.committed[k])) {
                d[k] = cfgA[k];
                c[k] = cfgA[k];
            } else {
                d[k] = pg.draft[k];
                c[k] = cfgA[k];
            }
        }
        pg.draft = d;
        pg.committed = c;
    }
    function save() {
        for (var i = 0; i < pg.keys.length; i++)
            cfgA[pg.keys[i]] = pg.draft[pg.keys[i]];
        cfg.writeAdapter();
        pg.committed = pg.clone(pg.draft);
    }
    function revert() { pg.draft = pg.clone(pg.committed); }
    function resetDefaults() { pg.draft = pg.clone(pg.factory); }

    // weatherUnit is stored as the launcher expects (auto | C | F); the seg
    // shows readable labels and maps back.
    function unitLabel(k) { return k === "C" ? "\u00b0C" : k === "F" ? "\u00b0F" : "Auto"; }
    function unitKey(l) { return l === "\u00b0C" ? "C" : l === "\u00b0F" ? "F" : "auto"; }

    // the unit the "auto" setting resolves to for the preview readout, derived
    // from the locale the way the launcher's weather backend does.
    function localeUnit() {
        var l = String(Quickshell.env("LC_MEASUREMENT") || Quickshell.env("LANG") || "");
        return /(^|[_.@-])(US|LR|MM)([_.@-]|$)/.test(l) ? "F" : "C";
    }
    readonly property string effUnit: pg.draft.weatherUnit === "auto"
        ? pg.localeUnit() : (String(pg.draft.weatherUnit) || "C")

    // ── the config file this page owns end to end ───────────────────────────
    FileView {
        id: cfg
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/launcher.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: { if (!pg.loaded) { pg.adopt(); pg.loaded = true; } else pg.adoptExternal(); }
        onLoadFailed: { if (!pg.loaded) { pg.adopt(); pg.loaded = true; } }

        JsonAdapter {
            id: cfgA
            property real radius: 16
            property int bgBlur: 12
            property string weatherUnit: "auto"
            property string heroImage: ""
            property real heroStrength: 0.6
            property real heroPosX: 0.5
            property real heroPosY: 0.5
            property bool showWeather: true
            property bool showGreeting: true
        }
    }

    // a local clock for the preview; minute precision, so a slow tick is fine.
    property var now: new Date()
    Timer { interval: 10000; running: true; repeat: true; onTriggered: pg.now = new Date(); }
    readonly property string clockStr: pg.pad2(pg.now.getHours()) + ":" + pg.pad2(pg.now.getMinutes())
    readonly property string dateStr: Qt.locale("en_US").toString(pg.now, "dddd, MMM d")
    readonly property string greeting: {
        var h = pg.now.getHours();
        return h < 5 ? "GOOD NIGHT" : h < 12 ? "GOOD MORNING" : h < 18 ? "GOOD AFTERNOON" : "GOOD EVENING";
    }

    // ── head: eyebrow, Fraunces title, blurb (matches every settings page) ──
    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s6
        spacing: Tokens.s2

        Row {
            spacing: Tokens.s2
            Rectangle {
                width: 16; height: 1; color: Tokens.ink
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "\u529b"; color: Tokens.ink; font.family: Tokens.jp
                font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: I18n.tr("DESKTOP"); color: Tokens.inkMuted; font.family: Tokens.ui
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            text: I18n.tr("App Launcher"); color: Tokens.ink
            font.family: Tokens.display; font.pixelSize: Tokens.fTitle
        }
        Text {
            width: Math.min(parent.width, 760)
            text: I18n.tr("Tune the command palette you open with Super+Space: its corners, the blur behind it, and the home card's greeting, weather and backdrop. Nothing is written until you save.")
            color: Tokens.inkMuted; font.family: Tokens.ui
            font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap
        }
    }

    // marginalia in the head's right margin: the reference's masthead row as a
    // running head, dressing the dead space beside the title. Ink only.
    Marginalia {
        anchors { right: parent.right; top: head.top }
        anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s1
        kana: "ランチャー"
        index: "003"; label: I18n.tr("PALETTE")
    }

    // ── pinned live preview of the launcher home card ───────────────────────
    // Pinned above the scroll (DESIGN.md rule 11): it shows the real effect of
    // the settings -- the backdrop cover-cropped by heroPosX/Y and dimmed by
    // heroStrength (drag to reposition), the greeting, and the weather glance or
    // date. The backdrop is a genuine image specimen, the licensed colour here.
    Preview {
        id: preview
        anchors { left: parent.left; right: parent.right; top: head.bottom }
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s5
        height: 244
        label: I18n.tr("LIVE PREVIEW")
        tag: "SUPER SPACE"
        live: true

        Item {
            id: card
            anchors.fill: parent

            // backmost: the hero backdrop, cover-cropped and dimmed exactly as
            // the launcher card renders it.
            Rectangle {
                id: heroClip
                anchors.fill: parent
                radius: Tokens.radius
                color: "transparent"
                clip: true

                Image {
                    id: heroImg
                    visible: (pg.draft.heroImage || "").length > 0
                    readonly property real ir: heroImg.implicitHeight > 0 ? heroImg.implicitWidth / heroImg.implicitHeight : 1
                    readonly property real fr: card.height > 0 ? card.width / card.height : 1
                    width: heroImg.ir > heroImg.fr ? card.height * heroImg.ir : card.width
                    height: heroImg.ir > heroImg.fr ? card.height : card.width / heroImg.ir
                    x: (card.width - width) * (Number(pg.draft.heroPosX) || 0)
                    y: (card.height - height) * (Number(pg.draft.heroPosY) || 0)
                    source: pg.draft.heroImage || ""
                    opacity: Number(pg.draft.heroStrength) || 0
                    asynchronous: true
                    cache: true
                    smooth: true
                }

                // empty state: the launcher falls back to its shipped art, which
                // the Hub does not carry, so the preview says so in words.
                Text {
                    visible: (pg.draft.heroImage || "").length === 0
                    anchors.centerIn: parent
                    text: I18n.tr("SHIPPED ART")
                    color: Tokens.inkFaint; font.family: Tokens.ui
                    font.pixelSize: Tokens.fMicro; font.weight: Font.Medium
                    font.letterSpacing: Tokens.trackMark
                }
            }

            // left: greeting eyebrow over the hero clock. The clock is a
            // presented numeral, so Grotesk with tnum, never mono (DESIGN.md
            // section 2). No breathing colon: the only perpetual animation
            // allowed on the sheet is the dirty dot.
            Column {
                anchors { left: parent.left; top: parent.top }
                anchors.leftMargin: Tokens.s4; anchors.topMargin: Tokens.s4
                spacing: Tokens.s1

                Text {
                    visible: !!pg.draft.showGreeting
                    text: pg.greeting; color: Tokens.ink
                    font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                    font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                }
                Text {
                    text: pg.clockStr; color: Tokens.ink
                    font.family: Tokens.ui; font.pixelSize: Tokens.fHero
                    font.weight: Font.Light; font.features: ({ "tnum": 1 })
                }
            }

            // right: the weather glance when shown, the date otherwise. The
            // temperature is a representative sample in the resolved unit -- the
            // Hub does not fetch live weather -- so the glance shows the unit and
            // the show/hide behaviour the setting actually controls.
            Column {
                anchors { right: parent.right; top: parent.top }
                anchors.rightMargin: Tokens.s4; anchors.topMargin: Tokens.s4
                spacing: Tokens.s1

                Text {
                    anchors.right: parent.right
                    visible: !!pg.draft.showWeather
                    text: (pg.effUnit === "F" ? "70" : "21") + (pg.effUnit === "F" ? I18n.tr("\u00b0F") : I18n.tr("\u00b0C"))
                    color: Tokens.ink; font.family: Tokens.ui
                    font.pixelSize: 22; font.weight: Font.Light; font.features: ({ "tnum": 1 })
                }
                Text {
                    anchors.right: parent.right
                    visible: !!pg.draft.showWeather
                    text: I18n.tr("Clear sky")
                    color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                }
                Text {
                    anchors.right: parent.right
                    visible: !pg.draft.showWeather
                    text: pg.dateStr
                    color: Tokens.ink; font.family: Tokens.ui
                    font.pixelSize: 22; font.weight: Font.Light
                }
                Text {
                    anchors.right: parent.right
                    visible: !!pg.draft.showWeather
                    text: pg.dateStr
                    color: Tokens.inkFaint; font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                }
            }

            // the preview is also the editor for the focal point: drag it to
            // pick the part of the backdrop that shows (DESIGN keeps this the
            // only way to set heroPosX/heroPosY, as the old page did).
            DragHandler {
                id: dragH
                target: null
                enabled: (pg.draft.heroImage || "").length > 0
                cursorShape: Qt.SizeAllCursor
                property real ox: 0.5
                property real oy: 0.5
                onActiveChanged: if (dragH.active) {
                    dragH.ox = Number(pg.draft.heroPosX) || 0;
                    dragH.oy = Number(pg.draft.heroPosY) || 0;
                }
                onActiveTranslationChanged: {
                    if (!dragH.active)
                        return;
                    var rx = heroImg.width - card.width;
                    var ry = heroImg.height - card.height;
                    if (rx > 1)
                        pg.edit("heroPosX", pg.clamp01(dragH.ox - dragH.activeTranslation.x / rx));
                    if (ry > 1)
                        pg.edit("heroPosY", pg.clamp01(dragH.oy - dragH.activeTranslation.y / ry));
                }
            }
            HoverHandler { id: dragHov; enabled: (pg.draft.heroImage || "").length > 0; cursorShape: Qt.SizeAllCursor }

            // drag hint, shown on hover over a set backdrop. A solid lift bar,
            // no translucency (DESIGN.md section 6).
            Rectangle {
                visible: (pg.draft.heroImage || "").length > 0 && dragHov.hovered
                anchors { left: parent.left; bottom: parent.bottom; margins: Tokens.s2 }
                width: dragHint.implicitWidth + Tokens.s4
                height: 22
                radius: Tokens.radius
                color: Tokens.paperLift
                border.width: Tokens.border
                border.color: Tokens.line
                Text {
                    id: dragHint
                    anchors.centerIn: parent
                    text: I18n.tr("DRAG TO REPOSITION")
                    color: Tokens.inkDim; font.family: Tokens.ui
                    font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                }
            }
        }
    }

    // ── the scrolling settings grid, grouped by meaning ─────────────────────
    Flickable {
        id: flick
        anchors {
            left: parent.left; right: parent.right
            top: preview.bottom; bottom: bar.top
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

            // PALETTE: the window's shape and the frost behind it, two-up so the
            // row fills instead of stranding a lone cell in dead width.
            Section {
                id: palSect
                width: col.width
                title: I18n.tr("PALETTE")

                Cell {
                    width: palSect.span(6)
                    height: Tokens.cellH
                    controlWidth: Spans.inlineWidth("step", 0, width)
                    label: I18n.tr("Corner radius")
                    desc: I18n.tr("Rounds the palette window corners; inner cards follow 4 px tighter.")
                    unit: "px"
                    value: String(pg.draft.radius)
                    def: String(pg.committed.radius)
                    changed: !pg.same(pg.draft.radius, pg.committed.radius)
                    source: "launcher.json"
                    Step {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        value: Number(pg.draft.radius) || 0
                        from: 0; to: 28
                        onModified: (v) => pg.edit("radius", v)
                    }
                }
                Cell {
                    width: palSect.span(6)
                    height: Tokens.cellH
                    controlWidth: Spans.inlineWidth("step", 0, width)
                    label: I18n.tr("Background blur")
                    desc: I18n.tr("Frosts the desktop behind the open palette, even with blur off globally. 0 keeps it sharp.")
                    unit: "px"
                    value: String(pg.draft.bgBlur)
                    def: String(pg.committed.bgBlur)
                    changed: !pg.same(pg.draft.bgBlur, pg.committed.bgBlur)
                    source: "launcher.json"
                    Step {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        value: Number(pg.draft.bgBlur) || 0
                        from: 0; to: 30
                        onModified: (v) => pg.edit("bgBlur", v)
                    }
                }
            }

            // HOME CARD
            Section {
                id: hcSect
                width: col.width
                title: I18n.tr("HOME CARD")

                Cell {
                    width: hcSect.span(4)
                    height: Tokens.cellH
                    controlWidth: Spans.inlineWidth("sw", 0, width)
                    label: I18n.tr("Show greeting")
                    desc: I18n.tr("Time-of-day greeting above the home card clock.")
                    value: pg.draft.showGreeting ? "ON" : "OFF"
                    def: pg.committed.showGreeting ? "ON" : "OFF"
                    changed: !pg.same(pg.draft.showGreeting, pg.committed.showGreeting)
                    source: "launcher.json"
                    Sw {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: !!pg.draft.showGreeting
                        onToggled: (v) => pg.edit("showGreeting", v)
                    }
                }
                Cell {
                    width: hcSect.span(4)
                    height: Tokens.cellH
                    controlWidth: Spans.inlineWidth("sw", 0, width)
                    label: I18n.tr("Show weather")
                    desc: I18n.tr("Current conditions and temperature on the home card; off shows the date.")
                    value: pg.draft.showWeather ? "ON" : "OFF"
                    def: pg.committed.showWeather ? "ON" : "OFF"
                    changed: !pg.same(pg.draft.showWeather, pg.committed.showWeather)
                    source: "launcher.json"
                    Sw {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: !!pg.draft.showWeather
                        onToggled: (v) => pg.edit("showWeather", v)
                    }
                }
                Cell {
                    width: hcSect.span(4)
                    height: Tokens.cellH
                    controlWidth: Spans.inlineWidth("seg", 3, width)
                    label: I18n.tr("Weather units")
                    desc: I18n.tr("Temperature scale on the home card; Auto follows your locale.")
                    value: pg.unitLabel(pg.draft.weatherUnit)
                    def: pg.unitLabel(pg.committed.weatherUnit)
                    changed: !pg.same(pg.draft.weatherUnit, pg.committed.weatherUnit)
                    source: "launcher.json"
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: ["Auto", "\u00b0C", "\u00b0F"]
                        current: pg.unitLabel(pg.draft.weatherUnit)
                        onChose: (l) => pg.edit("weatherUnit", pg.unitKey(l))
                    }
                }
            }

            // BACKDROP
            Section {
                id: bdSect
                width: col.width
                title: I18n.tr("BACKDROP")

                // the backdrop file affordance: a full-width module with the
                // current filename, the picker, and a way back to the shipped
                // art. Built bespoke because a file path is not one of the eight
                // controls; it still wears the cell's chrome (hairline, changed
                // bar, source tag) so it belongs in the grid.
                Item {
                    id: heroCell
                    width: bdSect.span(Spans.cols)
                    height: 120
                    readonly property bool changed: !pg.same(pg.draft.heroImage, pg.committed.heroImage)
                    readonly property bool set: (pg.draft.heroImage || "").length > 0

                    Rectangle {
                        anchors.fill: parent
                        radius: Tokens.radius
                        color: hcHov.hovered ? Tokens.tint5 : "transparent"
                        border.width: Tokens.border
                        border.color: hcHov.hovered ? Tokens.lineStrong : Tokens.line
                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                        Behavior on border.color { ColorAnimation { duration: Tokens.snap } }
                    }
                    HoverHandler { id: hcHov }

                    Rectangle {
                        visible: heroCell.changed
                        x: 0; y: Tokens.s2
                        width: 2; height: parent.height - Tokens.s4
                        color: Tokens.ink
                    }

                    Text {
                        anchors { right: parent.right; top: parent.top; margins: Tokens.s3 }
                        text: "launcher"
                        color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
                        opacity: hcHov.hovered ? 1 : 0.8
                        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
                    }

                    Column {
                        anchors { left: parent.left; top: parent.top; margins: Tokens.s3 }
                        anchors.leftMargin: Tokens.s4
                        width: heroCell.width - Tokens.s4 - Tokens.s3
                        spacing: Tokens.s2

                        Text {
                            text: I18n.tr("BACKDROP IMAGE")
                            color: Tokens.inkMuted; font.family: Tokens.ui
                            font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                        }

                        Item {
                            width: parent.width
                            height: 32

                            Text {
                                anchors.left: parent.left
                                anchors.right: heroActs.left
                                anchors.rightMargin: Tokens.s3
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideMiddle
                                text: heroCell.set ? pg.basename(pg.draft.heroImage) : I18n.tr("Shipped art")
                                color: heroCell.set ? Tokens.inkDim : Tokens.inkFaint
                                font.family: heroCell.set ? Tokens.mono : Tokens.ui
                                font.pixelSize: heroCell.set ? 12 : Tokens.fSmall
                            }
                            Row {
                                id: heroActs
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Tokens.s2
                                Btn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: I18n.tr("CHANGE")
                                    onAct: pg.openPicker()
                                }
                                Btn {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: heroCell.set
                                    text: I18n.tr("USE SHIPPED ART")
                                    onAct: pg.edit("heroImage", "")
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: I18n.tr("A landscape PNG or JPG, ideally 1600 px wide or more. It is cropped to a wide banner and dimmed; drag the preview to pick the part that shows.")
                            color: Tokens.inkMuted; font.family: Tokens.ui
                            font.pixelSize: 12; wrapMode: Text.WordWrap
                            maximumLineCount: 2; elide: Text.ElideRight
                        }
                    }
                }

                Cell {
                    width: bdSect.span(Spans.cols)
                    height: Tokens.cellH
                    controlWidth: Spans.inlineWidth("slid", 0, width)
                    label: I18n.tr("Strength")
                    desc: I18n.tr("How visible the backdrop image is; 0 hides it completely.")
                    unit: "%"
                    value: String(Math.round((Number(pg.draft.heroStrength) || 0) * 100))
                    def: String(Math.round((Number(pg.committed.heroStrength) || 0) * 100))
                    changed: !pg.same(pg.draft.heroStrength, pg.committed.heroStrength)
                    source: "launcher.json"
                    Slid {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        value: Math.round((Number(pg.draft.heroStrength) || 0) * 100)
                        from: 0; to: 100
                        onModified: (v) => pg.edit("heroStrength", v / 100)
                    }
                }
            }
        }
    }

    // ── action bar: status + Reset / Revert / Save ──────────────────────────
    // this page is full-bleed, so the shell's global action bar is hidden; this
    // bar is the only way to persist. It mirrors DESIGN.md section 8 verbatim.
    Rectangle {
        id: bar
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 60
        color: "transparent"
        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 1; color: Tokens.line
        }

        // marginalia in the bar's dead centre, between the status and the verbs.
        Marginalia {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            kana: "起動"
            index: "SUPER"; label: I18n.tr("SPACE")
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: Tokens.s6
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s3

            Rectangle {
                id: dot
                anchors.verticalCenter: parent.verticalCenter
                width: 6; height: 6; radius: 3
                antialiasing: false
                color: pg.dirty ? Tokens.ink : "transparent"
                border.width: pg.dirty ? 0 : Tokens.border
                border.color: Tokens.inkFaint

                SequentialAnimation on opacity {
                    running: pg.dirty
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    onStopped: dot.opacity = 1
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pg.dirty
                    ? (pg.dirtyCount + (pg.dirtyCount === 1 ? I18n.tr(" CHANGE") : I18n.tr(" CHANGES")) + I18n.tr(" \u00b7 PREVIEWING \u00b7 NOT SAVED"))
                    : I18n.tr("SAVED \u00b7 LIVE ON YOUR DESKTOP")
                color: pg.dirty ? Tokens.ink : Tokens.inkMuted
                font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
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
                onAct: pg.resetDefaults()
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: 20; color: Tokens.line
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("REVERT")
                armed: pg.dirty
                onAct: pg.revert()
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("SAVE")
                primary: true
                armed: pg.dirty
                onAct: pg.save()
            }
        }
    }

    // ── the backdrop chooser: a monochrome thumbnail grid over a folder ──────
    // ported from the old ImagePicker (folders-first, quick locations, PNG/JPG
    // filter, pick-and-close) and rebuilt in Tokens. Real thumbnails are image
    // specimens, so they keep their colour; everything else is paper and ink.
    property bool pickerOpen: false
    readonly property string home: Quickshell.env("HOME") || ""
    property url pickerFolder: "file://" + pg.home + "/Pictures"
    function openPicker() {
        pg.pickerFolder = "file://" + pg.home + "/Pictures";
        pg.pickerOpen = true;
    }
    function gotoDir(sub) { pg.pickerFolder = "file://" + pg.home + (sub.length ? "/" + sub : ""); }

    Item {
        id: pickerLayer
        anchors.fill: parent
        visible: pg.pickerOpen
        z: 100

        // click-catcher: an outside click cancels. No fill -- translucency is
        // banned on app surfaces (DESIGN.md section 6); the panel is opaque lift.
        MouseArea { anchors.fill: parent; hoverEnabled: true; onClicked: pg.pickerOpen = false }

        FolderListModel {
            id: fm
            folder: pg.pickerFolder
            showDirs: true
            showDirsFirst: true
            showDotAndDotDot: false
            showHidden: false
            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.bmp"]
            sortField: FolderListModel.Name
        }

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 900)
            height: Math.min(parent.height - 60, 560)
            radius: Tokens.radius
            color: Tokens.paperLift
            border.width: Tokens.border
            border.color: Tokens.lineStrong
            MouseArea { anchors.fill: parent; onClicked: {} }   // absorb inside clicks

            Text {
                id: ptitle
                anchors { left: parent.left; top: parent.top; margins: Tokens.s4 }
                text: I18n.tr("CHOOSE A BACKDROP")
                color: Tokens.ink; font.family: Tokens.ui
                font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
            }
            Text {
                anchors.left: ptitle.left
                anchors.top: ptitle.bottom
                anchors.topMargin: Tokens.s1
                anchors.right: pclose.left
                anchors.rightMargin: Tokens.s3
                elide: Text.ElideLeft
                text: ("" + pg.pickerFolder).replace("file://", "").replace(pg.home, "~")
                color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: 11
            }
            IconBtn {
                id: pclose
                anchors { right: parent.right; top: parent.top; margins: Tokens.s3 }
                glyph: "\u2715"
                onAct: pg.pickerOpen = false
            }

            Row {
                id: pnav
                anchors { left: parent.left; right: parent.right; top: ptitle.bottom }
                anchors.leftMargin: Tokens.s4; anchors.rightMargin: Tokens.s4; anchors.topMargin: Tokens.s5
                spacing: Tokens.s2

                Btn { text: I18n.tr("\u2191 UP"); onAct: pg.pickerFolder = fm.parentFolder }
                Btn { text: I18n.tr("HOME"); onAct: pg.gotoDir("") }
                Btn { text: I18n.tr("PICTURES"); onAct: pg.gotoDir("Pictures") }
                Btn { text: I18n.tr("DOWNLOADS"); onAct: pg.gotoDir("Downloads") }
            }

            GridView {
                id: grid
                anchors {
                    left: parent.left; right: parent.right
                    top: pnav.bottom; bottom: pfoot.top
                    leftMargin: Tokens.s3; rightMargin: Tokens.s3
                    topMargin: Tokens.s3; bottomMargin: Tokens.s2
                }
                clip: true
                readonly property int cols: Math.max(3, Math.floor(width / 190))
                cellWidth: Math.floor(width / cols)
                cellHeight: Math.round(cellWidth * 0.72)
                cacheBuffer: 1200
                boundsBehavior: Flickable.StopAtBounds
                model: fm
                ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

                delegate: Item {
                    id: tile
                    required property string fileName
                    required property url fileUrl
                    required property bool fileIsDir
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: Tokens.radius
                        // a folder is a row-like item, so it inverts under the
                        // cursor; an image cannot invert, so it gets an ink edge.
                        color: tile.fileIsDir && th.hovered ? Tokens.bone : (th.hovered ? Tokens.tint5 : "transparent")
                        border.width: Tokens.border
                        border.color: th.hovered ? (tile.fileIsDir ? Tokens.bone : Tokens.ink) : Tokens.line
                        clip: true
                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                        Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

                        Column {
                            visible: tile.fileIsDir
                            anchors.centerIn: parent
                            width: parent.width - Tokens.s5
                            spacing: Tokens.s2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("DIR")
                                color: th.hovered ? Tokens.inkOnBone : Tokens.inkMuted
                                font.family: Tokens.ui; font.pixelSize: Tokens.fTiny
                                font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideMiddle
                                text: tile.fileName
                                color: th.hovered ? Tokens.inkOnBone : Tokens.inkDim
                                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                            }
                        }

                        Image {
                            visible: !tile.fileIsDir
                            anchors.fill: parent
                            anchors.margins: 1
                            asynchronous: true
                            cache: true
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(Math.ceil(parent.width * 1.4), Math.ceil(parent.height * 1.4))
                            source: tile.fileIsDir ? "" : tile.fileUrl
                        }

                        Rectangle {
                            visible: !tile.fileIsDir && th.hovered
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            height: 20
                            color: Tokens.paperLift
                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.s2
                                anchors.rightMargin: Tokens.s2
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideMiddle
                                text: tile.fileName
                                color: Tokens.inkDim; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
                            }
                        }

                        HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                if (tile.fileIsDir) {
                                    pg.pickerFolder = tile.fileUrl;
                                } else {
                                    pg.edit("heroImage", "" + tile.fileUrl);
                                    pg.pickerOpen = false;
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: grid
                visible: fm.status === FolderListModel.Ready && fm.count === 0
                text: I18n.tr("NO IMAGES OR FOLDERS HERE")
                color: Tokens.inkMuted; font.family: Tokens.ui
                font.pixelSize: 12; font.letterSpacing: 2
            }

            Item {
                id: pfoot
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 52
                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    height: 1; color: Tokens.lineSoft
                }
                Btn {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.s4
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("CANCEL")
                    onAct: pg.pickerOpen = false
                }
            }
        }
    }
}
