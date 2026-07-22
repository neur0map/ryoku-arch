import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Renders a page from its schema. A setting is a row of data; where it lands
// and what draws it are decided by Spans and its kind, so adding one is an
// edit to the schema and nothing else.
//
// The draft object holds live values and is the page's own; this only reads it
// and reports edits back. The one file it writes is the weather resolver cache
// (the picked place's coords the weather widgets read), on a location pick.
Item {
    id: sheet

    property var schema: []          // [{ tab, group, key, label, desc, ctl, src, opts, lo, hi, unit, pct }]
    property var draft: null         // the page's live values
    property var defaults: ({})      // factory values, for the struck default
    property string tab: ""
    property string query: ""
    // when set (e.g. "barStyle"), a schema row carrying a `styles` list is shown
    // only while draft[styleKey] is in it, so each bar style exposes just the
    // settings its bar actually reads. reads draft (replaced on edit) so it is live.
    property string styleKey: ""

    signal edited(string key, var value)

    readonly property var rows: {
        var q = query.toLowerCase();
        return schema.filter(function (r) {
            if (sheet.styleKey !== "" && r.styles && sheet.draft
                && r.styles.indexOf(sheet.draft[sheet.styleKey]) < 0) return false;
            if (r.tab !== sheet.tab && query === "") return false;
            if (query === "") return true;
            return (r.label + " " + (r.desc || "") + " " + r.key).toLowerCase().indexOf(q) >= 0;
        });
    }
    readonly property var groups: {
        var g = [];
        for (var i = 0; i < rows.length; i++)
            if (g.indexOf(rows[i].group) < 0) g.push(rows[i].group);
        return g;
    }

    function val(r) {
        if (!draft) return "";
        var v = draft[r.key];
        return v === undefined ? "" : v;
    }
    function shown(r) {
        var v = val(r);
        if (r.ctl === "sw") return v ? "ON" : "OFF";
        if (r.ctl === "slid" && r.pct) return String(Math.round(v * 100));
        if (r.ctl === "multi") return String((v || []).length);
        if (r.ctl === "color") return String(v).toUpperCase();
        return String(v);
    }
    function shownDef(r) {
        var d = defaults[r.key];
        if (d === undefined) return "";
        if (r.ctl === "sw") return d ? "ON" : "OFF";
        if (r.ctl === "slid" && r.pct) return String(Math.round(d * 100));
        if (r.ctl === "multi") return String((d || []).length);
        return String(d);
    }
    function isChanged(r) {
        var v = val(r), d = defaults[r.key];
        if (d === undefined) return false;
        if (r.ctl === "multi") return JSON.stringify(v || []) !== JSON.stringify(d || []);
        return v !== d;
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.height + Tokens.s5
        clip: true
        ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: flick.width - 14
            spacing: Tokens.s5

            Repeater {
                model: sheet.groups
                Section {
                    id: sect
                    required property string modelData
                    width: col.width
                    title: I18n.tr(modelData === "" ? "OTHER" : modelData)

                    // bento: pack this group's declared spans into flush rows,
                    // so no row ends in dead space. minSpan keeps a cell usable
                    // on a narrow sheet.
                    readonly property var groupRows: sheet.rows.filter(function (r) { return r.group === sect.modelData })
                    readonly property int minSpan: {
                        for (var n = 1; n <= Spans.cols; n++)
                            if (n * colWidth + (n - 1) * gutter >= 290) return n;
                        return Spans.cols;
                    }
                    readonly property var packed: Spans.pack(
                        groupRows.map(function (r) { return (r.ctl === "seg" && (r.opts || []).length >= 3) ? Spans.cols : Spans.of(r.ctl, (r.opts || []).length); }),
                        minSpan)

                    Repeater {
                        model: sect.groupRows
                        Cell {
                            id: cell
                            required property var modelData
                            required property int index
                            readonly property var r: modelData
                            readonly property int optCount: (r.opts || []).length

                            width: sect.span(sect.packed[index] || 4)
                            height: neededHeight
                            block: Spans.isBlock(r.ctl) || (r.ctl === "seg" && cell.optCount >= 3)
                            footH: (r.ctl === "pick" || r.ctl === "text" || r.ctl === "image" || r.ctl === "location" || r.ctl === "color" || r.ctl === "action") ? 34 : 0
                            controlWidth: Spans.inlineWidth(r.ctl, optCount, width)

                            label: I18n.tr(r.label)
                            desc: I18n.tr(r.desc || "")
                            unit: r.pct ? "%" : (r.unit || "")
                            value: (r.ctl === "text" || r.ctl === "seg" || r.ctl === "image" || r.ctl === "location" || r.ctl === "color") ? "" : sheet.shown(r)
                            def: sheet.shownDef(r)
                            changed: sheet.isChanged(r)
                            source: r.src + ".json"

                            Loader {
                                anchors.fill: parent
                                sourceComponent: {
                                    switch (cell.r.ctl) {
                                    case "sw": return swC;
                                    case "step": return stepC;
                                    case "slid": return slidC;
                                    case "seg": return segC;
                                    case "chips": return chipsC;
                                    case "multi": return multiC;
                                    case "pick": return pickC;
                                    case "gallery": return galleryC;
                                    case "image": return imageC;
                                    case "location": return locationC;
                                    case "color": return colorC;
                                    case "action": return actionC;
                                    default: return textC;
                                    }
                                }
                            }

                            // an action button (e.g. AI translation): runs a tool
                            // for the current language in a terminal.
                            Component {
                                id: actionC
                                Btn {
                                    anchors { left: parent.left; bottom: parent.bottom }
                                    text: I18n.tr(cell.r.actionLabel || "Generate")
                                    onAct: {
                                        if (cell.r.key === "i18nGenerate")
                                            Quickshell.execDetached(["kitty", "--class", "ryoku-i18n", "-e", "sh", "-c",
                                                "ryoku-i18n llm " + I18n.lang + "; echo; read -n1 -rsp 'Done. Press any key to close…'; echo"]);
                                    }
                                }
                            }
                            Component {
                                id: swC
                                Sw {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    on: !!sheet.val(cell.r)
                                    onToggled: (v) => sheet.edited(cell.r.key, v)
                                }
                            }
                            Component {
                                id: stepC
                                Step {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    value: Number(sheet.val(cell.r)) || 0
                                    from: Number(cell.r.lo) || 0
                                    to: Number(cell.r.hi) || 100
                                    onModified: (v) => sheet.edited(cell.r.key, v)
                                }
                            }
                            Component {
                                id: slidC
                                Slid {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(cell.width * 0.42)
                                    value: Number(sheet.val(cell.r)) || 0
                                    from: Number(cell.r.lo) || 0
                                    to: Number(cell.r.hi) || 1
                                    onModified: (v) => sheet.edited(cell.r.key, v)
                                }
                            }
                            Component {
                                id: segC
                                Seg {
                                    anchors.right: cell.block ? undefined : parent.right
                                    anchors.left: cell.block ? parent.left : undefined
                                    anchors.verticalCenter: parent.verticalCenter
                                    options: cell.r.opts
                                    current: String(sheet.val(cell.r))
                                    onChose: (k) => sheet.edited(cell.r.key, k)
                                }
                            }
                            Component {
                                id: chipsC
                                Chips {
                                    anchors.fill: parent
                                    options: cell.r.opts
                                    current: String(sheet.val(cell.r))
                                    onChose: (k) => sheet.edited(cell.r.key, k)
                                }
                            }
                            Component {
                                id: multiC
                                Multi {
                                    anchors.fill: parent
                                    options: cell.r.opts
                                    chosen: sheet.val(cell.r) || []
                                    onToggled: (k) => {
                                        var l = (sheet.val(cell.r) || []).slice();
                                        var i = l.indexOf(k);
                                        if (i >= 0) l.splice(i, 1); else l.push(k);
                                        sheet.edited(cell.r.key, l);
                                    }
                                }
                            }
                            Component {
                                id: galleryC
                                Gallery {
                                    anchors.fill: parent
                                    options: Silhouette.skins
                                    current: String(sheet.val(cell.r))
                                    onChose: (k) => sheet.edited(cell.r.key, k)
                                }
                            }
                            Component {
                                id: pickC
                                PickBar {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    value: String(sheet.val(cell.r))
                                    count: cell.optCount
                                    onOpened: sheet.openPick(cell.r)
                                }
                            }
                            Component {
                                id: textC
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    radius: Tokens.radius
                                    border.width: ti.activeFocus ? 2 : Tokens.border
                                    border.color: ti.activeFocus ? Tokens.ink : Tokens.line
                                    TextInput {
                                        id: ti
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        verticalAlignment: Text.AlignVCenter
                                        clip: true
                                        // show the head of a long value at rest, not
                                        // a scrolled-to-the-cursor tail.
                                        autoScroll: activeFocus
                                        color: Tokens.ink
                                        font.family: Tokens.ui
                                        font.pixelSize: 12
                                        selectByMouse: true
                                        text: String(sheet.val(cell.r))
                                        onEditingFinished: sheet.edited(cell.r.key, text)
                                        // commit as you type, not only on focus
                                        // loss: clicking Save (a TapHandler) never
                                        // blurs this field, so an editingFinished-
                                        // only commit dropped the typed value and
                                        // the setting "would not save".
                                        onTextEdited: sheet.edited(cell.r.key, text)
                                    }
                                }
                            }
                            // a colour: a live swatch + hex, with a visual picker
                            // on the swatch, instead of the bare text field this
                            // used to fall through to (ctl "color" had no case).
                            Component {
                                id: colorC
                                ColorField {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    height: 30
                                    value: String(sheet.val(cell.r))
                                    onChosen: (v) => sheet.edited(cell.r.key, v)
                                }
                            }
                            // an image mark: a live thumbnail of the current
                            // file plus Choose (opens the shared file picker,
                            // hosted by the page) and Clear (falls back to the
                            // text glyph). far friendlier than typing a path.
                            Component {
                                id: imageC
                                Row {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    height: 30
                                    spacing: Tokens.s2
                                    Rectangle {
                                        id: imgThumb
                                        width: 46; height: 28
                                        anchors.verticalCenter: parent.verticalCenter
                                        radius: Tokens.radius
                                        color: "transparent"
                                        border.width: Tokens.border
                                        border.color: Tokens.line
                                        clip: true
                                        readonly property string src: String(sheet.val(cell.r))
                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            visible: imgThumb.src !== ""
                                            source: imgThumb.src === "" ? "" : (imgThumb.src.indexOf("://") >= 0 ? imgThumb.src : "file://" + imgThumb.src)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            sourceSize.width: 140
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: imgThumb.src === ""
                                            text: "力"
                                            color: Tokens.inkFaint
                                            font.family: Tokens.jp
                                            font.pixelSize: 13
                                        }
                                    }
                                    Btn {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "CHOOSE…"
                                        onAct: sheet.imagePick(cell.r)
                                    }
                                    Btn {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: String(sheet.val(cell.r)) !== ""
                                        text: "CLEAR"
                                        onAct: sheet.edited(cell.r.key, "")
                                    }
                                }
                            }
                            // a location field with live autocomplete: as you
                            // type, Open-Meteo's keyless geocoder (the same one
                            // the weather widgets resolve with) suggests real
                            // places; picking one stores the name and records
                            // the resolver cache so all three weather surfaces
                            // land on exactly that place (Paris FR vs Paris TX).
                            // typing freely still works; empty locates by IP.
                            Component {
                                id: locationC
                                Item {
                                    id: locRoot
                                    anchors.fill: parent
                                    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"

                                    Rectangle {
                                        id: locField
                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                        height: 30
                                        color: "transparent"
                                        radius: Tokens.radius
                                        border.width: lti.activeFocus ? 2 : Tokens.border
                                        border.color: lti.activeFocus ? Tokens.ink : Tokens.line
                                        TextInput {
                                            id: lti
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            verticalAlignment: Text.AlignVCenter
                                            clip: true
                                            autoScroll: activeFocus
                                            color: Tokens.ink
                                            font.family: Tokens.ui
                                            font.pixelSize: 12
                                            selectByMouse: true
                                            text: String(sheet.val(cell.r))
                                            onTextEdited: debounce.restart()
                                            onEditingFinished: sheet.edited(cell.r.key, text)
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            visible: lti.text === "" && !lti.activeFocus
                                            text: "Empty locates by IP"
                                            color: Tokens.inkFaint
                                            font.family: Tokens.ui
                                            font.pixelSize: 12
                                        }
                                    }

                                    Timer {
                                        id: debounce
                                        interval: 300
                                        onTriggered: {
                                            var q = lti.text.trim();
                                            if (q.length < 2) { locPop.close(); return; }
                                            geo.command = ["curl", "-s", "--max-time", "6",
                                                "https://geocoding-api.open-meteo.com/v1/search?count=6&language=en&format=json&name=" + encodeURIComponent(q)];
                                            geo.running = false;
                                            geo.running = true;
                                        }
                                    }

                                    Process {
                                        id: geo
                                        stdout: StdioCollector {
                                            onStreamFinished: {
                                                var out = [];
                                                try {
                                                    var j = JSON.parse(this.text);
                                                    if (j && Array.isArray(j.results)) {
                                                        for (var i = 0; i < j.results.length; i++) {
                                                            var r = j.results[i];
                                                            if (typeof r.latitude === "number" && typeof r.longitude === "number")
                                                                out.push({ name: r.name || "", admin1: r.admin1 || "", country: r.country || "", lat: r.latitude, lon: r.longitude });
                                                        }
                                                    }
                                                } catch (e) {}
                                                locList.model = out;
                                                if (out.length > 0 && lti.activeFocus) locPop.open(); else locPop.close();
                                            }
                                        }
                                    }

                                    FileView {
                                        id: locCache
                                        path: locRoot.stateDir + "/weather-loc.json"
                                        blockLoading: true
                                        printErrors: false
                                    }

                                    Popup {
                                        id: locPop
                                        parent: locField
                                        y: -locPop.height - 2
                                        width: locField.width
                                        padding: 1
                                        focus: false
                                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                        implicitHeight: Math.min(locList.count, 6) * 28 + 2
                                        background: Rectangle {
                                            color: Tokens.paperLift
                                            radius: Tokens.radius
                                            border.width: Tokens.border
                                            border.color: Tokens.lineStrong
                                        }
                                        contentItem: ListView {
                                            id: locList
                                            clip: true
                                            model: []
                                            delegate: Rectangle {
                                                id: lrow
                                                required property var modelData
                                                width: ListView.view.width
                                                height: 28
                                                color: lhov.hovered ? Tokens.tint10 : "transparent"
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.leftMargin: 8
                                                    anchors.rightMargin: 8
                                                    elide: Text.ElideRight
                                                    text: lrow.modelData.name + (lrow.modelData.admin1 ? "  ·  " + lrow.modelData.admin1 : "") + (lrow.modelData.country ? "  ·  " + lrow.modelData.country : "")
                                                    color: Tokens.ink
                                                    font.family: Tokens.ui
                                                    font.pixelSize: 12
                                                }
                                                HoverHandler { id: lhov; cursorShape: Qt.PointingHandCursor }
                                                TapHandler {
                                                    onTapped: {
                                                        lti.text = lrow.modelData.name;
                                                        sheet.edited(cell.r.key, lrow.modelData.name);
                                                        locCache.setText(JSON.stringify({ query: lrow.modelData.name, city: lrow.modelData.name, lat: lrow.modelData.lat, lon: lrow.modelData.lon }));
                                                        locPop.close();
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
            }
        }
    }

    signal pickRequested(var row)
    function openPick(r) { pickRequested(r) }

    signal imagePickRequested(var row)
    function imagePick(r) { imagePickRequested(r) }

    Column {
        anchors.centerIn: parent
        visible: sheet.rows.length === 0
        spacing: Tokens.s2
        Text {
            text: I18n.tr("NO MATCH")
            color: Tokens.inkDim
            font.family: Tokens.ui
            font.pixelSize: Tokens.fRow
            font.letterSpacing: 2
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: I18n.tr("nothing here matches “%1”").arg(sheet.query)
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
