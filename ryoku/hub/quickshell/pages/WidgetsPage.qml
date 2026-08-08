pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "../schema/WidgetsPage.js" as Schema

// Desktop Widgets (DESIGN.md section 8, DESKTOP). The wallpaper clock is edited
// here and mirrored in a pinned live specimen so its face, size, opacity and
// placement read without leaning over to the desktop. This is a full-bleed page:
// the shell hides its side panel and action bar, so the page draws its own head,
// preview and Save/Revert bar. It owns widgets.json directly; nothing lands on
// the desktop until Save.
Item {
    id: pg

    property var hub
    readonly property bool fullBleed: true

    readonly property string query: (pg.hub && pg.hub.query) ? pg.hub.query : ""

    // ── the file's clock key set, mirrored by the JsonAdapter below ─────────
    readonly property var keys: [
        "clockEnabled", "clockDesign", "clock24h", "clockSeconds", "clockScale",
        "clockOpacity", "clockRadius", "clockAccent", "clockBg", "clockAnchor",
        "clockX", "clockY", "clockLocked", "dateShow", "dateDesign",
        "calendarEnabled", "calendarStyle", "calendarWeeks", "calendarWeekNumbers",
        "calendarHolidayRegion", "calendarScale", "calendarOpacity", "calendarAnchor",
        "calendarX", "calendarY", "calendarLocked",
        "musicEnabled", "musicStyle", "musicLyrics", "musicScale", "musicOpacity",
        "musicAnchor", "musicX", "musicY", "musicLocked", "musicApp"
    ]

    // Factory values mirror the wallpaper clock's canonical Config defaults.
    readonly property var factory: ({
        "clockEnabled": true, "clockDesign": "digital", "clock24h": true, "clockSeconds": false,
        "clockScale": 1.0, "clockOpacity": 1.0, "clockRadius": 26, "clockAccent": "palette",
        "clockBg": "none", "clockAnchor": "top-left", "clockX": 72, "clockY": 64, "clockLocked": false,
        "dateShow": true, "dateDesign": "inline",
        "calendarEnabled": true, "calendarStyle": "glass", "calendarWeeks": 6,
        "calendarWeekNumbers": true, "calendarHolidayRegion": "", "calendarScale": 1.0,
        "calendarOpacity": 1.0, "calendarAnchor": "bottom-right", "calendarX": 80,
        "calendarY": 80, "calendarLocked": false,
        "musicEnabled": false, "musicStyle": "cover", "musicLyrics": true,
        "musicScale": 1.0, "musicOpacity": 1.0, "musicAnchor": "bottom-left",
        "musicX": 80, "musicY": 80, "musicLocked": false, "musicApp": ""
    })

    // Scale and opacity persist as ratios; the sheet edits integer percents.
    readonly property var pctKeys: ({
        "clockOpacity": true, "calendarOpacity": true, "musicOpacity": true
    })
    readonly property var scaleKeys: ({
        "clockScale": true, "calendarScale": true, "musicScale": true
    })

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

    // The clock and its date rows share one synthetic tab; ratio rows become
    // integer-percent sliders at the sheet boundary.
    function groupOf(k) {
        if (k.indexOf("calendar") === 0) return "CALENDAR";
        if (k.indexOf("music") === 0) return "MUSIC";
        return k.indexOf("date") === 0 ? "DATE" : "CLOCK";
    }
    readonly property var schemaRows: {
        var order = ["CLOCK", "DATE", "CALENDAR", "MUSIC"];
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
            property string clockAccent: "palette"
            property string clockBg: "none"
            property string clockAnchor: "top-left"
            property int clockX: 72
            property int clockY: 64
            property bool clockLocked: false
            property bool dateShow: true
            property string dateDesign: "inline"
            property bool calendarEnabled: true
            property string calendarStyle: "glass"
            property int calendarWeeks: 6
            property bool calendarWeekNumbers: true
            property string calendarHolidayRegion: ""
            property real calendarScale: 1.0
            property real calendarOpacity: 1.0
            property string calendarAnchor: "bottom-right"
            property int calendarX: 80
            property int calendarY: 80
            property bool calendarLocked: false
            property bool musicEnabled: false
            property string musicStyle: "cover"
            property bool musicLyrics: true
            property real musicScale: 1.0
            property real musicOpacity: 1.0
            property string musicAnchor: "bottom-left"
            property int musicX: 80
            property int musicY: 80
            property bool musicLocked: false
            property string musicApp: ""
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
            text: I18n.tr("The clock, calendar and now-playing sheet on your wallpaper, previewed live on the right. Choose each look, density, size, opacity and position; nothing lands on the desktop until you save.")
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

    // ── the live clock preview: a pinned specimen card whose corner map marks
    // placement on the wallpaper. ────────────────────────────────────────────
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
                text: ((pg.draft.clockEnabled ? 1 : 0) + (pg.draft.calendarEnabled ? 1 : 0)
                    + (pg.draft.musicEnabled ? 1 : 0)) + " / 3 ON"
                color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
            }
        }

        Column {
            id: pvCards
            anchors { left: parent.left; right: parent.right; top: pvHead.bottom; bottom: parent.bottom }
            anchors.topMargin: Tokens.s3
            spacing: Tokens.s4
            readonly property real cardH: Math.max(130, (height - spacing * 2) / 3)

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
                            item.accentChoice = Qt.binding(() => pg.draft.clockAccent || "palette");
                            item.dateShow = Qt.binding(() => pg.draft.dateShow === true);
                            item.dateDesign = Qt.binding(() => pg.draft.dateDesign || "inline");
                        }
                    }
                }
            }

            SpecimenCard {
                width: parent.width; height: pvCards.cardH
                title: I18n.tr("CALENDAR")
                on: pg.draft.calendarEnabled === true
                anchor: pg.draft.calendarAnchor || "bottom-right"
                userScale: Math.min(1, pg.draft.calendarScale || 1)
                userOpacity: pg.draft.calendarOpacity === undefined ? 1 : pg.draft.calendarOpacity
                natW: 330; natH: 210
                preview: Component {
                    Loader {
                        anchors.fill: parent
                        source: Qt.resolvedUrl("../CalendarPreview.qml")
                        onLoaded: {
                            item.style = Qt.binding(() => pg.draft.calendarStyle || "glass");
                            item.weeks = Qt.binding(() => pg.draft.calendarWeeks || 6);
                            item.showWeekNumbers = Qt.binding(() => pg.draft.calendarWeekNumbers === true);
                        }
                    }
                }
            }

            SpecimenCard {
                width: parent.width; height: pvCards.cardH
                title: I18n.tr("MUSIC")
                on: pg.draft.musicEnabled === true
                anchor: pg.draft.musicAnchor || "bottom-left"
                userScale: Math.min(1, pg.draft.musicScale || 1)
                userOpacity: pg.draft.musicOpacity === undefined ? 1 : pg.draft.musicOpacity
                natW: 400; natH: 216
                preview: Component {
                    Loader {
                        anchors.fill: parent
                        source: Qt.resolvedUrl("../MusicPreview.qml")
                        onLoaded: {
                            item.style = Qt.binding(() => pg.draft.musicStyle || "cover");
                            item.lyrics = Qt.binding(() => pg.draft.musicLyrics === true);
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
            item.appPickRequested.connect(pg.onSheetAppPick);
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
    property var appPickRow: null
    function onSheetAppPick(r) { pg.appPickRow = r; }

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

    // ── the music-app picker overlay (keybinds-style), for the "app" cell ────
    Loader {
        id: appPickerLoader
        anchors.fill: parent
        z: 101
        active: pg.appPickRow !== null
        source: active ? Qt.resolvedUrl("../AppPicker.qml") : ""
        onLoaded: {
            item.title = Qt.binding(() => pg.appPickRow ? I18n.tr(pg.appPickRow.label) : "");
            item.chosen.connect(function (cmd) {
                if (pg.appPickRow) pg.edit(pg.appPickRow.key, cmd);
                pg.appPickRow = null;
            });
            item.dismissed.connect(function () { pg.appPickRow = null; });
        }
    }
}
