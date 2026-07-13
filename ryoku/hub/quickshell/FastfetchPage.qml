pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import "Singletons"

// Fastfetch: a friendly editor for the branded terminal readout. config.jsonc
// stays the source of truth (the header's Edit config opens it raw); this reads
// it via `ryoku-hub fastfetch get`, edits a model, live-previews the readout via
// the backend (parsing its truecolor SGR into coloured runs), and writes back on
// Save. The emblem takes an image (an SVG is rasterized on import), an ASCII art
// file, a built-in, or none. Info rows toggle, reorder, and rename.
Item {
    id: page

    property var model: ({ "logo": { "kind": "none", "source": "", "width": 28, "height": 14, "padding": 3 }, "accent": "226;52;42", "rows": [] })
    property var committed: ({})
    property bool ready: false
    property int rev: 0

    readonly property bool dirty: {
        void page.rev;
        return page.ready && JSON.stringify(page.model) !== JSON.stringify(page.committed);
    }

    // info modules the Add menu offers, beyond the brand lines already present.
    readonly property var catalog: [
        { "key": "cpu", "label": "CPU" }, { "key": "gpu", "label": "GPU" },
        { "key": "memory", "label": "Memory" }, { "key": "disk", "label": "Disk" },
        { "key": "kernel", "label": "Kernel" }, { "key": "os", "label": "OS" },
        { "key": "host", "label": "Host" }, { "key": "uptime", "label": "Uptime" },
        { "key": "packages", "label": "Packages" }, { "key": "shell", "label": "Shell" },
        { "key": "terminal", "label": "Terminal" }, { "key": "wm", "label": "WM" },
        { "key": "de", "label": "Desktop" }, { "key": "battery", "label": "Battery" },
        { "key": "localip", "label": "Local IP" }, { "key": "board", "label": "Board" }
    ]
    readonly property var addOptions: {
        var out = [{ "key": "__header", "label": "Section header" }, { "key": "__break", "label": "Spacer" }, { "key": "__colors", "label": "Colour swatches" }];
        for (var i = 0; i < page.catalog.length; i++)
            out.push({ "key": page.catalog[i].key, "label": page.catalog[i].label, "hint": "module" });
        return out;
    }

    // ---- load ---------------------------------------------------------------
    Process {
        id: getProc
        command: ["ryoku-hub", "fastfetch", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    page.model = JSON.parse(this.text);
                    page.committed = JSON.parse(this.text);
                    if (!page.model.rows)
                        page.model.rows = [];
                    page.ready = true;
                    page.rev++;
                    page.queuePreview();
                } catch (e) {
                    console.log("fastfetch get parse failed: " + e);
                }
            }
        }
    }

    // ---- edit helpers (reassign model so bindings + dirty re-evaluate) -------
    function clone() { return JSON.parse(JSON.stringify(page.model)); }
    function commitModel(m) { page.model = m; page.rev++; page.queuePreview(); }
    function setLogo(k, v) { var m = page.clone(); m.logo[k] = v; page.commitModel(m); }
    function setAccent(v) { var m = page.clone(); m.accent = v; page.commitModel(m); }
    function setRow(i, k, v) { var m = page.clone(); m.rows[i][k] = v; page.commitModel(m); }
    function moveRow(i, d) {
        var j = i + d;
        if (j < 0 || j >= page.model.rows.length)
            return;
        var m = page.clone();
        var t = m.rows[i]; m.rows[i] = m.rows[j]; m.rows[j] = t;
        page.commitModel(m);
    }
    function removeRow(i) { var m = page.clone(); m.rows.splice(i, 1); page.commitModel(m); }
    function addFromMenu(key) {
        var m = page.clone();
        if (key === "__header")
            m.rows.push({ "kind": "header", "enabled": true, "text": "SECTION", "label": "Section header" });
        else if (key === "__break")
            m.rows.push({ "kind": "break", "enabled": true, "label": "Spacer" });
        else if (key === "__colors")
            m.rows.push({ "kind": "colors", "enabled": true, "label": "Colour swatches", "raw": { "type": "colors", "symbol": "circle" } });
        else {
            var lbl = key.toUpperCase();
            for (var i = 0; i < page.catalog.length; i++)
                if (page.catalog[i].key === key) lbl = page.catalog[i].label.toUpperCase();
            m.rows.push({ "kind": "module", "enabled": true, "module": key, "key": lbl, "label": lbl });
        }
        page.commitModel(m);
    }

    function accentHex() {
        var p = String(page.model.accent || "226;52;42").split(";");
        function h(n) { return ("0" + (parseInt(n) || 0).toString(16)).slice(-2); }
        return "#" + h(p[0]) + h(p[1]) + h(p[2]);
    }
    function hexToTriple(hex) {
        var c = String(hex);
        if (c.charAt(0) === "#") c = c.slice(1);
        return parseInt(c.substr(0, 2), 16) + ";" + parseInt(c.substr(2, 2), 16) + ";" + parseInt(c.substr(4, 2), 16);
    }
    function rowEditable(kind) { return kind === "tagline" || kind === "header" || kind === "module"; }
    function rowPlaceholder(kind) { return kind === "module" ? "LABEL" : "text"; }

    // ---- live preview (throttled) -------------------------------------------
    property var previewLines: []
    property bool previewPending: false
    Timer {
        id: throttle
        interval: 90
        onTriggered: {
            if (page.previewPending) {
                page.previewPending = false;
                page.previewNow();
                throttle.restart();
            }
        }
    }
    function queuePreview() {
        if (throttle.running)
            page.previewPending = true;
        else {
            page.previewNow();
            throttle.start();
        }
    }
    function previewNow() {
        previewProc.command = ["ryoku-hub", "fastfetch", "preview", JSON.stringify(page.model)];
        previewProc.running = true;
    }
    Process {
        id: previewProc
        stdout: StdioCollector { onStreamFinished: page.previewLines = page.parseAnsi(this.text) }
    }

    // fastfetch SGR (truecolor) -> lines of {text,color,bold} runs. mono font in
    // the view keeps column alignment; only 38;2;r;g;b, bold (1) and reset (0)
    // appear in the readout.
    function parseAnsi(s) {
        var lines = [];
        var raw = String(s || "").split("\n");
        for (var li = 0; li < raw.length; li++) {
            var line = raw[li], runs = [], color = Theme.cream, bold = false, buf = "", i = 0;
            while (i < line.length) {
                if (line.charCodeAt(i) === 27 && line.charAt(i + 1) === "[") {
                    if (buf.length) { runs.push({ "text": buf, "color": color, "bold": bold }); buf = ""; }
                    var j = line.indexOf("m", i);
                    if (j < 0) break;
                    var codes = line.substring(i + 2, j).split(";");
                    for (var k = 0; k < codes.length; k++) {
                        if (codes[k] === "0" || codes[k] === "") { color = Theme.cream; bold = false; }
                        else if (codes[k] === "1") bold = true;
                        else if (codes[k] === "38" && codes[k + 1] === "2") {
                            color = Qt.rgba((parseInt(codes[k + 2]) || 0) / 255, (parseInt(codes[k + 3]) || 0) / 255, (parseInt(codes[k + 4]) || 0) / 255, 1);
                            k += 4;
                        }
                    }
                    i = j + 1;
                } else { buf += line.charAt(i); i++; }
            }
            if (buf.length) runs.push({ "text": buf, "color": color, "bold": bold });
            lines.push(runs);
        }
        return lines;
    }

    // ---- save / revert ------------------------------------------------------
    Process { id: saveProc }
    function save() {
        throttle.stop();
        page.previewPending = false;
        saveProc.command = ["ryoku-hub", "fastfetch", "save", JSON.stringify(page.model)];
        saveProc.running = true;
        page.committed = page.clone();
        page.rev++;
    }
    function revert() {
        throttle.stop();
        page.previewPending = false;
        page.model = JSON.parse(JSON.stringify(page.committed));
        page.rev++;
        page.queuePreview();
    }
    Component.onDestruction: {
        // leaving with unsaved edits: nothing to undo on the live system (config
        // is only written on Save), so just stop pending previews.
        throttle.stop();
    }

    // ---- logo import --------------------------------------------------------
    Process {
        id: importProc
        property string pendingKind: "image"
        stdout: StdioCollector {
            onStreamFinished: {
                var p = String(this.text).trim();
                if (p.length) {
                    var m = page.clone();
                    m.logo.source = p;
                    m.logo.kind = importProc.pendingKind;
                    page.commitModel(m);
                }
            }
        }
    }
    function importLogo(path, kind) {
        importProc.pendingKind = kind;
        importProc.command = ["ryoku-hub", "fastfetch", "import-logo", path];
        importProc.running = true;
    }
    function openLogoFile() {
        var s = page.model.logo.source;
        if (!s || s.length === 0)
            return;
        Quickshell.execDetached(["kitty", "-e", "nvim", s]);
    }
    function previewInTerminal() { Quickshell.execDetached(["kitty", "-e", "sh", "-c", "ryoku-fastfetch; read -n1"]); }

    FileDialog {
        id: imageDlg
        title: "Choose a logo image"
        nameFilters: ["Images (*.svg *.png *.jpg *.jpeg *.webp)", "All files (*)"]
        onAccepted: page.importLogo("" + imageDlg.selectedFile, "image")
    }
    FileDialog {
        id: asciiDlg
        title: "Choose an ASCII art file"
        nameFilters: ["Text (*.txt *.ascii *.art)", "All files (*)"]
        onAccepted: page.importLogo("" + asciiDlg.selectedFile, "ascii")
    }

    // ---- layout: preview (left) + controls (right), action bar (bottom) -----
    Row {
        id: split
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: bar.top
        anchors.bottomMargin: 16
        spacing: 28

        // preview panel
        Rectangle {
            id: previewCard
            width: Math.round(split.width * 0.46)
            height: parent.height
            radius: Theme.radius
            color: "#0e0b07"
            border.width: 1
            border.color: Theme.line
            clip: true

            Text {
                id: pvLabel
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.leftMargin: 18
                anchors.topMargin: 16
                text: "READOUT PREVIEW"
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.letterSpacing: 2.4
                font.capitalization: Font.AllUppercase
            }

            // the real readout: logo column on the left, dossier on the right,
            // mirroring fastfetch's own layout.
            Flickable {
                id: pvFlick
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: pvLabel.bottom
                anchors.bottom: pvRule.top
                anchors.leftMargin: 18
                anchors.rightMargin: 10
                anchors.topMargin: 14
                anchors.bottomMargin: 12
                contentWidth: width
                contentHeight: pvRow.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 6 }

                Row {
                    id: pvRow
                    spacing: 16

                    Item {
                        width: 92
                        height: Math.max(readout.height, 92)
                        Image {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 84; height: 84
                            visible: page.model.logo.kind === "image" && page.model.logo.source.length > 0
                            source: (page.model.logo.kind === "image" && page.model.logo.source.length > 0)
                                ? (page.model.logo.source.indexOf("file:") === 0 ? page.model.logo.source : "file://" + page.model.logo.source) : ""
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 168; sourceSize.height: 168
                            smooth: true
                        }
                        Rectangle {
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 84; height: 84
                            radius: Theme.radius
                            visible: page.model.logo.kind !== "image"
                            color: Theme.surfaceLo
                            border.width: 1
                            border.color: Theme.line
                            Text {
                                anchors.centerIn: parent
                                text: page.model.logo.kind === "ascii" ? "TXT" : (page.model.logo.kind === "builtin" ? "\uf303" : "none")
                                color: Theme.faint
                                font.family: Theme.mono
                                font.pixelSize: page.model.logo.kind === "builtin" ? 30 : 12
                            }
                        }
                    }

                    Column {
                        id: readout
                        spacing: 0
                        Repeater {
                            model: page.previewLines
                            delegate: Row {
                                id: lineRow
                                required property var modelData
                                spacing: 0
                                Repeater {
                                    model: lineRow.modelData
                                    delegate: Text {
                                        required property var modelData
                                        text: modelData.text
                                        color: modelData.color
                                        font.family: Theme.mono
                                        font.pixelSize: 12
                                        font.weight: modelData.bold ? Font.Bold : Font.Normal
                                        textFormat: Text.PlainText
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: pvRule
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: pvBar.top
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                height: 1
                color: Theme.lineSoft
            }

            Item {
                id: pvBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 52
                HubButton {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Preview in terminal"
                    icon: "terminal"
                    onClicked: page.previewInTerminal()
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.model.logo.kind === "image" ? "kitty shows the real logo" : ""
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }

        // controls
        Flickable {
            id: ctrlFlick
            width: split.width - previewCard.width - split.spacing
            height: parent.height
            contentWidth: width
            contentHeight: ctrlCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded; width: 7 }

            Column {
                id: ctrlCol
                width: ctrlFlick.width - 12
                spacing: 26

                // EMBLEM
                SettingSection {
                    width: parent.width
                    title: "EMBLEM"
                    Segmented {
                        model: [
                            { "key": "image", "label": "Image" },
                            { "key": "ascii", "label": "ASCII" },
                            { "key": "builtin", "label": "Built-in" },
                            { "key": "none", "label": "None" }
                        ]
                        current: page.model.logo.kind
                        onSelected: (k) => page.setLogo("kind", k)
                    }
                    Row {
                        width: parent.width
                        spacing: 12
                        visible: page.model.logo.kind === "image" || page.model.logo.kind === "ascii"
                        Text {
                            width: parent.width - chooseBtn.width - openBtn.width - 24
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideMiddle
                            text: page.model.logo.source.length ? page.model.logo.source : "No file chosen"
                            color: page.model.logo.source.length ? Theme.cream : Theme.faint
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                        HubButton {
                            id: chooseBtn
                            anchors.verticalCenter: parent.verticalCenter
                            label: page.model.logo.kind === "ascii" ? "Choose .txt" : "Choose image"
                            icon: "image"
                            onClicked: page.model.logo.kind === "ascii" ? asciiDlg.open() : imageDlg.open()
                        }
                        HubButton {
                            id: openBtn
                            anchors.verticalCenter: parent.verticalCenter
                            label: "Open file"
                            icon: "terminal"
                            enabled: page.model.logo.source.length > 0
                            onClicked: page.openLogoFile()
                        }
                    }
                    Row {
                        width: parent.width
                        spacing: 22
                        visible: page.model.logo.kind === "image" || page.model.logo.kind === "ascii"
                        NumberField {
                            label: "Width"; unit: "col"
                            from: 0; to: 80; value: page.model.logo.width
                            onModified: (v) => page.setLogo("width", v)
                        }
                        NumberField {
                            label: "Height"; unit: "col"
                            from: 0; to: 60; value: page.model.logo.height
                            onModified: (v) => page.setLogo("height", v)
                        }
                        NumberField {
                            label: "Pad"; unit: "col"
                            from: 0; to: 20; value: page.model.logo.padding
                            onModified: (v) => page.setLogo("padding", v)
                        }
                    }
                    Text {
                        width: Math.min(parent.width, 560)
                        wrapMode: Text.WordWrap
                        visible: page.model.logo.kind === "image"
                        text: "PNG, JPG or WEBP; an SVG is rasterized to PNG on import. Square art reads best; it is drawn with the kitty graphics protocol in kitty, chafa elsewhere."
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }

                // ACCENT
                SettingSection {
                    width: parent.width
                    title: "ACCENT"
                    ColorField {
                        label: "Readout accent"
                        value: page.accentHex()
                        onModified: (c) => page.setAccent(page.hexToTriple(c))
                    }
                }

                // INFO
                SettingSection {
                    width: parent.width
                    title: "INFO"
                    Repeater {
                        model: page.model.rows
                        delegate: Rectangle {
                            id: rowItem
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: 40
                            radius: Theme.radius
                            color: rowHov.hovered ? Theme.surfaceLo : "transparent"
                            opacity: rowItem.modelData.enabled ? 1 : 0.45
                            HoverHandler { id: rowHov }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                RowMoveBtn { glyph: "\u2191"; onTapped: page.moveRow(rowItem.index, -1) }
                                RowMoveBtn { glyph: "\u2193"; onTapped: page.moveRow(rowItem.index, 1) }
                            }

                            Text {
                                id: rowLabel
                                anchors.left: parent.left
                                anchors.leftMargin: 62
                                anchors.verticalCenter: parent.verticalCenter
                                width: 120
                                elide: Text.ElideRight
                                text: rowItem.modelData.label || rowItem.modelData.kind
                                color: Theme.subtle
                                font.family: Theme.font
                                font.pixelSize: 13
                                font.weight: Font.Medium
                            }

                            // inline editor for tagline/header text or module key
                            Rectangle {
                                anchors.left: rowLabel.right
                                anchors.leftMargin: 10
                                anchors.right: rowTools.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                height: 28
                                radius: Theme.radius
                                visible: page.rowEditable(rowItem.modelData.kind)
                                color: Theme.surfaceLo
                                border.width: 1
                                border.color: ed.activeFocus ? Theme.ember : Theme.line
                                TextInput {
                                    id: ed
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    verticalAlignment: TextInput.AlignVCenter
                                    clip: true
                                    color: Theme.bright
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                    selectByMouse: true
                                    text: rowItem.modelData.kind === "module" ? (rowItem.modelData.key || "") : (rowItem.modelData.text || "")
                                    onEditingFinished: {
                                        var f = rowItem.modelData.kind === "module" ? "key" : "text";
                                        if (text !== (rowItem.modelData[f] || ""))
                                            page.setRow(rowItem.index, f, text);
                                    }
                                }
                            }

                            Row {
                                id: rowTools
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                RowMoveBtn {
                                    glyph: rowItem.modelData.enabled ? "\u25cf" : "\u25cb"
                                    tint: rowItem.modelData.enabled ? Theme.ember : Theme.faint
                                    onTapped: page.setRow(rowItem.index, "enabled", !rowItem.modelData.enabled)
                                }
                                RowMoveBtn { glyph: "\u2715"; onTapped: page.removeRow(rowItem.index) }
                            }
                        }
                    }
                    Dropdown {
                        label: "Add a row"
                        placeholder: "Add\u2026"
                        options: page.addOptions
                        current: ""
                        onChosen: (k) => page.addFromMenu(k)
                    }
                }
            }
        }
    }

    // ---- action bar ---------------------------------------------------------
    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 54
        radius: Theme.radius
        color: Theme.rail
        border.width: 1
        border.color: Theme.line

        Rectangle {
            id: dot
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 9; height: 9; radius: 4.5
            color: page.dirty ? Theme.gold : Theme.ok
        }
        Text {
            anchors.left: dot.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: page.dirty ? "Unsaved changes" : "Saved \u00b7 config.jsonc"
            color: page.dirty ? Theme.bright : Theme.dim
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Revert"
                icon: "close"
                enabled: page.dirty
                onClicked: page.revert()
            }
            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Save"
                icon: "check"
                primary: true
                enabled: page.dirty
                onClicked: page.save()
            }
        }
    }

    // small square glyph button used for the row's move / enable / remove tools.
    component RowMoveBtn: Item {
        id: rb
        property string glyph: ""
        property color tint: Theme.dim
        signal tapped()
        width: 22
        height: 22
        Rectangle {
            anchors.fill: parent
            radius: Theme.radius
            color: rbHov.hovered ? Theme.keyTop : "transparent"
        }
        Text {
            anchors.centerIn: parent
            text: rb.glyph
            color: rbHov.hovered ? Theme.bright : rb.tint
            font.family: Theme.font
            font.pixelSize: 13
        }
        HoverHandler { id: rbHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: rb.tapped() }
    }
}
