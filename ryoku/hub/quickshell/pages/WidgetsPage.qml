pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "../schema/WidgetsPage.js" as Schema

// Desktop Widgets (DESIGN.md section 8, DESKTOP). The clock, calendar and
// weather that float on the wallpaper, edited here and mirrored in a pinned
// right-hand column of live specimen cards so the chosen face, size, opacity and
// accent read without leaning over to the desktop; each card's corner map marks
// where the widget sits, and an off widget dims under a struck header. This is a
// full-bleed page: the shell hides its side panel and action bar, so the page
// draws its own head, its own preview column, and its own Save/Revert bar. It
// owns widgets.json directly; nothing lands on the desktop until Save. Every
// value the chrome draws is a Token; the cards render the real desktop widgets.
//
// SettingsSheet and the three reused Preview components live one directory up.
// They are pulled in with Loader-by-URL rather than `import ".."`: a bare
// directory type-import only resolves for pages loaded from inside the shell's
// own config root, so a URL load is the form that works both in the shell and
// when this page is loaded standalone.
Item {
    id: pg

    property var hub
    readonly property bool fullBleed: true

    readonly property string query: (pg.hub && pg.hub.query) ? pg.hub.query : ""

    // ── the file's flat key set, mirrored by the JsonAdapter below ──────────
    readonly property var keys: [
        "clockEnabled", "clockDesign", "clock24h", "clockSeconds", "clockScale",
        "clockOpacity", "clockRadius", "clockAccent", "clockBg", "clockAnchor",
        "clockX", "clockY", "clockLocked",
        "dateShow", "dateDesign",
        "calEnabled", "calDesign", "calWeekStart", "calScale", "calOpacity",
        "calRadius", "calAccent", "calBg", "calAnchor", "calX", "calY", "calLocked",
        "weatherEnabled", "weatherDesign", "weatherUnit", "weatherScope",
        "weatherAnimate", "weatherScale", "weatherOpacity", "weatherRadius",
        "weatherAnchor", "weatherX", "weatherY", "weatherLocked"
    ]

    // factory values, mirroring the desktop widgets' canonical Config defaults.
    // used only by RESET; declared here so the page owns its own truth.
    readonly property var factory: ({
        "clockEnabled": true, "clockDesign": "digital", "clock24h": true, "clockSeconds": false,
        "clockScale": 1.0, "clockOpacity": 1.0, "clockRadius": 26, "clockAccent": "wallust",
        "clockBg": "none", "clockAnchor": "top-left", "clockX": 72, "clockY": 64, "clockLocked": false,
        "dateShow": true, "dateDesign": "inline",
        "calEnabled": false, "calDesign": "month", "calWeekStart": "mon", "calScale": 1.0,
        "calOpacity": 1.0, "calRadius": 26, "calAccent": "wallust", "calBg": "glass",
        "calAnchor": "bottom-right", "calX": 72, "calY": 64, "calLocked": false,
        "weatherEnabled": true, "weatherDesign": "card", "weatherUnit": "C", "weatherScope": "today",
        "weatherAnimate": true, "weatherScale": 1.0, "weatherOpacity": 1.0, "weatherRadius": 26,
        "weatherAnchor": "top-right", "weatherX": 72, "weatherY": 64, "weatherLocked": false
    })

    // scale and opacity persist as ratios (0.5..2.5, 0.2..1.0). The shipped Slid
    // emits whole numbers, so the sheet edits them as integer percents and the
    // draft is converted back to a ratio at the boundary; the file stays native.
    readonly property var pctKeys: ({ "clockOpacity": true, "weatherOpacity": true, "calOpacity": true })
    readonly property var scaleKeys: ({ "clockScale": true, "weatherScale": true, "calScale": true })

    property var draft: ({})
    property var committed: ({})
    property bool loaded: false

    function readAdapter() {
        var m = {};
        for (var i = 0; i < pg.keys.length; i++) {
            var k = pg.keys[i];
            m[k] = cfgA[k];
        }
        return m;
    }
    function edit(k, v) {
        var d = Object.assign({}, pg.draft);
        d[k] = v;
        pg.draft = d;
    }
    function save() {
        for (var i = 0; i < pg.keys.length; i++) {
            var k = pg.keys[i];
            cfgA[k] = pg.draft[k];
        }
        cfg.writeAdapter();
        pg.committed = Object.assign({}, pg.draft);
    }
    function revert() { pg.draft = Object.assign({}, pg.committed); }
    function reset() { pg.draft = Object.assign({}, pg.factory); }

    // first load adopts disk as both baseline and draft. a later external write
    // (someone edits the file, or drags a widget on the desktop) rebases only
    // the keys the user has not locally edited, so unsaved edits survive.
    function onCfgLoaded() {
        if (!pg.loaded) {
            pg.committed = pg.readAdapter();
            pg.draft = pg.readAdapter();
            pg.loaded = true;
            return;
        }
        var disk = pg.readAdapter();
        var nc = {};
        var nd = Object.assign({}, pg.draft);
        for (var i = 0; i < pg.keys.length; i++) {
            var k = pg.keys[i];
            if (String(pg.draft[k]) === String(pg.committed[k])) {
                nd[k] = disk[k];
                nc[k] = disk[k];
            } else {
                nc[k] = pg.committed[k];
            }
        }
        pg.committed = nc;
        pg.draft = nd;
    }

    readonly property int dirtyCount: {
        if (!pg.loaded)
            return 0;
        var n = 0;
        for (var i = 0; i < pg.keys.length; i++) {
            var k = pg.keys[i];
            if (String(pg.draft[k]) !== String(pg.committed[k]))
                n++;
        }
        return n;
    }
    readonly property bool dirty: pg.dirtyCount > 0

    // ── schema, remapped to the four meaning groups the design asks for ──────
    // the generated schema tabs by widget and buries DATE under the clock; the
    // page wants CLOCK / DATE / CALENDAR / WEATHER as sections in one scroll, so
    // every row is re-grouped and put on a single synthetic tab. ratio rows are
    // retargeted to integer-percent sliders (see pctKeys/scaleKeys).
    function groupOf(k) {
        if (k.indexOf("date") === 0) return "DATE";
        if (k.indexOf("clock") === 0) return "CLOCK";
        if (k.indexOf("cal") === 0) return "CALENDAR";
        if (k.indexOf("weather") === 0) return "WEATHER";
        return "CLOCK";
    }
    readonly property var schemaRows: {
        var order = ["CLOCK", "DATE", "CALENDAR", "WEATHER"];
        var out = [];
        for (var gi = 0; gi < order.length; gi++) {
            for (var i = 0; i < Schema.rows.length; i++) {
                var r = Schema.rows[i];
                if (pg.groupOf(r.key) !== order[gi])
                    continue;
                var c = {};
                for (var p in r)
                    c[p] = r[p];
                c.tab = "widgets";
                c.group = order[gi];
                if (pg.pctKeys[r.key]) {
                    c.ctl = "slid"; c.lo = 20; c.hi = 100; c.unit = "%"; c.pct = false;
                } else if (pg.scaleKeys[r.key]) {
                    c.ctl = "slid"; c.lo = 50; c.hi = 250; c.unit = "%"; c.pct = false;
                }
                out.push(c);
            }
        }
        return out;
    }

    // the flat maps handed to the sheet: ratios shown as whole percents.
    readonly property var sheetDraft: {
        var m = {};
        for (var i = 0; i < pg.keys.length; i++) {
            var k = pg.keys[i];
            var v = pg.draft[k];
            if (pg.pctKeys[k] || pg.scaleKeys[k])
                m[k] = Math.round((Number(v) || 0) * 100);
            else
                m[k] = v;
        }
        return m;
    }
    readonly property var sheetDefaults: {
        var m = {};
        for (var i = 0; i < pg.keys.length; i++) {
            var k = pg.keys[i];
            var v = pg.committed[k];
            if (v === undefined) { m[k] = undefined; continue; }
            if (pg.pctKeys[k] || pg.scaleKeys[k])
                m[k] = Math.round((Number(v) || 0) * 100);
            else
                m[k] = v;
        }
        return m;
    }

    function onSheetEdited(k, v) {
        if (pg.pctKeys[k] || pg.scaleKeys[k])
            pg.edit(k, v / 100);
        else
            pg.edit(k, v);
    }
    function onSheetPick(r) { pg.pickRow = r; }

    // anchor -> 0/0.5/1 on each axis, for the card's corner mini-map.
    function afx(a) { return a.indexOf("left") >= 0 ? 0 : (a.indexOf("right") >= 0 ? 1 : 0.5); }
    function afy(a) { return a.indexOf("top") >= 0 ? 0 : (a.indexOf("bottom") >= 0 ? 1 : 0.5); }

    // one live specimen: a framed card that renders the real desktop widget,
    // scaled to fit and centred, dimmed with a struck header when the widget is
    // off, and a 3x3 corner map marking where it sits on the wallpaper.
    component SpecimenCard: Rectangle {
        id: card
        property string title: ""
        property bool on: true
        property string anchor: "center"
        property real natW: 200
        property real natH: 140
        property real userScale: 1
        property real userOpacity: 1
        property Component preview: null

        color: Tokens.paperLift
        radius: Tokens.radius
        border.width: Tokens.border
        border.color: card.on ? Tokens.line : Tokens.lineSoft
        clip: true
        opacity: card.on ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: Tokens.snap } }

        Item {
            id: hdr
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: Tokens.s3; anchors.rightMargin: Tokens.s3; anchors.topMargin: Tokens.s2
            height: 14
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: card.title
                color: card.on ? Tokens.inkMuted : Tokens.inkFaint
                font.family: Tokens.ui; font.pixelSize: 9; font.weight: Font.Medium
                font.letterSpacing: Tokens.trackLabel; font.strikeout: !card.on
            }
            Grid {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                columns: 3; rowSpacing: 2; columnSpacing: 2
                Repeater {
                    model: 9
                    Rectangle {
                        required property int index
                        width: 3; height: 3
                        readonly property bool lit: card.on
                            && (index % 3) === Math.round(pg.afx(card.anchor) * 2)
                            && Math.floor(index / 3) === Math.round(pg.afy(card.anchor) * 2)
                        color: lit ? Tokens.ink : Tokens.lineStrong
                    }
                }
            }
        }

        Item {
            id: bodyHolder
            anchors { left: parent.left; right: parent.right; top: hdr.bottom; bottom: parent.bottom }
            anchors.margins: Tokens.s2
            clip: true
            Item {
                width: card.natW; height: card.natH
                anchors.centerIn: parent
                opacity: card.userOpacity
                scale: Math.min(bodyHolder.width / card.natW, bodyHolder.height / card.natH, 1.15) * card.userScale
                Loader { anchors.fill: parent; sourceComponent: card.preview }
            }
        }
    }

    // ── persistence: the page owns widgets.json ──────────────────────────────
    FileView {
        id: cfg
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/widgets.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: pg.onCfgLoaded()
        onLoadFailed: {
            if (!pg.loaded) {
                pg.committed = pg.readAdapter();
                pg.draft = pg.readAdapter();
                pg.loaded = true;
            }
        }

        JsonAdapter {
            id: cfgA
            property bool clockEnabled: true
            property string clockDesign: "digital"
            property bool clock24h: true
            property bool clockSeconds: false
            property real clockScale: 1.0
            property real clockOpacity: 1.0
            property int clockRadius: 26
            property string clockAccent: "wallust"
            property string clockBg: "none"
            property string clockAnchor: "top-left"
            property int clockX: 72
            property int clockY: 64
            property bool clockLocked: false
            property bool dateShow: true
            property string dateDesign: "inline"
            property bool calEnabled: false
            property string calDesign: "month"
            property string calWeekStart: "mon"
            property real calScale: 1.0
            property real calOpacity: 1.0
            property int calRadius: 26
            property string calAccent: "wallust"
            property string calBg: "glass"
            property string calAnchor: "bottom-right"
            property int calX: 72
            property int calY: 64
            property bool calLocked: false
            property bool weatherEnabled: true
            property string weatherDesign: "card"
            property string weatherUnit: "C"
            property string weatherScope: "today"
            property bool weatherAnimate: true
            property real weatherScale: 1.0
            property real weatherOpacity: 1.0
            property int weatherRadius: 26
            property string weatherAnchor: "top-right"
            property int weatherX: 72
            property int weatherY: 64
            property bool weatherLocked: false
        }
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
                text: "力"; color: Tokens.ink; font.family: Tokens.jp
                font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: I18n.tr("DESKTOP"); color: Tokens.inkMuted; font.family: Tokens.ui
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            text: I18n.tr("Desktop Widgets"); color: Tokens.ink
            font.family: Tokens.display; font.pixelSize: Tokens.fTitle
        }
        Text {
            width: Math.min(parent.width, 720)
            text: I18n.tr("The clock, calendar and weather that float on your wallpaper, previewed live on the right. Pick a face, size, opacity and corner for each; nothing lands on the desktop until you save.")
            color: Tokens.inkMuted; font.family: Tokens.ui
            font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap
        }
    }

    // marginalia dressing the head's empty right margin (running head). Ink only.
    Marginalia {
        anchors { right: parent.right; top: head.top }
        anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s1
        kana: "部品"
        index: "03"; label: I18n.tr("DESKTOP")
        glyph: "wave"; glyph2: "column"
    }

    // ── the live preview: a pinned right column of specimen cards, one per
    // widget, so the chosen face, accent, size and opacity read at a glance while
    // the settings scroll full-height on the left. no cramped desktop mock; the
    // corner map in each card header carries where the widget sits. ───────────
    Item {
        id: previewCol
        anchors { right: parent.right; top: head.bottom; bottom: bar.top }
        anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s5; anchors.bottomMargin: Tokens.s4
        width: Math.round(Math.min(400, Math.max(300, pg.width * 0.34)))

        Item {
            id: pvHead
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 14
            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: I18n.tr("LIVE PREVIEW"); color: Tokens.inkMuted
                font.family: Tokens.mono; font.pixelSize: Tokens.fTiny; font.letterSpacing: 1.4
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: ((pg.draft.clockEnabled ? 1 : 0) + (pg.draft.calEnabled ? 1 : 0) + (pg.draft.weatherEnabled ? 1 : 0)) + " / 3 ON"
                color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
            }
        }

        Column {
            id: pvCards
            anchors { left: parent.left; right: parent.right; top: pvHead.bottom; bottom: parent.bottom }
            anchors.topMargin: Tokens.s3
            spacing: Tokens.s4
            readonly property real cardH: (height - 2 * Tokens.s4) / 3

            SpecimenCard {
                width: parent.width; height: pvCards.cardH
                title: I18n.tr("CLOCK")
                on: pg.draft.clockEnabled === true
                anchor: pg.draft.clockAnchor || "top-left"
                userScale: pg.draft.clockScale || 1
                userOpacity: pg.draft.clockOpacity === undefined ? 1 : pg.draft.clockOpacity
                natW: 210; natH: 150
                preview: Component {
                    Loader {
                        anchors.fill: parent
                        source: Qt.resolvedUrl("../ClockPreview.qml")
                        onLoaded: {
                            item.design = Qt.binding(() => pg.draft.clockDesign || "digital");
                            item.is24 = Qt.binding(() => pg.draft.clock24h === true);
                            item.seconds = Qt.binding(() => pg.draft.clockSeconds === true);
                            item.accentChoice = Qt.binding(() => pg.draft.clockAccent || "wallust");
                            item.dateShow = Qt.binding(() => pg.draft.dateShow === true);
                            item.dateDesign = Qt.binding(() => pg.draft.dateDesign || "inline");
                        }
                    }
                }
            }
            SpecimenCard {
                width: parent.width; height: pvCards.cardH
                title: I18n.tr("CALENDAR")
                on: pg.draft.calEnabled === true
                anchor: pg.draft.calAnchor || "bottom-right"
                userScale: pg.draft.calScale || 1
                userOpacity: pg.draft.calOpacity === undefined ? 1 : pg.draft.calOpacity
                natW: 230; natH: 250
                preview: Component {
                    Loader {
                        anchors.fill: parent
                        source: Qt.resolvedUrl("../CalendarPreview.qml")
                        onLoaded: {
                            item.design = Qt.binding(() => pg.draft.calDesign || "month");
                            item.accentChoice = Qt.binding(() => pg.draft.calAccent || "wallust");
                            item.weekStart = Qt.binding(() => pg.draft.calWeekStart || "mon");
                        }
                    }
                }
            }
            SpecimenCard {
                width: parent.width; height: pvCards.cardH
                title: I18n.tr("WEATHER")
                on: pg.draft.weatherEnabled === true
                anchor: pg.draft.weatherAnchor || "top-right"
                userScale: pg.draft.weatherScale || 1
                userOpacity: pg.draft.weatherOpacity === undefined ? 1 : pg.draft.weatherOpacity
                natW: 320; natH: 200
                preview: Component {
                    Loader {
                        anchors.fill: parent
                        source: Qt.resolvedUrl("../WeatherPreview.qml")
                        onLoaded: {
                            item.design = Qt.binding(() => pg.draft.weatherDesign || "card");
                            item.unit = Qt.binding(() => pg.draft.weatherUnit || "C");
                            item.scope = Qt.binding(() => pg.draft.weatherScope || "today");
                            item.animate = Qt.binding(() => pg.draft.weatherAnimate === true);
                        }
                    }
                }
            }
        }
    }

    // ── the settings, grouped by meaning and driven by the shared renderer ──
    Loader {
        id: sheetLoader
        anchors {
            left: parent.left; right: previewCol.left
            top: head.bottom; bottom: bar.top
            leftMargin: Tokens.s6; rightMargin: Tokens.s5
            topMargin: Tokens.s5; bottomMargin: Tokens.s4
        }
        source: Qt.resolvedUrl("../SettingsSheet.qml")
        onLoaded: {
            item.schema = Qt.binding(() => pg.schemaRows);
            item.draft = Qt.binding(() => pg.sheetDraft);
            item.defaults = Qt.binding(() => pg.sheetDefaults);
            item.tab = "widgets";
            item.query = Qt.binding(() => pg.query);
            item.edited.connect(pg.onSheetEdited);
            item.pickRequested.connect(pg.onSheetPick);
        }
    }

    // ── action bar: status + Reset / Revert / Save ──────────────────────────
    // full-bleed, so the shell's global bar is hidden and this is the only way
    // to persist. nothing writes until Save (DESIGN.md section 11).
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
            kana: "部品"
            glyph: "wave"; glyph2: "column"
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
                    ? (pg.dirtyCount + (pg.dirtyCount === 1 ? I18n.tr(" CHANGE") : I18n.tr(" CHANGES")) + I18n.tr(" · PREVIEWING · NOT SAVED"))
                    : I18n.tr("SAVED · LIVE ON YOUR DESKTOP")
                color: pg.dirty ? Tokens.ink : Tokens.inkMuted
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
                onAct: pg.reset()
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

    // ── the anchor catalogue overlay (Picker), shared by the pick cells ──────
    property var pickRow: null

    MouseArea {
        id: scrim
        anchors.fill: parent
        visible: pg.pickRow !== null
        z: 100
        onClicked: pg.pickRow = null
        onVisibleChanged: if (visible) picker.open()

        Picker {
            id: picker
            anchors.centerIn: parent
            title: pg.pickRow ? I18n.tr(pg.pickRow.label) : ""
            options: pg.pickRow ? (pg.pickRow.opts || []) : []
            current: pg.pickRow ? String(pg.draft[pg.pickRow.key]) : ""
            onChose: (key) => {
                if (pg.pickRow)
                    pg.edit(pg.pickRow.key, key);
                pg.pickRow = null;
            }
            onDismissed: pg.pickRow = null

            MouseArea { anchors.fill: parent; z: -1 }
        }
    }
}
