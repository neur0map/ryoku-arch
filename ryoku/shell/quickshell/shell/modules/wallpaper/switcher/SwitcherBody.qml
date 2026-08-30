pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"
import Ryoku.Ui.Singletons
import Quickshell.Hyprland
import shell.services

// Wallpaper switcher - a shelf of tall wallpaper columns filling the screen and a
// single compact instrument pill floating at top-centre (力 · mode · layout · the
// colour rail · sort · search · counter). No card, no bottom chrome. It runs the
// live-canvas model: browsing applies the focused wallpaper to the real desktop
// (on a short settle), so the screen itself is the preview; Enter or a click
// keeps the pick, Esc reverts to whatever was on screen when it opened. Themes
// preview the same way. The backend (Walls / Themes / ryoku-shell) is untouched.
Item {
    id: body

    required property real s
    required property bool active
    signal requestClose()

    // the output this pick targets: "*" = all screens, else a connector name.
    // opened from the bar it carries a screen; from Super+W it is the monitor
    // the switcher is shown on. Connected monitors feed the target selector.
    property string screenName: ""
    property string target: "*"
    readonly property var monitors: Hyprland.monitors.values
    readonly property string targetLabel: body.target === "*" ? "All" : (body.target.length > 0 ? body.target : "All")
    function cycleTarget() {
        var opts = ["*"];
        for (var i = 0; i < body.monitors.length; i++)
            if (body.monitors[i] && body.monitors[i].name)
                opts.push(body.monitors[i].name);
        var idx = opts.indexOf(body.target);
        body.target = opts[(idx + 1 + opts.length) % opts.length];
        body.schedulePreview();
    }

    // ── mode / filter / search (transient per open); layout + sort live in View ──
    property string mode: "walls"            // walls | themes
    property string typeFilter: "all"        // all | image | live
    property int colorFilter: -1             // -1 = every colour, else a group id
    property string search: ""
    property int selIndex: 0

    readonly property bool themesMode: body.mode === "themes"
    property string drawer: ""               // "" | "layout" | "filter" popover
    readonly property bool following: Themes.following

    function norm(t) { return String(t || "").toLowerCase(); }

    // walls: type + colour + search filter, then the chosen sort.
    readonly property var wallBase: {
        var out = [];
        var q = body.norm(body.search);
        var es = Walls.entries;
        for (var i = 0; i < es.length; i++) {
            var e = es[i];
            if (body.typeFilter !== "all" && e.type !== body.typeFilter) continue;
            if (body.colorFilter !== -1 && e.group !== body.colorFilter) continue;
            if (q.length > 0 && body.norm(e.name).indexOf(q) < 0) continue;
            out.push(e);
        }
        return out;
    }
    function sorted(a) {
        var v = View.sort;
        if (v === "recent") return a.slice().sort((x, y) => y.mtime - x.mtime);
        if (v === "name") return a.slice().sort((x, y) => body.norm(x.name).localeCompare(body.norm(y.name)));
        return a;   // colour: the scan's own hue order
    }
    readonly property var wallShown: body.sorted(body.wallBase)

    // themes: label search only.
    readonly property var themeShown: {
        var q = body.norm(body.search);
        if (q.length === 0) return Themes.themes;
        return Themes.themes.filter(t => body.norm(t.label).indexOf(q) >= 0);
    }

    readonly property var shown: body.themesMode ? body.themeShown : body.wallShown
    readonly property var selEntry: (body.selIndex >= 0 && body.selIndex < body.shown.length)
        ? body.shown[body.selIndex] : null
    readonly property string activeKey: (body.themesMode ? Themes.active : Walls.currentFor(body.target)) || ""

    // colour groups present under the current type filter.
    readonly property var wallGroups: {
        var seen = ({});
        var es = Walls.entries;
        for (var i = 0; i < es.length; i++) {
            var e = es[i];
            if (body.typeFilter !== "all" && e.type !== body.typeFilter) continue;
            seen[e.group] = true;
        }
        var out = [];
        for (var g = 0; g < Colors.order.length; g++)
            if (seen[Colors.order[g]]) out.push(Colors.order[g]);
        return out;
    }

    // ── live preview: snapshot on open, apply on settle, revert on cancel ──
    property string originalWall: ""
    property string originalTheme: ""
    property bool touchedWall: false
    property bool touchedTheme: false
    property bool started: false

    Component.onCompleted: {
        // Single-output rigs have nothing to disambiguate: route them through
        // the flagless "*" apply (matches the Super+W path) rather than
        // --screen <name>, so they don't silently lose the recolor step that
        // only runs on the default target.
        body.target = ShellState.wallpaperSwitcherTarget.length > 0 ? ShellState.wallpaperSwitcherTarget
            : (body.monitors.length > 1 && body.screenName.length > 0 ? body.screenName : "*");
        ShellState.wallpaperSwitcherTarget = "";
        body.originalWall = Walls.currentFor(body.target);
        body.originalTheme = Themes.active;
        body.forceActiveFocus();
    }

    Timer {
        id: previewTimer
        interval: 190
        onTriggered: body.applyPreview(false)
    }
    function schedulePreview() { if (View.livePreview) previewTimer.restart(); }
    function applyPreview(isCommit) {
        var e = body.selEntry;
        if (!e) return;
        if (body.themesMode) {
            Themes.apply(e.id);
            body.touchedTheme = true;
        } else {
            // live wallpapers preview through the tile's own loop; applying one
            // to the desktop spawns a player, so only do that on the keep.
            if (!isCommit && e.type === "live") return;
            Walls.apply(e.path, body.target);
            body.touchedWall = true;
        }
    }
    function commit() {                       // Enter / click a column: keep the pick
        previewTimer.stop();
        body.applyPreview(true);
        body.requestClose();
    }
    function cancel() {                       // Esc: put back what was on screen
        previewTimer.stop();
        if (body.touchedWall && body.originalWall.length > 0)
            Walls.apply(body.originalWall, body.target);
        if (body.touchedTheme)
            Themes.apply(body.originalTheme.length > 0 ? body.originalTheme : "Wallpaper");
        body.requestClose();
    }
    function choose(i) { body.selIndex = i; body.commit(); }

    function positionToActive() {
        var arr = body.shown, idx = 0;
        for (var i = 0; i < arr.length; i++) {
            var hit = body.themesMode
                ? (arr[i].id === (Themes.active.length > 0 ? Themes.active : body.originalTheme))
                : (arr[i].path === Walls.current);
            if (hit) { idx = i; break; }
        }
        body.selIndex = idx;
    }

    function setMode(m) {
        if (body.mode === m) return;
        body.mode = m; body.search = "";
        body.positionToActive();
    }
    function setType(t) {
        if (body.typeFilter === t) return;
        body.typeFilter = t; body.colorFilter = -1; body.selIndex = 0;
    }
    function setColor(g) {
        body.colorFilter = (body.colorFilter === g) ? -1 : g; body.selIndex = 0;
    }
    function moveSel(d) {
        if (body.shown.length === 0) return;
        var ni = Math.max(0, Math.min(body.shown.length - 1, body.selIndex + d));
        if (ni === body.selIndex) return;
        body.selIndex = ni;
        body.schedulePreview();
    }
    function focusAt(i) {
        if (i === body.selIndex) return;
        body.selIndex = i;
        body.schedulePreview();
    }
    function toggleFollow() {
        if (body.following) {
            if (body.selEntry) { Themes.apply(body.selEntry.id); body.touchedTheme = true; }
        } else {
            Themes.apply("Wallpaper"); body.touchedTheme = true;
        }
    }

    readonly property int hostCols: (host.item && host.item.columns) ? host.item.columns : 1
    function pad2(n) { return (n < 10 ? "0" : "") + n; }

    onShownChanged: {
        if (!body.started && body.shown.length > 0) {
            body.started = true;
            body.positionToActive();
        }
        if (body.selIndex >= body.shown.length)
            body.selIndex = Math.max(0, body.shown.length - 1);
    }

    focus: true
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape) {
            if (body.search.length > 0) body.search = "";
            else body.cancel();
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            body.commit();
        } else if (e.key === Qt.Key_Tab) {
            body.setMode(body.themesMode ? "walls" : "themes");
        } else if (e.key === Qt.Key_Left) {
            body.moveSel(-1);
        } else if (e.key === Qt.Key_Right) {
            body.moveSel(1);
        } else if (e.key === Qt.Key_Up) {
            body.moveSel(-body.hostCols);
        } else if (e.key === Qt.Key_Down) {
            body.moveSel(body.hostCols);
        } else if (e.key === Qt.Key_Backspace) {
            if (body.search.length > 0) body.search = body.search.slice(0, -1);
        } else if (e.text && e.text.length === 1 && e.text.charCodeAt(0) >= 32 && e.text.charCodeAt(0) !== 127
                   && (e.modifiers === Qt.NoModifier || e.modifiers === Qt.ShiftModifier)) {
            if (e.text !== " " || (body.search.length > 0 && !body.search.endsWith(" ")))
                body.search += e.text;
        } else {
            return;
        }
        e.accepted = true;
    }

    // ── a mode segment: bone plate + dark ink when on (inversion, the one accent) ──
    component Seg: Item {
        id: seg
        property string label: ""
        property bool on: false
        signal clicked()
        implicitWidth: segTxt.implicitWidth + Math.round(20 * body.s)
        implicitHeight: Math.round(26 * body.s)
        Rectangle {
            anchors.fill: parent
            radius: Math.round(3 * body.s)
            color: seg.on ? Theme.bone : (segHov.hovered ? Theme.fillHover : "transparent")
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Text {
                id: segTxt
                anchors.centerIn: parent
                text: I18n.tr(seg.label)
                color: seg.on ? Theme.inkOnBone : (segHov.hovered ? Theme.onSurface : Theme.inkDim)
                font.family: Theme.ui
                font.pixelSize: Math.round(12 * body.s)
                font.weight: seg.on ? Font.DemiBold : Font.Medium
            }
        }
        HoverHandler { id: segHov; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.clicked() }
    }

    // ── a borderless glyph button for the pill (layout / sort / search / type) ──
    component IconBtn: Item {
        id: ib
        property string glyph: ""
        property string label: ""
        property bool on: false
        signal clicked()
        implicitWidth: ibRow.implicitWidth + Math.round(14 * body.s)
        implicitHeight: Math.round(26 * body.s)
        Rectangle {
            anchors.fill: parent
            radius: Math.round(3 * body.s)
            color: ib.on ? Theme.fillActive : (ibHov.hovered ? Theme.fillHover : "transparent")
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Row {
                id: ibRow
                anchors.centerIn: parent
                spacing: Math.round(5 * body.s)
                Text {
                    visible: ib.glyph.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: ib.glyph
                    color: ib.on ? Theme.seal : (ibHov.hovered ? Theme.onSurface : Theme.inkDim)
                    font.family: Theme.mono
                    font.pixelSize: Math.round(13 * body.s)
                }
                Text {
                    visible: ib.label.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr(ib.label)
                    color: ib.on ? Theme.onSurface : (ibHov.hovered ? Theme.onSurface : Theme.inkDim)
                    font.family: Theme.ui
                    font.pixelSize: Math.round(11.5 * body.s)
                }
            }
        }
        HoverHandler { id: ibHov; cursorShape: Qt.PointingHandCursor }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ib.clicked() }
    }

    component Sep: Rectangle {
        width: 1
        height: Math.round(18 * body.s)
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: Theme.sep
    }

    // ── the stage: a compact bottom-centre card above the bar. The live desktop
    // behind it is the real preview (browsing applies to the target screen). ──
    Rectangle {
        id: stage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: bar.top
        anchors.bottomMargin: Math.round(12 * body.s)
        width: Math.round(Math.min(parent.width - 48 * body.s, 1100 * body.s))
        height: Math.round(Math.min(parent.height * 0.40, 460 * body.s))
        visible: body.shown.length > 0
        color: "transparent"
        clip: true

        Loader {
            id: host
            anchors.fill: parent
            anchors.margins: Math.round(10 * body.s)
            sourceComponent: View.layout === "grid" ? gridC
                : View.layout === "hearthstone" ? hearthC
                : View.layout === "drift" ? driftC : stripsC
            onItemChanged: if (item) item.selIndex = Qt.binding(() => body.selIndex)
        }
        Component {
            id: stripsC
            LayoutStrips {
                s: body.s; model: body.shown; kind: body.themesMode ? "theme" : "wall"
                bg: Theme.surface; active: body.active; activeKey: body.activeKey
                interactive: true
                onFocusIndex: (i) => body.focusAt(i)
                onChosen: (i) => body.choose(i)
            }
        }
        Component {
            id: hearthC
            LayoutHearthstone {
                s: body.s; model: body.shown; kind: body.themesMode ? "theme" : "wall"
                bg: Theme.surface; active: body.active; activeKey: body.activeKey
                interactive: true
                onFocusIndex: (i) => body.focusAt(i)
                onChosen: (i) => body.choose(i)
            }
        }
        Component {
            id: driftC
            LayoutDrift {
                s: body.s; model: body.shown; kind: body.themesMode ? "theme" : "wall"
                bg: Theme.surface; active: body.active; activeKey: body.activeKey
                interactive: true
                onFocusIndex: (i) => body.focusAt(i)
                onChosen: (i) => body.choose(i)
            }
        }
        Component {
            id: gridC
            LayoutGrid {
                s: body.s; model: body.shown; kind: body.themesMode ? "theme" : "wall"
                bg: Theme.surface; active: body.active; activeKey: body.activeKey
                interactive: true
                onFocusIndex: (i) => body.focusAt(i)
                onChosen: (i) => body.choose(i)
            }
        }
    }

    // empty / loading
    Text {
        anchors.centerIn: parent
        visible: body.shown.length === 0
        horizontalAlignment: Text.AlignHCenter
        text: body.themesMode
            ? (Themes.loading ? I18n.tr("Reading colour schemes") : (body.search.length > 0 ? I18n.tr("No schemes match \u201c") + body.search + "\u201d" : I18n.tr("No colour schemes")))
            : Walls.loading ? I18n.tr("Reading wallpapers")
            : (body.search.length > 0 ? I18n.tr("No wallpapers match \u201c") + body.search + "\u201d"
                : (body.colorFilter !== -1 || body.typeFilter !== "all") ? I18n.tr("Nothing in this filter")
                : I18n.tr("No wallpapers in ~/Pictures/Wallpapers"))
        color: Theme.onSurface
        font.family: Theme.ui
        font.pixelSize: Math.round(16 * body.s)
    }

    // click anywhere (while a drawer is open) to dismiss it, not the switcher
    MouseArea {
        anchors.fill: parent
        visible: body.drawer !== ""
        onClicked: body.drawer = ""
    }

    // ── drawer: a popover above the bar (layout picker / filters) ──
    Rectangle {
        id: drawer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: stage.top
        anchors.bottomMargin: body.drawer !== "" ? Math.round(10 * body.s) : Math.round(2 * body.s)
        Behavior on anchors.bottomMargin { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        opacity: body.drawer !== "" ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
        height: Math.round(40 * body.s)
        width: (body.drawer === "filter" ? filterRow.implicitWidth : layoutRow.implicitWidth) + Math.round(24 * body.s)
        radius: Math.round(8 * body.s)
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.96)
        border.width: 1
        border.color: Theme.lineStrong
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: (m) => m.accepted = true }

        Row {
            id: layoutRow
            anchors.centerIn: parent
            spacing: Math.round(4 * body.s)
            visible: body.drawer === "layout"
            IconBtn { label: I18n.tr("Strips"); on: View.layout === "strips"; onClicked: { View.layout = "strips"; body.drawer = ""; } }
            IconBtn { label: I18n.tr("Hearthstone"); on: View.layout === "hearthstone"; onClicked: { View.layout = "hearthstone"; body.drawer = ""; } }
            IconBtn { label: I18n.tr("Drift"); on: View.layout === "drift"; onClicked: { View.layout = "drift"; body.drawer = ""; } }
            IconBtn { label: I18n.tr("Grid"); on: View.layout === "grid"; onClicked: { View.layout = "grid"; body.drawer = ""; } }
        }
        Row {
            id: filterRow
            anchors.centerIn: parent
            spacing: Math.round(8 * body.s)
            visible: body.drawer === "filter"
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(2 * body.s)
                IconBtn { label: I18n.tr("All"); on: body.typeFilter === "all"; onClicked: body.setType("all") }
                IconBtn { label: I18n.tr("Img"); on: body.typeFilter === "image"; onClicked: body.setType("image") }
                IconBtn { label: I18n.tr("Live"); on: body.typeFilter === "live"; onClicked: body.setType("live") }
            }
            Sep {}
            ColorStrip {
                anchors.verticalCenter: parent.verticalCenter
                height: Math.round(20 * body.s)
                s: body.s
                groups: body.wallGroups
                selected: body.colorFilter
                onPicked: (g) => body.setColor(g)
            }
            Sep {}
            IconBtn { glyph: "\u21c5"; label: View.sortLabel(View.sort); onClicked: View.cycleSort() }
            Sep {}
            IconBtn { glyph: View.livePreview ? "\u25c9" : "\u25cb"; label: I18n.tr("Preview"); on: View.livePreview; onClicked: View.livePreview = !View.livePreview }
        }
    }

    // ── the bar: compact, bottom-centre; secondary controls live in drawers ──
    Rectangle {
        id: bar
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(16 * body.s)
        anchors.horizontalCenter: parent.horizontalCenter
        height: Math.round(32 * body.s)
        width: barRow.implicitWidth + Math.round(24 * body.s)
        radius: Math.round(8 * body.s)
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.94)
        border.width: 1
        border.color: Theme.lineStrong
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: (m) => m.accepted = true }

        Row {
            id: barRow
            anchors.centerIn: parent
            spacing: Math.round(8 * body.s)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.mark
                color: Theme.seal
                font.family: Theme.fontJp
                font.pixelSize: Math.round(15 * body.s)
            }
            Sep {}
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(2 * body.s)
                Seg { label: I18n.tr("Walls"); on: !body.themesMode; onClicked: body.setMode("walls") }
                Seg { label: I18n.tr("Themes"); on: body.themesMode; onClicked: body.setMode("themes") }
            }
            Sep {}
            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                visible: !body.themesMode && body.monitors.length > 1
                glyph: "\u25a3"; label: body.targetLabel
                onClicked: body.cycleTarget()
            }
            Sep { visible: !body.themesMode && body.monitors.length > 1 }
            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                glyph: "\u25b4"; label: View.layoutLabel(View.layout)
                on: body.drawer === "layout"
                onClicked: body.drawer = (body.drawer === "layout" ? "" : "layout")
            }
            IconBtn {
                anchors.verticalCenter: parent.verticalCenter
                visible: !body.themesMode
                glyph: "\u25b4"; label: I18n.tr("Filter")
                on: body.drawer === "filter"
                onClicked: body.drawer = (body.drawer === "filter" ? "" : "filter")
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(2 * body.s)
                visible: body.themesMode
                IconBtn { glyph: body.following ? "\u25c9" : "\u25cb"; label: I18n.tr("Follow"); on: body.following; onClicked: body.toggleFollow() }
                IconBtn { label: "Default"; on: Themes.active === "Default"; onClicked: { Themes.apply("Default"); body.touchedTheme = true; } }
            }
            Sep {}
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * body.s)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2315"
                    color: body.search.length > 0 ? Theme.onSurface : Theme.inkDim
                    font.family: Theme.mono
                    font.pixelSize: Math.round(13 * body.s)
                }
                Text {
                    visible: body.search.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: body.search
                    color: Theme.onSurface
                    font.family: Theme.mono
                    font.pixelSize: Math.round(11 * body.s)
                }
            }
            Sep {}
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: body.shown.length > 0 ? (body.pad2(body.selIndex + 1) + " / " + body.pad2(body.shown.length)) : "--"
                color: Theme.inkDim
                font.family: Theme.mono
                font.pixelSize: Math.round(11 * body.s)
                font.letterSpacing: 1 * body.s
            }
        }
    }
}
