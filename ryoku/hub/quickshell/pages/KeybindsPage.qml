pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell.Io
import Quickshell
import Quickshell.Hyprland
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Keybinds (DESIGN.md section 8, SYSTEM). Two surfaces under one head: the live
// shortcut legend (every desktop bind, read straight from what Hyprland has
// bound via `ryoku-hub keybinds`) and the custom-bind editor (add/edit/remove
// user shortcuts layered on top). The legend is the source of truth; custom
// binds show in it once saved and reloaded. This is a full-bleed page: it owns
// its whole content region, so it draws its own head, its own tab switch and
// -- because the shell hides its global action bar -- its own Save/Revert
// controls for the shared hypr store. Custom binds live in that store under the
// `keybinds` key; nothing writes to disk until Save. Every value is a Token.
Item {
    id: pg

    property var hub
    readonly property bool fullBleed: true

    // guard the harness and the pre-load window: the shell injects a real hub
    // exposing hyprVal/hyprEdit; a bare probe object exposes neither.
    readonly property bool hubReady: pg.hub && typeof pg.hub.hyprVal === "function"
    // the live custom-bind array from the draft: a list of { keys, action, value }.
    readonly property var customRows: pg.hubReady ? (pg.hub.hyprVal("keybinds") || []) : []
    // gated so the editor empty state does not flash before `hypr get` returns.
    readonly property bool ready: pg.hubReady ? pg.hub.hyprLoaded === true : false
    readonly property int dirtyCount: pg.hubReady ? (pg.hub.dirty || 0) : 0

    // "all" = the shipped legend, "custom" = the editor. Transient, not persisted.
    property string tab: "all"

    // the shipped legend, parsed live from binds.lua by the backend. Owned here
    // (a self-contained page fetches its own backend), forwarded to both the
    // legend view and the conflict check.
    property var categories: []

    Process {
        id: legendGet
        command: ["ryoku-hub", "keybinds"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    pg.categories = o.categories || [];
                } catch (e) { console.log("keybinds: legend parse failed: " + e); }
            }
        }
    }

    // ── conflict detection (ported verbatim from KeybindsEditor) ────────────
    // catches what a hand-edited user.lua never would: a custom combo that
    // shadows a shipped bind, or duplicates another custom one. Keys are
    // normalised for case, spacing and modifier order before compare.
    function normKeys(s) {
        if (!s)
            return "";
        var parts = ("" + s).split("+");
        var out = [];
        for (var i = 0; i < parts.length; i++) {
            var t = parts[i].trim().toLowerCase();
            if (t.length)
                out.push(t);
        }
        out.sort();
        return out.join("+");
    }
    readonly property var shippedKeys: {
        var set = {};
        for (var c = 0; c < pg.categories.length; c++) {
            var binds = pg.categories[c].binds || [];
            for (var b = 0; b < binds.length; b++) {
                var k = pg.normKeys((binds[b].keys || []).join(" + "));
                if (k.length)
                    set[k] = true;
            }
        }
        return set;
    }
    function customCount(norm) {
        var n = 0;
        for (var i = 0; i < pg.customRows.length; i++)
            if (pg.normKeys(pg.customRows[i].keys) === norm)
                n++;
        return n;
    }
    // "" none, "shipped" shadows a Ryoku bind, "duplicate" repeats another custom.
    function rowConflict(i) {
        var k = pg.normKeys((pg.customRows[i] || ({})).keys);
        if (!k)
            return "";
        if (pg.shippedKeys[k])
            return "shipped";
        return pg.customCount(k) > 1 ? "duplicate" : "";
    }
    readonly property int conflictCount: {
        var n = 0;
        for (var i = 0; i < pg.customRows.length; i++)
            if (pg.rowConflict(i) !== "")
                n++;
        return n;
    }

    // the four bind actions, key -> visible label. keys are the exact strings the
    // Go backend switches on, so a rename here silently breaks settings.lua.
    readonly property var actionOpts: [
        { "key": "exec", "label": "Run command" },
        { "key": "close", "label": "Close window" },
        { "key": "fullscreen", "label": "Fullscreen" },
        { "key": "togglefloating", "label": "Toggle floating" }
    ]
    function labelIn(opts, key) {
        for (var i = 0; i < opts.length; i++)
            if (opts[i].key === key)
                return opts[i].label;
        return key;
    }
    function keyIn(opts, label) {
        for (var i = 0; i < opts.length; i++)
            if (opts[i].label === label)
                return opts[i].key;
        return label;
    }
    function labelsOf(opts) {
        return opts.map(function (o) { return o.label; });
    }

    // every mutation hands hyprEdit a fresh slice: the array swap rebinds the
    // Repeater and rebuilds the delegate owning a focused field, so text edits
    // commit on editing-finished, not per keystroke.
    function patch(i, key, val) {
        if (!pg.hubReady)
            return;
        var a = (pg.hub.hyprVal("keybinds") || []).slice();
        a[i] = Object.assign({}, a[i]);
        a[i][key] = val;
        pg.hub.hyprEdit("keybinds", a);
    }
    // switching action clears the value: only "exec" carries a command.
    function setAction(i, key) {
        if (!pg.hubReady)
            return;
        var a = (pg.hub.hyprVal("keybinds") || []).slice();
        a[i] = Object.assign({}, a[i]);
        a[i].action = key;
        if (key !== "exec")
            a[i].value = "";
        pg.hub.hyprEdit("keybinds", a);
    }
    function addRow() {
        if (!pg.hubReady)
            return;
        var a = (pg.hub.hyprVal("keybinds") || []).slice();
        a.push({ "keys": "", "action": "exec", "value": "" });
        pg.hub.hyprEdit("keybinds", a);
    }
    function removeRow(i) {
        if (!pg.hubReady)
            return;
        var a = (pg.hub.hyprVal("keybinds") || []).slice();
        a.splice(i, 1);
        pg.hub.hyprEdit("keybinds", a);
    }
    function clearAll() {
        if (pg.hubReady)
            pg.hub.hyprEdit("keybinds", []);
    }
    function saveAll() {
        if (pg.hubReady)
            pg.hub.save();
    }
    function revertAll() {
        if (pg.hubReady)
            pg.hub.revert();
    }

    // ── chord recorder ──────────────────────────────────────────────────────
    // The star of this page: instead of typing "SUPER + J", the user clicks
    // record and presses the combo. Capture is safe because the Hub first enters
    // a do-nothing Hyprland submap (modules/record.lua): in a submap only its
    // own binds fire, so a live chord like SUPER + Q passes through to be read
    // here instead of closing the Hub. recordRow is the row being recorded
    // (-1 = idle); the overlay below drives it.
    property int recordRow: -1

    function enterRecordSubmap() { Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"record\")"]); }
    function exitRecordSubmap() { Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.submap(\"reset\")"]); }

    function startRecord(i) {
        if (!pg.hubReady || i < 0)
            return;
        pg.recordRow = i;
        pg.enterRecordSubmap();
        recordTimeout.restart();
    }
    // commit true writes the captured chord to the row; false just cancels.
    function stopRecord(commit, chord) {
        recordTimeout.stop();
        pg.exitRecordSubmap();
        var i = pg.recordRow;
        pg.recordRow = -1;
        if (commit && chord && i >= 0)
            pg.patch(i, "keys", chord);
    }

    // never leave the keyboard stranded in the record submap: a hard ceiling
    // exits it even if every other path fails.
    Timer {
        id: recordTimeout
        interval: 15000
        onTriggered: pg.stopRecord(false, "")
    }

    // the submap's Escape binding (or any external reset) fires this; if we were
    // still recording, treat it as a cancel so the overlay closes cleanly.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (pg.recordRow >= 0 && event.name === "submap" && (event.data === "" || event.data === "reset"))
                pg.stopRecord(false, "");
        }
    }

    // Qt key code -> the token Hyprland binds on. Covers letters, digits, the
    // function row, navigation, and the common punctuation; anything unmapped
    // returns "" so the recorder keeps waiting (and the field stays typeable for
    // the exotic rest).
    function qtKeyName(k) {
        if (k >= Qt.Key_A && k <= Qt.Key_Z)
            return String.fromCharCode(k);
        if (k >= Qt.Key_0 && k <= Qt.Key_9)
            return String.fromCharCode(k);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F12)
            return "F" + (k - Qt.Key_F1 + 1);
        switch (k) {
        case Qt.Key_Return: case Qt.Key_Enter: return "Return";
        case Qt.Key_Space: return "Space";
        case Qt.Key_Tab: return "Tab";
        case Qt.Key_Left: return "Left";
        case Qt.Key_Right: return "Right";
        case Qt.Key_Up: return "Up";
        case Qt.Key_Down: return "Down";
        case Qt.Key_Backspace: return "BackSpace";
        case Qt.Key_Delete: return "Delete";
        case Qt.Key_Home: return "Home";
        case Qt.Key_End: return "End";
        case Qt.Key_PageUp: return "Prior";
        case Qt.Key_PageDown: return "Next";
        case Qt.Key_Insert: return "Insert";
        case Qt.Key_Print: return "Print";
        case Qt.Key_Minus: return "minus";
        case Qt.Key_Equal: return "equal";
        case Qt.Key_Comma: return "comma";
        case Qt.Key_Period: return "period";
        case Qt.Key_Slash: return "slash";
        case Qt.Key_Backslash: return "backslash";
        case Qt.Key_Semicolon: return "semicolon";
        case Qt.Key_Apostrophe: return "apostrophe";
        case Qt.Key_BracketLeft: return "bracketleft";
        case Qt.Key_BracketRight: return "bracketright";
        case Qt.Key_QuoteLeft: return "grave";
        }
        return "";
    }
    // build the Hyprland combo from a KeyEvent: held modifiers + the main key,
    // in the order binds.lua writes them. "" until a non-modifier key lands.
    function chordFrom(event) {
        var name = pg.qtKeyName(event.key);
        if (name === "")
            return "";
        var mods = [];
        if (event.modifiers & Qt.MetaModifier) mods.push("SUPER");
        if (event.modifiers & Qt.ControlModifier) mods.push("CTRL");
        if (event.modifiers & Qt.AltModifier) mods.push("ALT");
        if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT");
        mods.push(name);
        return mods.join(" + ");
    }
    // the shipped bind a normalised chord shadows, by description, for the
    // conflict badge. "" when nothing shipped matches.
    function shippedDescFor(norm) {
        for (var c = 0; c < pg.categories.length; c++) {
            var binds = pg.categories[c].binds || [];
            for (var b = 0; b < binds.length; b++) {
                if (pg.normKeys((binds[b].keys || []).join(" + ")) === norm)
                    return binds[b].desc || "a shipped shortcut";
            }
        }
        return "";
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
                text: "SYSTEM"; color: Tokens.inkMuted; font.family: Tokens.ui
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            text: "Keybinds"; color: Tokens.ink
            font.family: Tokens.display; font.pixelSize: Tokens.fTitle
        }
        Text {
            width: Math.min(parent.width, 720)
            text: "Every desktop shortcut, read live from what Hyprland actually has bound, plus the custom binds you layer on top. Custom shortcuts show in the legend and are checked against the shipped ones for conflicts."
            color: Tokens.inkMuted; font.family: Tokens.ui
            font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap
        }
    }

    // marginalia in the head's right margin, dressing the dead space beside the title. Ink only.
    Marginalia {
        anchors { right: parent.right; top: head.top }
        anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s1
        kana: "操作"
        index: "02"; label: "SYSTEM"
        glyph: "meander"; glyph2: "torii"
    }

    // ── tab switch: Shortcuts (legend) | Custom (editor) ──
    Tabs {
        id: tabs
        anchors.left: parent.left
        anchors.leftMargin: Tokens.s6
        anchors.top: head.bottom
        anchors.topMargin: Tokens.s5
        options: ["Shortcuts", "Custom"]
        current: pg.tab === "all" ? "Shortcuts" : "Custom"
        onChose: (label) => pg.tab = (label === "Shortcuts" ? "all" : "custom")
    }

    // ── the tab body: a Loader swaps the whole subtree, fading the new one in ──
    Loader {
        id: loader
        anchors {
            left: parent.left; right: parent.right
            top: tabs.bottom; bottom: parent.bottom
            leftMargin: Tokens.s6; rightMargin: Tokens.s6
            topMargin: Tokens.s4; bottomMargin: Tokens.s6
        }
        sourceComponent: pg.tab === "all" ? legendComp : customComp
        onLoaded: {
            if (!item)
                return;
            item.opacity = 0;
            fade.restart();
        }
    }
    // content exchange -> swap token; nothing travels, so a plain fade is right.
    NumberAnimation {
        id: fade
        target: loader.item; property: "opacity"; to: 1
        duration: Tokens.swap; easing.type: Tokens.ease
    }

    // ── the shipped-bind legend (read-only) ─────────────────────────────────
    Component {
        id: legendComp

        Flickable {
            id: legend
            contentWidth: width
            contentHeight: col.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

            Column {
                id: col
                width: legend.width - Tokens.s3   // reserve a lane for the scroll rail
                spacing: Tokens.s5

                Repeater {
                    model: pg.categories

                    delegate: Column {
                        id: grp
                        required property var modelData
                        width: col.width
                        spacing: 0

                        // section head: dot + category caps + hairline leader.
                        Item {
                            width: parent.width
                            height: 30
                            Row {
                                id: grpLabel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Tokens.s2
                                Rectangle {
                                    width: 4; height: 4; color: Tokens.ink
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: grp.modelData.name; color: Tokens.ink
                                    font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                                    font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                                    font.capitalization: Font.AllUppercase
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Rectangle {
                                anchors.left: grpLabel.right; anchors.leftMargin: Tokens.s3
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 1; color: Tokens.lineSoft
                            }
                        }

                        Repeater {
                            model: grp.modelData.binds

                            delegate: Column {
                                id: bindWrap
                                required property var modelData
                                required property int index
                                width: grp.width

                                // row separators inside the group.
                                Rectangle {
                                    visible: bindWrap.index > 0
                                    width: parent.width; height: 1; color: Tokens.lineSoft
                                }

                                // one legend line: description left, keycaps right.
                                Item {
                                    width: parent.width
                                    height: 44

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: caps.left; anchors.rightMargin: Tokens.s4
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: bindWrap.modelData.desc || ""
                                        color: Tokens.inkDim
                                        font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                                        elide: Text.ElideRight
                                    }

                                    Row {
                                        id: caps
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Tokens.s1

                                        Repeater {
                                            model: bindWrap.modelData.keys || []

                                            delegate: Row {
                                                id: capWrap
                                                required property var modelData
                                                required property int index
                                                spacing: Tokens.s1

                                                Text {
                                                    visible: capWrap.index > 0
                                                    height: 22
                                                    verticalAlignment: Text.AlignVCenter
                                                    text: "+"
                                                    color: Tokens.inkFaint
                                                    font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                                                }
                                                // keycap: hairline rect, mono, inkFaint (file-truth chrome).
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    implicitHeight: 22
                                                    implicitWidth: Math.max(22, capLabel.implicitWidth + 14)
                                                    radius: Tokens.radius
                                                    color: "transparent"
                                                    border.width: Tokens.border
                                                    border.color: Tokens.line
                                                    Text {
                                                        id: capLabel
                                                        anchors.centerIn: parent
                                                        text: capWrap.modelData
                                                        color: Tokens.inkFaint
                                                        font.family: Tokens.mono; font.pixelSize: Tokens.fMicro
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // footer explainer: where the legend comes from, and the caveat.
                Text {
                    width: col.width
                    wrapMode: Text.WordWrap
                    text: "Read live from Ryoku's binds plus your Hub custom shortcuts. Binds added by hand in ~/.config/hypr/user.lua do not appear here and are not conflict-checked, so add custom shortcuts in the Custom tab."
                    color: Tokens.inkFaint; font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall; lineHeight: 1.3
                }
            }
        }
    }

    // ── the custom-bind editor ──────────────────────────────────────────────
    Component {
        id: customComp

        Item {
            id: editor

            // which row's action catalogue is open; -1 = closed.
            property int pickerRow: -1
            function openPicker(i) { editor.pickerRow = i; picker.open(); }

            // intro: load-bearing product guidance, not decoration.
            Text {
                id: intro
                anchors { left: parent.left; right: parent.right; top: parent.top }
                wrapMode: Text.WordWrap
                text: "Custom shortcuts layered over the ones Ryoku ships and kept in the Hub, so they show in the Shortcuts legend and get conflict-checked. Click record and press the combo -- even SUPER + Q is captured safely -- or type it the way Hyprland writes it, e.g. SUPER + J. Binds hand-written in ~/.config/hypr/user.lua never appear here and are not conflict-checked."
                color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                lineHeight: 1.3
            }

            // section head: dot + SHORTCUTS + leader + count + add.
            Item {
                id: sect
                anchors { left: parent.left; right: parent.right; top: intro.bottom; topMargin: Tokens.s4 }
                height: 32

                Row {
                    id: sectLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.s2
                    Rectangle {
                        width: 4; height: 4; color: Tokens.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "SHORTCUTS"; color: Tokens.ink; font.family: Tokens.ui
                        font.pixelSize: Tokens.fMicro; font.weight: Font.Medium
                        font.letterSpacing: Tokens.trackMark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    id: sectActions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.s3

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        // an entry count is file-truth chrome, so mono.
                        text: pg.customRows.length + (pg.customRows.length === 1 ? " BIND" : " BINDS")
                        color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
                    }
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "+"
                        armed: pg.hubReady
                        // add a row and drop straight into recording it: the
                        // one-click path to a brand-new shortcut.
                        onAct: { pg.addRow(); Qt.callLater(function() { pg.startRecord(pg.customRows.length - 1); }); }
                    }
                }

                Rectangle {
                    anchors.left: sectLabel.right; anchors.right: sectActions.left
                    anchors.leftMargin: Tokens.s3; anchors.rightMargin: Tokens.s3
                    anchors.verticalCenter: parent.verticalCenter
                    height: 1; color: Tokens.lineSoft
                }
            }

            // ── the scrolling bind list ──
            Flickable {
                id: flick
                anchors {
                    left: parent.left; right: parent.right
                    top: sect.bottom; bottom: bar.top
                    topMargin: Tokens.s4; bottomMargin: Tokens.s3
                }
                contentWidth: width
                contentHeight: Math.max(rowsCol.height, height)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

                Column {
                    id: rowsCol
                    width: flick.width - Tokens.s3   // reserve a lane for the scroll rail
                    spacing: Tokens.s2

                    Repeater {
                        model: pg.customRows

                        delegate: Rectangle {
                            id: rowRect
                            required property int index
                            required property var modelData

                            readonly property int lineH: 30
                            readonly property real gap: Tokens.s2
                            readonly property real removeW: 26
                            readonly property real keysW: 200
                            readonly property real recW: 26
                            readonly property string act: rowRect.modelData.action || "exec"
                            readonly property bool needsValue: act === "exec"
                            readonly property string conflict: pg.rowConflict(rowRect.index)

                            width: rowsCol.width
                            height: Tokens.s3 * 2 + lineH + (conflict !== "" ? 18 : 0)
                            radius: Tokens.radius
                            color: rh.hovered ? Tokens.tint5 : "transparent"
                            border.width: Tokens.border
                            // a conflict flags itself in solid ink -- the brightest
                            // tell on the sheet, colour-free (DESIGN.md section 1).
                            border.color: conflict !== "" ? Tokens.ink
                                : (rh.hovered ? Tokens.lineStrong : Tokens.line)
                            Behavior on color { ColorAnimation { duration: Tokens.snap } }
                            Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

                            HoverHandler { id: rh }

                            // ── controls line ──
                            Item {
                                id: ctlRow
                                anchors {
                                    left: parent.left; right: parent.right; top: parent.top
                                    leftMargin: Tokens.s3; rightMargin: Tokens.s3; topMargin: Tokens.s3
                                }
                                height: rowRect.lineH

                                // key combo: a Hyprland combo string, so mono.
                                Field {
                                    id: keysF
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: rowRect.keysW - rowRect.recW - rowRect.gap
                                    tabular: true
                                    placeholder: "SUPER + J"
                                    text: rowRect.modelData.keys || ""
                                    onCommitted: (v) => {
                                        if (v !== (rowRect.modelData.keys || ""))
                                            pg.patch(rowRect.index, "keys", v);
                                    }
                                }

                                // record: capture the combo by pressing it. Safe
                                // because startRecord enters the record submap
                                // first, so the live chord reaches the field, not
                                // Hyprland.
                                IconBtn {
                                    id: recBtn
                                    anchors.left: keysF.right
                                    anchors.leftMargin: rowRect.gap
                                    anchors.verticalCenter: parent.verticalCenter
                                    glyph: "\u25CF"
                                    armed: pg.hubReady
                                    onAct: pg.startRecord(rowRect.index)
                                }

                                IconBtn {
                                    id: removeBtn
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    // a paired minus, not a trash icon: remove is not
                                    // danger and there is no red on the sheet.
                                    glyph: "\u2212"
                                    onAct: pg.removeRow(rowRect.index)
                                }

                                // command box: shown only for "Run command"; the foot
                                // bar fills whatever is left when it is hidden.
                                Item {
                                    id: cmdBox
                                    anchors.right: removeBtn.left
                                    anchors.rightMargin: rowRect.gap
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: rowRect.lineH
                                    width: rowRect.needsValue
                                        ? Math.max(140, Math.round((parent.width - rowRect.keysW - rowRect.removeW - rowRect.gap * 3) * 0.5))
                                        : 0

                                    // command is a shell string, so mono.
                                    Field {
                                        id: cmdF
                                        anchors.fill: parent
                                        visible: rowRect.needsValue
                                        tabular: true
                                        placeholder: "command to run"
                                        text: rowRect.modelData.value || ""
                                        onCommitted: (v) => {
                                            if (v !== (rowRect.modelData.value || ""))
                                                pg.patch(rowRect.index, "value", v);
                                        }
                                    }
                                }

                                // the action catalogue foot bar.
                                PickBar {
                                    id: actionBar
                                    anchors.left: recBtn.right
                                    anchors.leftMargin: rowRect.gap
                                    anchors.right: cmdBox.left
                                    anchors.rightMargin: rowRect.needsValue ? rowRect.gap : 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    value: pg.labelIn(pg.actionOpts, rowRect.act)
                                    count: pg.actionOpts.length
                                    onOpened: editor.openPicker(rowRect.index)
                                }
                            }

                            // conflict note: names what it clashes with, in ink,
                            // no colour (DESIGN.md section 1).
                            Text {
                                visible: rowRect.conflict !== ""
                                anchors.left: parent.left; anchors.leftMargin: Tokens.s3
                                anchors.bottom: parent.bottom; anchors.bottomMargin: Tokens.s2
                                text: {
                                    if (rowRect.conflict === "duplicate")
                                        return "Duplicate of another custom bind";
                                    var d = pg.shippedDescFor(pg.normKeys(rowRect.modelData.keys || ""));
                                    return d ? ("Shadows shipped: " + d) : "Shadows a shipped bind";
                                }
                                color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                            }
                        }
                    }
                }
            }

            // empty state, gated on load so it does not flash before data arrives.
            Text {
                anchors.centerIn: flick
                visible: pg.ready && pg.customRows.length === 0
                text: "No custom shortcuts yet. Add one to bind a command or a window action."
                color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
            }

            // ── action bar: status + Clear all / Revert / Save ──
            // this page is full-bleed, so the shell's global action bar is
            // hidden; this bar is the only way to persist the shared store.
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

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.s2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.s3

                    // status dot: filled ink while dirty or in conflict; a heartbeat
                    // pulse (the one perpetual animation) only while dirty.
                    Rectangle {
                        id: dot
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6; height: 6; radius: 3
                        antialiasing: false
                        readonly property bool lit: pg.conflictCount > 0 || pg.dirtyCount > 0
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
                        text: pg.conflictCount > 0
                            ? (pg.conflictCount + " conflict with a shipped or duplicate combo")
                            : (pg.dirtyCount > 0 ? "Unsaved shortcuts" : "Saved")
                        color: (pg.conflictCount > 0 || pg.dirtyCount > 0) ? Tokens.ink : Tokens.inkMuted
                        font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                        font.weight: Font.Medium
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.s2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.s3

                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RESTORE DEFAULTS"
                        armed: pg.customRows.length > 0
                        onAct: pg.clearAll()
                    }
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "REVERT"
                        armed: pg.dirtyCount > 0
                        onAct: pg.revertAll()
                    }
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SAVE"
                        primary: true
                        armed: pg.dirtyCount > 0
                        onAct: pg.saveAll()
                    }
                }

                // marginalia dressing the empty bar centre between status and actions -- a dead margin. Ink only.
                Marginalia {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    kana: "操作"
                    glyph: "meander"; glyph2: "torii"
                }
            }

            // ── the action catalogue overlay (Picker), shared across rows ──
            MouseArea {
                id: scrim
                anchors.fill: parent
                visible: editor.pickerRow >= 0
                z: 100
                // a bare click-catcher: dismiss on an outside click. No fill --
                // translucency is banned on app surfaces (DESIGN.md section 6).
                onClicked: editor.pickerRow = -1

                Picker {
                    id: picker
                    anchors.centerIn: parent
                    title: "Action"
                    options: pg.labelsOf(pg.actionOpts)
                    current: {
                        if (editor.pickerRow < 0)
                            return "";
                        var r = (pg.customRows[editor.pickerRow] || ({})).action || "exec";
                        return pg.labelIn(pg.actionOpts, r);
                    }
                    onChose: (label) => {
                        pg.setAction(editor.pickerRow, pg.keyIn(pg.actionOpts, label));
                        editor.pickerRow = -1;
                    }
                    onDismissed: editor.pickerRow = -1

                    // absorb clicks inside the card so the scrim does not treat a
                    // header/padding tap as an outside dismiss.
                    MouseArea { anchors.fill: parent; z: -1 }
                }
            }

            // ── chord recorder overlay ──────────────────────────────────────
            // shown while a row records. The capture Item holds keyboard focus so
            // the combo the record submap lets through arrives here as a plain
            // KeyEvent; chordFrom turns it into the string Hyprland binds on.
            MouseArea {
                id: recScrim
                anchors.fill: parent
                visible: pg.recordRow >= 0
                z: 200
                onClicked: pg.stopRecord(false, "")
                onVisibleChanged: if (visible) capture.forceActiveFocus()

                Item {
                    id: capture
                    anchors.fill: parent
                    focus: true
                    Keys.onPressed: (event) => {
                        event.accepted = true;
                        if (event.isAutoRepeat)
                            return;
                        if (event.key === Qt.Key_Escape) {
                            pg.stopRecord(false, "");
                            return;
                        }
                        var chord = pg.chordFrom(event);
                        if (chord !== "")
                            pg.stopRecord(true, chord);
                    }
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 340; height: 156
                    radius: Tokens.radius
                    color: Tokens.paper
                    border.width: Tokens.border
                    border.color: Tokens.lineStrong

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - Tokens.s4 * 2
                        spacing: Tokens.s3

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "PRESS YOUR SHORTCUT"
                            color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                            font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: "Hold your modifiers and tap the key. Esc cancels."
                            color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                        }
                        Btn {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "CANCEL"
                            armed: true
                            onAct: pg.stopRecord(false, "")
                        }
                    }

                    // absorb clicks inside the card so the scrim does not dismiss.
                    MouseArea { anchors.fill: parent; z: -1 }
                }
            }
        }
    }
}
