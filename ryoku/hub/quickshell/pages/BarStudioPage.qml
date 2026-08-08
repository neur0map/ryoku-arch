pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "../barstudio"
import Ryoku.FrameBars
import "../barstudio/BarStudioModel.js" as Model

// Bar Studio (DESKTOP). Pick an edge, then edit that rail. It edits only the
// essentials that provably change the running desktop: the frame's draw toggle
// and opacity, each rail's on/off and thickness, and the widgets in its three
// zones (add via a per-zone drawer, remove, reorder). The retired chrome knobs
// (widget/window radius, border, the two-look style) and the rail auto-hide had
// no usable runtime effect, so they are gone; the bounded menus and the
// stash/system surfaces keep their persisted values (every edit clones the whole
// frameBars object, so no subtree it does not touch is ever dropped) but are not
// edited here.
//
// Everything stages through the shared draft (hub.stageLive), which applies to
// the RUNNING desktop as you work and rides the Hub's Save and Revert like every
// other framed page.
Item {
    id: page
    property var hub

    // which rail is on the bench
    property string edge: "left"

    // Always normalize what the editor reads. A stored value that lost a subtree
    // (a legacy config, a hand edit, a partial write) would otherwise leave the
    // editor reading undefined and a rail edit cloning the gap straight back to
    // disk. Normalizing restores every subtree from the schema default, so the
    // editor is always whole and the first staged edit heals the store. The
    // probe harness's bare hub has no val(); normalize(null) still yields a
    // complete default, so the page always loads.
    readonly property var config: {
        const v = page.hub && page.hub.val ? page.hub.val("frameBars") : null;
        return FrameBars.normalize(v, BarCatalog, MenuCatalog);
    }
    // the on-disk config, normalized to the same shape so the changed marks and
    // struck defaults compare like against like.
    readonly property var committedBars: {
        const c = page.hub && page.hub.committed ? page.hub.committed.frameBars : null;
        return c ? FrameBars.normalize(c, BarCatalog, MenuCatalog) : null;
    }

    // the selected rail and its on-disk twin, for the rail cells' changed marks
    readonly property var rail: page.config.rails[page.edge]
    readonly property var railWas: page.committedBars && page.committedBars.rails ? page.committedBars.rails[page.edge] : null
    readonly property bool horizontal: page.edge === "top" || page.edge === "bottom"

    property var barStyles: []

    function browseBarStyles() {
        Quickshell.execDetached(["ryostore", "open", "barstyles"]);
    }

    Process {
        id: styleProc
        command: ["ryostore", "catalog", "--category", "barstyles"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const catalog = JSON.parse(this.text || "{}");
                    page.barStyles = (catalog.items || [])
                        .filter(item => item.category === "barstyles" && item.installed === true)
                        .map(item => ({
                            id: item.id,
                            name: item.name || item.id,
                            desc: item.summary || item.description || "",
                            active: item.active === true
                        }));
                } catch (e) {
                    page.barStyles = [];
                }
            }
        }
    }

    // The Obi bar's widgets, for the per-widget show/hide toggles below. Mirrors
    // barstyles/obi/Scene.qml; Workspaces is the bar's identity and has no toggle.
    readonly property var obiWidgets: [
        { id: "activeWindow", label: qsTr("Active window"), desc: qsTr("The focused window's title, far left.") },
        { id: "resources", label: qsTr("Resources"), desc: qsTr("CPU and memory rings.") },
        { id: "media", label: qsTr("Media"), desc: qsTr("Now playing with a music visualizer.") },
        { id: "audio", label: qsTr("Audio"), desc: qsTr("Output and input volume, with a mixer.") },
        { id: "clock", label: qsTr("Clock"), desc: qsTr("Time and date.") },
        { id: "connectivity", label: qsTr("Connections"), desc: qsTr("Wi-Fi and Bluetooth.") },
        { id: "battery", label: qsTr("Battery"), desc: qsTr("Charge and power profile.") },
        { id: "tray", label: qsTr("Tray"), desc: qsTr("System tray icons.") },
        { id: "weather", label: qsTr("Weather"), desc: qsTr("Current conditions.") }
    ]
    // The running bar style, default the built-in frame style. The frame, rails
    // and zone editors below are Sumi's; a folder style owns its own layout.
    readonly property string activeStyle: page.fval("barStyle", "sumi")
    readonly property bool sumiActive: page.activeStyle === "sumi"
    readonly property string activeName: {
        for (let i = 0; i < page.barStyles.length; i++)
            if (page.barStyles[i].id === page.activeStyle) return page.barStyles[i].name;
        return page.activeStyle;
    }

    // Stage AND apply: edits ride the shared draft like every page, and the
    // hub's stageLive coalesces a settings.patch to the daemon so the running
    // desktop repaints as you work. The probe harness's bare hub has neither;
    // fall back so the page still loads and stages inertly.
    function stage(next) {
        if (!next || !page.hub) return;
        if (page.hub.stageLive) page.hub.stageLive("frameBars", next);
        else if (page.hub.edit) page.hub.edit("frameBars", next);
    }

    // The frame chrome keys live beside frameBars in shell.json: the running
    // shell reads frameEnabled for the draw toggle and frameOpacity for how solid
    // the frame paints, so they belong on the frame's own studio and stage
    // through the same live channel.
    function fval(key, fall) {
        if (!page.hub || !page.hub.val) return fall;
        const v = page.hub.val(key);
        return v === undefined || v === null ? fall : v;
    }
    function fnum(key, fall) {
        const v = Number(page.fval(key, fall));
        return isFinite(v) ? v : fall;
    }
    function fedit(key, value) {
        if (!page.hub) return;
        if (page.hub.stageLive) page.hub.stageLive(key, value);
        else if (page.hub.edit) page.hub.edit(key, value);
    }
    function fwas(key) {
        return page.hub && page.hub.committed ? page.hub.committed[key] : undefined;
    }

    // Obi's per-widget visibility lives in the `obi` map in shell.json (an absent
    // key reads as shown). Toggling stages the whole map live like every edit.
    function obiShown(id) {
        const o = page.fval("obi", ({}));
        return !o || o[id] !== false;
    }
    function obiSet(id, on) {
        const o = Object.assign({}, page.fval("obi", ({})));
        o[id] = on;
        page.fedit("obi", o);
    }

    // ── QS Bar (Hancore top bar) settings ────────────────────────────────────
    // Stored in the `qsbar` map in shell.json and applied live by the bar's
    // Theme; an absent key keeps the bar's own default. The V1/V2 variant is
    // owned by the bar's StateService, so it rides the bar's IPC and is mirrored
    // back from the persisted state file.
    function qval(key, fall) {
        const q = page.fval("qsbar", ({}));
        return q && q[key] !== undefined ? q[key] : fall;
    }
    function qset(key, v) {
        const q = Object.assign({}, page.fval("qsbar", ({})));
        q[key] = v;
        page.fedit("qsbar", q);
    }
    function qwid(id, fall) {
        const q = page.fval("qsbar", ({}));
        const w = q && q.widgets ? q.widgets : ({});
        return w[id] !== undefined ? w[id] : fall;
    }
    function qwidset(id, v) {
        const q = Object.assign({}, page.fval("qsbar", ({})));
        const w = Object.assign({}, q.widgets || ({}));
        w[id] = v;
        q.widgets = w;
        page.fedit("qsbar", q);
    }

    // The gap animation is stored as an int mode in the qsbar map. Bar Studio
    // exposes a labelled subset (the V1 stream's usable presets); each label maps
    // to the mode int the running bar reads. Off is the sentinel 0.
    readonly property var qsbarAnimModes: [
        { v: 0, label: qsTr("Off") },
        { v: 1, label: qsTr("Stream") },
        { v: 2, label: qsTr("Surge") },
        { v: 3, label: qsTr("Bolt") },
        { v: 7, label: qsTr("Reactor") },
        { v: 8, label: qsTr("Quotes") }
    ]
    function qsbarAnimLabel(v) {
        for (let i = 0; i < page.qsbarAnimModes.length; i++)
            if (page.qsbarAnimModes[i].v === v) return page.qsbarAnimModes[i].label;
        return page.qsbarAnimModes[0].label;
    }
    function qsbarAnimValue(label) {
        for (let i = 0; i < page.qsbarAnimModes.length; i++)
            if (page.qsbarAnimModes[i].label === label) return page.qsbarAnimModes[i].v;
        return 0;
    }

    property string qsbarVariant: "v1"
    function qsbarSetVariant(v) {
        Quickshell.execDetached(["qs", "-c", "shell", "ipc", "call", "variant", "activate", v]);
    }
    FileView {
        id: qsbarVariantFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/quickshell-rise/active-variant"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: page.qsbarVariant = (qsbarVariantFile.text() || "v1").trim() || "v1"
    }

    readonly property var qsbarWidgets: [
        { id: "status", label: qsTr("Status"), def: true, desc: qsTr("Arch updates, tray and notifications.") },
        { id: "cpu", label: qsTr("CPU"), def: true, desc: qsTr("CPU load and history.") },
        { id: "memory", label: qsTr("Memory"), def: true, desc: qsTr("Memory use.") },
        { id: "volume", label: qsTr("Volume"), def: true, desc: qsTr("Output volume and mixer.") },
        { id: "network", label: qsTr("Network"), def: true, desc: qsTr("Wi-Fi and Ethernet.") },
        { id: "brightness", label: qsTr("Brightness"), def: true, desc: qsTr("Backlight level.") },
        { id: "weather", label: qsTr("Weather"), def: true, desc: qsTr("Current conditions.") },
        { id: "media", label: qsTr("Media"), def: true, desc: qsTr("Now-playing controls.") },
        { id: "mpris", label: qsTr("Now playing"), def: true, desc: qsTr("The now-playing pill.") },
        { id: "quick", label: qsTr("Quick toggles"), def: true, desc: qsTr("Idle inhibitor, media and theme.") },
        { id: "claude", label: qsTr("AI usage"), def: false, desc: qsTr("Coding-agent usage meter.") },
        { id: "power", label: qsTr("Power profile"), def: false, desc: qsTr("Power-profile pill.") },
        { id: "bluetooth", label: qsTr("Bluetooth"), def: false, desc: qsTr("Bluetooth pill.") },
        { id: "gpu", label: qsTr("GPU"), def: true, desc: qsTr("GPU load."), v2: true },
        { id: "cpuTemperature", label: qsTr("CPU temperature"), def: true, desc: qsTr("CPU temperature."), v2: true },
        { id: "storage", label: qsTr("Storage"), def: true, desc: qsTr("Root filesystem usage."), v2: true }
    ]
    readonly property var qsbarColors: ["color01", "color02", "color03", "color04", "color05", "color06", "color07", "foreground"]
    property var qsbarPalette: ({})
    FileView {
        id: qsbarColorsFile
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try { page.qsbarPalette = JSON.parse(qsbarColorsFile.text() || "{}"); }
            catch (e) { page.qsbarPalette = ({}); }
        }
    }
    function qsbarSwatch(id) {
        const p = page.qsbarPalette;
        if (!p) return Tokens.inkDim;
        if (id === "foreground") return p.foreground || Tokens.ink;
        return p["color" + parseInt(id.slice(-2), 10)] || Tokens.inkDim;
    }

    CatalogLabels { id: labels }

    // ── head: the eyebrow band, the title, the blurb ─────────────────────────
    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: Tokens.s2

        Item {
            width: parent.width
            height: 14
            Row {
                id: ebrow
                spacing: Tokens.s2
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { width: 16; height: 1; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "力"; color: Tokens.ink; font.family: Tokens.jp
                    font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: qsTr("DESKTOP"); color: Tokens.inkMuted; font.family: Tokens.ui
                    font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Rectangle {
                anchors { left: ebrow.right; right: crossMark.left; verticalCenter: parent.verticalCenter }
                anchors.leftMargin: Tokens.s3; anchors.rightMargin: Tokens.s3
                height: 1; color: Tokens.lineSoft
            }
            Text {
                id: crossMark
                anchors { right: slashMark.left; rightMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                text: "+"; color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: 10
            }
            Text {
                id: slashMark
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "///"; color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: 10
            }
        }
        Text {
            text: qsTr("Bar Studio")
            color: Tokens.ink
            font.family: Tokens.display
            font.pixelSize: Tokens.fTitle
        }
        Text {
            width: Math.min(parent.width, 720)
            text: qsTr("The frame's chrome, its left rail, and the widgets on it. Every change lands live on the desktop, and Save keeps it.")
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
            wrapMode: Text.WordWrap
        }
    }

    // ── the sheet: FRAME, RAILS, WIDGETS in one scroll ───────────────────────
    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.s5 }
        contentWidth: width
        contentHeight: col.height + Tokens.s5
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: flick.width - 14
            spacing: Tokens.s5

            // ── BAR STYLE: which bar the desktop draws ───────────────────────
            SettingCard {
                id: styleSect
                width: col.width
                title: qsTr("BAR STYLE")

                Item {
                    width: parent.width
                    height: styleBody.height + Tokens.s3 + Tokens.s4
                    Column {
                        id: styleBody
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        anchors.leftMargin: Tokens.s4; anchors.rightMargin: Tokens.s4; anchors.topMargin: Tokens.s3
                        spacing: Tokens.s3
                        Row {
                            id: styleRow
                            width: parent.width
                            spacing: Tokens.s2
                            Repeater {
                                model: page.barStyles
                                delegate: Rectangle {
                                    id: styleCard
                                    required property var modelData
                                    readonly property bool on: page.activeStyle === styleCard.modelData.id

                                    objectName: "bar-style-" + styleCard.modelData.id
                                    width: (styleRow.width - (page.barStyles.length - 1) * Tokens.s2) / page.barStyles.length
                                    height: 64
                                    radius: Tokens.radius
                                    color: styleCard.on ? Tokens.bone : (sma.containsMouse ? Tokens.tint5 : "transparent")
                                    border.width: Tokens.border
                                    border.color: styleCard.on ? Tokens.bone : Tokens.line
                                    Behavior on color { ColorAnimation { duration: Tokens.snap } }

                                    Column {
                                        anchors { left: parent.left; right: parent.right; margins: Tokens.s3; verticalCenter: parent.verticalCenter }
                                        spacing: 3
                                        Text {
                                            text: styleCard.modelData.name.toUpperCase()
                                            color: styleCard.on ? Tokens.inkOnBone : Tokens.inkDim
                                            font.family: Tokens.ui
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            font.letterSpacing: Tokens.trackLabel
                                        }
                                        Text {
                                            width: parent.width
                                            text: styleCard.modelData.desc
                                            color: styleCard.on ? Tokens.inkOnBoneDim : Tokens.inkFaint
                                            font.family: Tokens.ui
                                            font.pixelSize: Tokens.fTiny
                                            elide: Text.ElideRight
                                        }
                                    }
                                    MouseArea {
                                        id: sma
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        preventStealing: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: page.fedit("barStyle", styleCard.modelData.id)
                                    }
                                }
                            }
                        }
                        Btn {
                            text: qsTr("BROWSE RYOSTORE")
                            onAct: page.browseBarStyles()
                        }
                    }
                }
            }

            // A folder style owns its own frame, rails and widgets inside its
            // barstyles/<id>/ folder, so the Sumi editors below stand down.
            SettingCard {
                id: folderNote
                width: col.width
                visible: !page.sumiActive
                title: qsTr("LAYOUT")

                Text {
                    width: parent.width
                    leftPadding: Tokens.s4; rightPadding: Tokens.s4
                    topPadding: Tokens.s3; bottomPadding: Tokens.s4
                    text: qsTr("The %1 style manages its own layout in barstyles/%2. Its controls are below.").arg(page.activeName).arg(page.activeStyle)
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fBody
                    wrapMode: Text.WordWrap
                }
            }

            // OBI WIDGETS: show or hide each widget on the Obi bar.
            SettingCard {
                id: obiSect
                width: col.width
                visible: page.activeStyle === "obi"
                title: qsTr("OBI WIDGETS")

                Repeater {
                    model: page.obiWidgets
                    delegate: SettingRow {
                        required property var modelData
                        required property int index
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: index > 0
                        controlWidth: 54
                        label: modelData.label
                        desc: modelData.desc
                        source: "shell.json"
                        Sw {
                            objectName: "obi-" + modelData.id
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: page.obiShown(modelData.id)
                            onToggled: value => page.obiSet(modelData.id, value)
                        }
                    }
                }
            }

            SettingCard {
                id: nacreSect
                width: col.width
                visible: page.activeStyle === "nacre"
                title: qsTr("NACRE LAYOUT")

                Item {
                    width: parent.width
                    height: nacreEd.height + Tokens.s3 + Tokens.s4
                    NacreEditor {
                        id: nacreEd
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        anchors.leftMargin: Tokens.s4; anchors.rightMargin: Tokens.s4; anchors.topMargin: Tokens.s3
                        config: page.fval("nacre", ({}))
                        onStaged: value => page.fedit("nacre", value)
                    }
                }
            }

            // ── QS BAR: the Hancore top bar's controls ───────────────────────
            SettingCard {
                id: qsbarSect
                width: col.width
                visible: page.activeStyle === "qsbar"
                title: qsTr("QS BAR")

                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    controlWidth: 120
                    label: qsTr("Layout")
                    desc: qsTr("V1 split islands with the animated stream, or the V2 unified top shell.")
                    source: qsTr("state")
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: ["v1", "v2"]
                        current: page.qsbarVariant
                        onChose: key => page.qsbarSetVariant(key)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 220
                    visible: page.qsbarVariant === "v2"
                    label: qsTr("Bar form")
                    desc: qsTr("The full-width shell, a fitted island, a floating dock, or a notch.")
                    source: "shell.json"
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: ["full", "fit", "dock", "notch"]
                        current: page.qval("barShellStyle", "full")
                        onChose: key => page.qset("barShellStyle", key)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 54
                    visible: page.qsbarVariant === "v2"
                    label: qsTr("Bar border")
                    desc: qsTr("Draw the outer border around the bar shell.")
                    source: "shell.json"
                    Sw {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: page.qval("barBorderEnabled", true)
                        onToggled: value => page.qset("barBorderEnabled", value)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 54
                    visible: page.qsbarVariant === "v2"
                    label: qsTr("Panel + tooltip border")
                    desc: qsTr("Draw the outer border around popouts and tooltips.")
                    source: "shell.json"
                    Sw {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: page.qval("panelTooltipBorderEnabled", true)
                        onToggled: value => page.qset("panelTooltipBorderEnabled", value)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    block: true
                    label: qsTr("Gap animation")
                    desc: qsTr("The stream that flows between the islands, reactive to playback.")
                    source: "shell.json"
                    Seg {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        options: page.qsbarAnimModes.map(m => m.label)
                        current: page.qsbarAnimLabel(page.qval("barAnim", 1))
                        onChose: key => page.qset("barAnim", page.qsbarAnimValue(key))
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 130
                    label: qsTr("Position")
                    desc: qsTr("Which screen edge the bar sits on.")
                    source: "shell.json"
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: ["top", "bottom"]
                        current: page.qval("barPosition", "top")
                        onChose: key => page.qset("barPosition", key)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 170
                    label: qsTr("Workspaces")
                    desc: qsTr("Only the active workspace, or a fixed 1-5 / 1-10 row.")
                    source: "shell.json"
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: ["active", "5", "10"]
                        current: page.qval("workspaceMode", "active")
                        onChose: key => page.qset("workspaceMode", key)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 190
                    label: qsTr("Workspace marker")
                    desc: qsTr("How the workspace indicators are drawn.")
                    source: "shell.json"
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: page.qsbarVariant === "v2" ? ["default", "numbers", "magic", "kanji", "rings", "aurora"] : ["default", "numbers", "magic"]
                        current: page.qval("workspaceStyle", "default")
                        onChose: key => page.qset("workspaceStyle", key)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 190
                    label: qsTr("Accent colour")
                    desc: qsTr("Which wallpaper colour tints the bar and its stream.")
                    source: "shell.json"
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.s1
                        Repeater {
                            model: page.qsbarColors
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool on: page.qval("barColor", "color01") === modelData
                                width: 20
                                height: 20
                                radius: Tokens.radius
                                color: page.qsbarSwatch(modelData)
                                border.width: on ? 2 : Tokens.border
                                border.color: on ? Tokens.bone : Tokens.line
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: page.qset("barColor", modelData) }
                            }
                        }
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 210
                    label: qsTr("AI tool")
                    desc: qsTr("Which coding-agent usage meter the AI pill shows.")
                    source: "shell.json"
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: ["claude", "codex", "opencode"]
                        current: page.qval("aiTool", "claude")
                        onChose: key => page.qset("aiTool", key)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    block: true
                    visible: page.qsbarVariant === "v2"
                    label: qsTr("Temperature source")
                    desc: qsTr("Which sensor the CPU-temperature widget reads.")
                    source: "shell.json"
                    Seg {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        options: ["cpu", "core", "gpu", "nvme", "memory"]
                        current: page.qval("barTemperatureSource", "cpu")
                        onChose: key => page.qset("barTemperatureSource", key)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    block: true
                    label: qsTr("Picker style")
                    desc: qsTr("How the theme, wallpaper and media pickers are laid out.")
                    source: "shell.json"
                    Seg {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        options: ["tanzaku", "hearthstone", "carousel"]
                        current: page.qval("pickerStyle", "tanzaku")
                        onChose: key => page.qset("pickerStyle", key)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 130
                    label: qsTr("Logo")
                    desc: qsTr("The launcher mark: the RYOKU wordmark or the 力 kanji.")
                    source: "shell.json"
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: ["text", "icon"]
                        current: page.qval("launcherLogoMode", "text")
                        onChose: key => page.qset("launcherLogoMode", key)
                    }
                }
                Repeater {
                    model: page.qsbarWidgets
                    delegate: SettingRow {
                        required property var modelData
                        visible: !modelData.v2 || page.qsbarVariant === "v2"
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        controlWidth: 54
                        label: modelData.label
                        desc: modelData.desc
                        source: "shell.json"
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: page.qwid(modelData.id, modelData.def)
                            onToggled: value => page.qwidset(modelData.id, value)
                        }
                    }
                }
            }

            // ── FRAME: the chrome the shell draws around the desktop ─────────
            SettingCard {
                id: frameSect
                width: col.width
                title: qsTr("FRAME")
                visible: page.sumiActive

                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    controlWidth: 54
                    label: qsTr("Draw frame")
                    def: page.fwas("frameEnabled") === undefined ? "" : (page.fwas("frameEnabled") ? qsTr("ON") : qsTr("OFF"))
                    changed: page.fwas("frameEnabled") !== undefined && !!page.fval("frameEnabled", true) !== !!page.fwas("frameEnabled")
                    desc: qsTr("Draw the bounded frame around the desktop at all.")
                    source: "shell.json"
                    Sw {
                        objectName: "frame-enabled"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: !!page.fval("frameEnabled", true)
                        onToggled: value => page.fedit("frameEnabled", value)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: Math.min(240, Math.max(160, Math.round(frameSect.width * 0.34)))
                    label: qsTr("Opacity")
                    unit: "%"
                    value: String(Math.round(page.fnum("frameOpacity", 1) * 100))
                    def: page.fwas("frameOpacity") === undefined ? "" : String(Math.round(Number(page.fwas("frameOpacity")) * 100))
                    changed: page.fwas("frameOpacity") !== undefined && page.fnum("frameOpacity", 1) !== Number(page.fwas("frameOpacity"))
                    desc: qsTr("How solid the frame draws.")
                    source: "shell.json"
                    Slid {
                        objectName: "frame-opacity"
                        anchors.fill: parent
                        from: 0.5; to: 1.0
                        value: page.fnum("frameOpacity", 1)
                        onModified: value => page.fedit("frameOpacity", value)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 58
                    label: qsTr("Frame thickness")
                    unit: "px"
                    value: String(page.fnum("frameThickness", 2))
                    def: page.fwas("frameThickness") === undefined ? "" : String(page.fwas("frameThickness"))
                    changed: page.fwas("frameThickness") !== undefined && page.fnum("frameThickness", 2) !== Number(page.fwas("frameThickness"))
                    desc: qsTr("How thick the frame band around the desktop is drawn.")
                    source: "shell.json"
                    Step {
                        objectName: "frame-thickness"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 24
                        value: page.fnum("frameThickness", 2)
                        onModified: value => page.fedit("frameThickness", value)
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 58
                    label: qsTr("Corner radius")
                    unit: "px"
                    value: String(page.fnum("frameCorner", 8))
                    def: page.fwas("frameCorner") === undefined ? "" : String(page.fwas("frameCorner"))
                    changed: page.fwas("frameCorner") !== undefined && page.fnum("frameCorner", 8) !== Number(page.fwas("frameCorner"))
                    desc: qsTr("How round the frame cuts the screen's corners.")
                    source: "shell.json"
                    Step {
                        objectName: "frame-corner"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 40
                        value: page.fnum("frameCorner", 8)
                        onModified: value => page.fedit("frameCorner", value)
                    }
                }
            }

            // ── RAILS: pick an edge, then its own switches ───────────────────
            SettingCard {
                id: railSect
                width: col.width
                title: qsTr("RAILS")
                visible: page.sumiActive

                Item {
                    width: parent.width
                    height: railRow.height + Tokens.s3 + Tokens.s3
                    Row {
                        id: railRow
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        anchors.leftMargin: Tokens.s4; anchors.rightMargin: Tokens.s4; anchors.topMargin: Tokens.s3
                        spacing: Tokens.s2
                        Repeater {
                            model: ["left"]
                            delegate: Rectangle {
                                id: plate
                                required property string modelData
                                readonly property var pRail: page.config.rails[plate.modelData]
                                readonly property int count: {
                                    const zs = plate.modelData === "top" || plate.modelData === "bottom" ? ["start", "center", "end"] : ["top", "center", "bottom"];
                                    let n = 0;
                                    for (const zone of zs) n += (plate.pRail[zone] || []).length;
                                    return n;
                                }
                                readonly property bool on: page.edge === plate.modelData

                                objectName: "rail-edge-" + plate.modelData
                                width: (railRow.width - 3 * Tokens.s2) / 4
                                height: 48
                                radius: Tokens.radius
                                color: plate.on ? Tokens.bone : (pma.containsMouse ? Tokens.tint5 : "transparent")
                                border.width: Tokens.border
                                border.color: plate.on ? Tokens.bone : Tokens.line
                                Behavior on color { ColorAnimation { duration: Tokens.snap } }

                                Column {
                                    anchors { left: parent.left; leftMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                                    spacing: 2
                                    Text {
                                        text: labels.edge(plate.modelData).toUpperCase()
                                        color: plate.on ? Tokens.inkOnBone : Tokens.inkDim
                                        font.family: Tokens.ui
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        font.letterSpacing: Tokens.trackLabel
                                    }
                                    Text {
                                        text: plate.pRail.enabled ? qsTr("on · %1").arg(plate.count) : qsTr("off")
                                        color: plate.on ? Tokens.inkOnBoneDim : Tokens.inkFaint
                                        font.family: Tokens.mono
                                        font.pixelSize: Tokens.fTiny
                                    }
                                }
                                MouseArea {
                                    id: pma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.edge = plate.modelData
                                }
                            }
                        }
                    }
                }

                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: 54
                    label: qsTr("Show this rail")
                    def: page.railWas ? (page.railWas.enabled ? qsTr("ON") : qsTr("OFF")) : ""
                    changed: !!page.railWas && page.rail.enabled !== page.railWas.enabled
                    desc: qsTr("Draw the %1 rail on the frame.").arg(labels.edge(page.edge).toLowerCase())
                    source: "shell.json"
                    Sw {
                        objectName: "rail-enabled"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: page.rail.enabled
                        onToggled: value => page.stage(Model.setRail(page.config, page.edge, { enabled: value }))
                    }
                }
                SettingRow {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    divider: true
                    controlWidth: Math.min(240, Math.max(160, Math.round(railSect.width * 0.34)))
                    label: qsTr("Thickness")
                    unit: "px"
                    value: String(page.rail.size)
                    def: page.railWas ? String(page.railWas.size) : ""
                    changed: !!page.railWas && page.rail.size !== page.railWas.size
                    desc: qsTr("How far the %1 rail stands into the screen.").arg(labels.edge(page.edge).toLowerCase())
                    source: "shell.json"
                    Slid {
                        objectName: "rail-thickness"
                        anchors.fill: parent
                        from: page.horizontal ? 16 : 24
                        to: page.horizontal ? 96 : 112
                        value: page.rail.size
                        onModified: value => page.stage(Model.setRail(page.config, page.edge, { size: value }))
                    }
                }
            }

            // ── WIDGETS: the selected rail's three zones and its add drawers ──
            SettingCard {
                id: zoneSect
                width: col.width
                title: qsTr("WIDGETS ON THE %1 RAIL").arg(labels.edge(page.edge).toUpperCase())
                visible: page.sumiActive

                Item {
                    width: parent.width
                    height: zoneEd.height + Tokens.s3 + Tokens.s4
                    ZoneEditor {
                        id: zoneEd
                        anchors { left: parent.left; right: parent.right; top: parent.top }
                        anchors.leftMargin: Tokens.s4; anchors.rightMargin: Tokens.s4; anchors.topMargin: Tokens.s3
                        config: page.config
                        edge: page.edge
                        catalog: BarCatalog
                        onStaged: next => page.stage(next)
                    }
                }
            }
        }
    }
}
