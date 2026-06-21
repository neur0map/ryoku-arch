pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "Singletons"

// Displays: detect every connected monitor and arrange them visually, no
// coordinate math. Drag tiles on the canvas to place them; tune resolution,
// refresh, scale, rotation, VRR, and mirroring per monitor; then Apply to the
// live session (ryoku-monitor apply) or Save a named, hardware-keyed profile that
// recalls itself at login. Edits stage in the canvas and only touch the displays
// on Apply, so fiddling never disrupts your screens.
Item {
    id: page

    // Live baseline (from ryoku-monitor list) and the editable draft. monCount is
    // the Repeater model so reassigning draft never happens for in-place edits;
    // `tick` drives reactivity for those mutations (a drag must not rebuild tiles).
    property var draft: []
    property int monCount: 0
    property int selected: 0
    property int tick: 0
    property string committed: "[]"
    property var profiles: []

    property bool dragging: false
    property var frozen: ({ "k": 1, "ox": 0, "oy": 0 })

    readonly property var sel: (page.selected >= 0 && page.selected < page.draft.length) ? page.draft[page.selected] : null

    // --- data load ----------------------------------------------------------
    Process {
        id: listProc
        command: ["ryoku-monitor", "list"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(this.text);
                    var d = [];
                    for (var i = 0; i < arr.length; i++)
                        d.push(page.clone(arr[i]));
                    page.draft = d;
                    page.monCount = d.length;
                    page.committed = JSON.stringify(page.specsAll());
                    if (page.selected >= d.length)
                        page.selected = 0;
                    page.tick++;
                } catch (e) {
                    console.log("hub: monitor list parse failed: " + e);
                }
            }
        }
    }

    Process {
        id: profilesProc
        command: ["ryoku-monitor", "profiles"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.profiles = JSON.parse(this.text); } catch (e) { page.profiles = []; }
            }
        }
    }

    Process { id: applyProc }
    Process { id: profileProc } // save / load / rm

    function reload() { listProc.running = true; profilesProc.running = true; }
    function reloadProfiles() { profilesProc.running = true; }

    // --- model helpers ------------------------------------------------------
    function parseMode(s) {
        var m = /^(\d+)x(\d+)@([\d.]+)/.exec(s);
        if (!m)
            return null;
        var w = parseInt(m[1]), h = parseInt(m[2]);
        return { "key": w + "x" + h + "@" + m[3], "label": w + " \u00d7 " + h + "  \u00b7  " + Math.round(parseFloat(m[3])) + " Hz", "w": w, "h": h, "rate": parseFloat(m[3]) };
    }
    function modeOptions(mon) {
        var seen = ({}), out = [];
        var arr = mon && mon.modes ? mon.modes : [];
        for (var i = 0; i < arr.length; i++) {
            var p = page.parseMode(arr[i]);
            if (!p || seen[p.key])
                continue;
            seen[p.key] = true;
            out.push(p);
        }
        out.sort((a, b) => (b.w * b.h - a.w * a.h) || (b.rate - a.rate));
        return out;
    }
    function pickCurrentMode(mon) {
        var arr = page.modeOptions(mon);
        for (var i = 0; i < arr.length; i++)
            if (arr[i].w === mon.width && arr[i].h === mon.height && Math.round(arr[i].rate) === Math.round(mon.refresh))
                return arr[i].key;
        for (i = 0; i < arr.length; i++)
            if (arr[i].w === mon.width && arr[i].h === mon.height)
                return arr[i].key;
        return mon.width + "x" + mon.height + "@" + mon.refresh;
    }
    function clone(mon) {
        return {
            "id": mon.id, "name": mon.name, "modes": (mon.modes || []),
            "width": mon.width, "height": mon.height, "refresh": mon.refresh,
            "mode": page.pickCurrentMode(mon),
            "scale": mon.scale, "x": mon.x, "y": mon.y, "transform": mon.transform || 0,
            "vrr": (mon.vrr === true ? 1 : (mon.vrr | 0)),
            "mirror": (mon.mirror && mon.mirror !== "none") ? mon.mirror : "",
            "disabled": mon.disabled === true
        };
    }
    function footW(m) {
        var lw = Math.round(m.width / m.scale), lh = Math.round(m.height / m.scale);
        return (m.transform & 1) ? lh : lw;
    }
    function footH(m) {
        var lw = Math.round(m.width / m.scale), lh = Math.round(m.height / m.scale);
        return (m.transform & 1) ? lw : lh;
    }
    function specsAll() {
        var out = [];
        for (var i = 0; i < page.draft.length; i++) {
            var m = page.draft[i];
            out.push({
                "id": m.id, "output": m.name, "mode": m.mode, "position": m.x + "x" + m.y,
                "scale": m.scale, "transform": m.transform, "vrr": m.vrr,
                "mirror": m.mirror, "disabled": m.disabled
            });
        }
        return out;
    }
    readonly property bool dirty: {
        void page.tick;
        return page.monCount > 0 && JSON.stringify(page.specsAll()) !== page.committed;
    }

    function setField(i, key, val) {
        if (i < 0 || i >= page.draft.length)
            return;
        page.draft[i][key] = val;
        page.tick++;
    }
    function setMode(i, key) {
        var p = page.parseMode(key);
        if (!p)
            return;
        page.draft[i].mode = key;
        page.draft[i].width = p.w;
        page.draft[i].height = p.h;
        page.draft[i].refresh = p.rate;
        page.tick++;
    }

    // --- canvas geometry ----------------------------------------------------
    function bbox() {
        var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9, any = false;
        for (var i = 0; i < page.draft.length; i++) {
            var m = page.draft[i];
            if (m.disabled)
                continue;
            any = true;
            minX = Math.min(minX, m.x);
            minY = Math.min(minY, m.y);
            maxX = Math.max(maxX, m.x + page.footW(m));
            maxY = Math.max(maxY, m.y + page.footH(m));
        }
        if (!any)
            return { "x": 0, "y": 0, "w": 1, "h": 1 };
        return { "x": minX, "y": minY, "w": Math.max(1, maxX - minX), "h": Math.max(1, maxY - minY) };
    }
    function computeView(cw, ch) {
        var b = page.bbox();
        if (cw <= 0 || ch <= 0)
            return { "k": 0.05, "ox": 0, "oy": 0 };
        var k = Math.min(cw * 0.84 / b.w, ch * 0.84 / b.h);
        if (!isFinite(k) || k <= 0)
            k = 0.05;
        return { "k": k, "ox": (cw - b.w * k) / 2 - b.x * k, "oy": (ch - b.h * k) / 2 - b.y * k };
    }
    function view() {
        void page.tick;
        return page.dragging ? page.frozen : page.computeView(canvasArea.width, canvasArea.height);
    }

    function nearestSnap(val, cands, th) {
        var best = val, bd = th;
        for (var i = 0; i < cands.length; i++) {
            var d = Math.abs(val - cands[i]);
            if (d < bd) { bd = d; best = cands[i]; }
        }
        return best;
    }
    function dragMonitor(i, dxLogical, dyLogical) {
        if (i < 0 || i >= page.draft.length)
            return;
        if (!page.dragging) {
            page.frozen = page.computeView(canvasArea.width, canvasArea.height);
            page.dragging = true;
        }
        page.draft[i].x += dxLogical;
        page.draft[i].y += dyLogical;
        page.tick++;
    }
    function endDrag(i) {
        if (i < 0 || i >= page.draft.length) {
            page.dragging = false;
            return;
        }
        var m = page.draft[i];
        var k = page.computeView(canvasArea.width, canvasArea.height).k;
        var th = Math.max(8, 22 / Math.max(0.0001, k));
        var xs = [0], ys = [0];
        for (var j = 0; j < page.draft.length; j++) {
            if (j === i || page.draft[j].disabled)
                continue;
            var o = page.draft[j];
            xs.push(o.x, o.x + page.footW(o), o.x - page.footW(m));
            ys.push(o.y, o.y + page.footH(o), o.y - page.footH(m));
        }
        m.x = Math.round(page.nearestSnap(m.x, xs, th));
        m.y = Math.round(page.nearestSnap(m.y, ys, th));
        page.normalize();
        page.dragging = false;
        page.tick++;
    }
    function normalize() {
        var minX = 1e9, minY = 1e9;
        for (var i = 0; i < page.draft.length; i++) {
            if (page.draft[i].disabled)
                continue;
            minX = Math.min(minX, page.draft[i].x);
            minY = Math.min(minY, page.draft[i].y);
        }
        if (!isFinite(minX))
            return;
        for (i = 0; i < page.draft.length; i++) {
            page.draft[i].x -= minX;
            page.draft[i].y -= minY;
        }
    }

    // --- apply / profiles ---------------------------------------------------
    function apply() {
        applyProc.command = ["ryoku-monitor", "apply", JSON.stringify(page.specsAll())];
        applyProc.running = true;
        page.committed = JSON.stringify(page.specsAll());
        page.tick++;
    }
    function saveProfile(name) {
        if (name.trim() === "")
            return;
        profileProc.command = ["ryoku-monitor", "save", name.trim(), JSON.stringify(page.specsAll())];
        profileProc.running = true;
        page.committed = JSON.stringify(page.specsAll());
        page.tick++;
        nameField.text = "";
        profileRefresh.start();
    }
    function loadProfile(name) {
        profileProc.command = ["ryoku-monitor", "load", name];
        profileProc.running = true;
        listRefresh.start();
    }
    function deleteProfile(name) {
        profileProc.command = ["ryoku-monitor", "rm", name];
        profileProc.running = true;
        profileRefresh.start();
    }
    function quick(cmd) {
        applyProc.command = ["ryoku-monitor", cmd];
        applyProc.running = true;
        listRefresh.start();
    }

    Timer { id: listRefresh; interval: 700; onTriggered: page.reload() }
    Timer { id: profileRefresh; interval: 300; onTriggered: page.reloadProfiles() }

    // --- layout -------------------------------------------------------------
    Text {
        id: detected
        anchors.left: parent.left
        anchors.top: parent.top
        text: page.monCount === 1 ? "1 display detected" : page.monCount + " displays detected"
        color: Theme.subtle
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    Row {
        id: quickRow
        anchors.right: parent.right
        anchors.verticalCenter: detected.verticalCenter
        spacing: 8
        HubButton { label: "Mirror"; icon: "display"; onClicked: page.quick("mirror") }
        HubButton { label: "Extend"; icon: "display"; onClicked: page.quick("extend") }
        HubButton { label: "DPI auto-scale"; icon: "refresh"; onClicked: page.quick("autoscale") }
    }

    Row {
        id: main
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: detected.bottom
        anchors.topMargin: 16
        anchors.bottom: bar.top
        anchors.bottomMargin: 16
        spacing: 24

        // canvas
        Rectangle {
            id: canvasArea
            width: parent.width - controls.width - main.spacing
            height: parent.height
            radius: 16
            color: Theme.surfaceLo
            border.width: 1
            border.color: Theme.line
            clip: true

            // a faint grid baseline
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 15
                color: "transparent"
            }

            Repeater {
                model: page.monCount

                delegate: MonitorTile {
                    id: tile
                    required property int index
                    readonly property var m: page.draft[index]
                    readonly property var v: page.view()

                    visible: !!m
                    x: m ? (m.x * v.k + v.ox) : 0
                    y: m ? (m.y * v.k + v.oy) : 0
                    width: m ? Math.max(36, page.footW(m) * v.k) : 36
                    height: m ? Math.max(28, page.footH(m) * v.k) : 28
                    canvasScale: v.k

                    title: m ? m.name : ""
                    sub: m ? (m.width + "\u00d7" + m.height) : ""
                    live: m ? !m.disabled : true
                    mirrored: m ? (m.mirror !== "") : false
                    selected: page.selected === index

                    onTapped: page.selected = index
                    onDragDelta: (dx, dy) => page.dragMonitor(index, dx, dy)
                    onDragEnded: page.endDrag(index)
                }
            }

            Text {
                anchors.centerIn: parent
                visible: page.monCount === 0
                text: "Detecting displays\u2026"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 14
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 12
                text: "Drag a display to arrange it \u00b7 edges snap"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        // per-monitor controls
        Flickable {
            id: controls
            width: 392
            height: parent.height
            contentWidth: width
            contentHeight: Math.max(ctlCol.height, height)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                id: csb
                policy: ScrollBar.AsNeeded
                width: 7
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: Theme.line
                    opacity: csb.pressed ? 0.9 : (csb.hovered ? 0.7 : 0.4)
                }
            }

            Column {
                id: ctlCol
                width: controls.width - 12
                spacing: 26

                Text {
                    visible: !page.sel
                    text: "Select a display to configure it."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 13
                }

                SettingSection {
                    width: parent.width
                    visible: !!page.sel
                    title: page.sel ? page.sel.name : "DISPLAY"

                    ToggleRow {
                        width: parent.width; label: "Enabled"
                        checked: { void page.tick; return page.sel ? !page.sel.disabled : true; }
                        onToggled: (v) => page.setField(page.selected, "disabled", !v)
                    }
                    Dropdown {
                        width: parent.width; label: "Resolution"
                        fieldWidth: 190
                        options: { void page.tick; return page.sel ? page.modeOptions(page.sel) : []; }
                        current: { void page.tick; return page.sel ? page.sel.mode : ""; }
                        onChosen: (k) => page.setMode(page.selected, k)
                    }
                    NumberField {
                        width: parent.width; label: "Scale"
                        from: 0.5; to: 3; step: 0.25; decimals: 2
                        value: { void page.tick; return page.sel ? page.sel.scale : 1; }
                        onModified: (v) => page.setField(page.selected, "scale", v)
                    }
                    ChoiceRow {
                        width: parent.width; label: "Rotation"
                        options: [{ "key": "0", "label": "0\u00b0" }, { "key": "1", "label": "90\u00b0" }, { "key": "2", "label": "180\u00b0" }, { "key": "3", "label": "270\u00b0" }]
                        current: { void page.tick; return page.sel ? String(page.sel.transform) : "0"; }
                        onChosen: (k) => page.setField(page.selected, "transform", parseInt(k))
                    }
                    ChoiceRow {
                        width: parent.width; label: "Adaptive sync"
                        options: [{ "key": "0", "label": "Off" }, { "key": "1", "label": "On" }, { "key": "2", "label": "Fullscreen" }]
                        current: { void page.tick; return page.sel ? String(page.sel.vrr) : "0"; }
                        onChosen: (k) => page.setField(page.selected, "vrr", parseInt(k))
                    }
                    Dropdown {
                        width: parent.width; label: "Mirror of"
                        fieldWidth: 190
                        options: page.mirrorOptions()
                        current: { void page.tick; return page.sel ? page.sel.mirror : ""; }
                        onChosen: (k) => page.setField(page.selected, "mirror", k)
                    }
                }

                SettingSection {
                    width: parent.width
                    visible: !!page.sel
                    title: "POSITION"
                    NumberField {
                        width: parent.width; label: "X"; unit: "px"
                        from: 0; to: 20000; step: 10
                        value: { void page.tick; return page.sel ? page.sel.x : 0; }
                        onModified: (v) => page.setField(page.selected, "x", v)
                    }
                    NumberField {
                        width: parent.width; label: "Y"; unit: "px"
                        from: 0; to: 20000; step: 10
                        value: { void page.tick; return page.sel ? page.sel.y : 0; }
                        onModified: (v) => page.setField(page.selected, "y", v)
                    }
                }

                SettingSection {
                    width: parent.width
                    title: "PROFILES"

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "Save this layout, keyed to the connected displays, so it returns automatically when you plug them in again."
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 12
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: parent.width - saveBtn.width - 8
                            height: 32
                            radius: 9
                            color: Theme.surfaceLo
                            border.width: 1
                            border.color: nameField.activeFocus ? Theme.ember : Theme.line
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            TextInput {
                                id: nameField
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onAccepted: page.saveProfile(text)

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: nameField.text === "" && !nameField.activeFocus
                                    text: "Profile name\u2026"
                                    color: Theme.faint
                                    font: nameField.font
                                }
                            }
                        }

                        HubButton {
                            id: saveBtn
                            label: "Save"
                            icon: "check"
                            onClicked: page.saveProfile(nameField.text)
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 7

                        Repeater {
                            model: page.profiles

                            delegate: Rectangle {
                                id: prof
                                required property var modelData
                                width: ctlCol.width - 12
                                height: 38
                                radius: 9
                                color: phov.hovered ? Theme.keyTop : Theme.surfaceLo
                                border.width: 1
                                border.color: prof.modelData.matches ? Theme.ember : Theme.line

                                HoverHandler { id: phov }

                                Row {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: prof.modelData.name
                                        color: Theme.bright
                                        font.family: Theme.font
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: prof.modelData.matches
                                        text: "CONNECTED"
                                        color: Theme.ember
                                        font.family: Theme.mono
                                        font.pixelSize: 8
                                        font.letterSpacing: 1.5
                                    }
                                }

                                Row {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6

                                    HubButton { label: "Apply"; onClicked: page.loadProfile(prof.modelData.name) }
                                    Item {
                                        width: 26; height: 26
                                        anchors.verticalCenter: parent.verticalCenter
                                        Icon {
                                            anchors.centerIn: parent
                                            name: "trash"; size: 15
                                            tint: delHov.hovered ? Theme.bad : Theme.faint
                                        }
                                        HoverHandler { id: delHov; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: page.deleteProfile(prof.modelData.name) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function mirrorOptions() {
        void page.tick;
        var out = [{ "key": "", "label": "None" }];
        for (var i = 0; i < page.draft.length; i++) {
            if (i === page.selected || page.draft[i].disabled)
                continue;
            out.push({ "key": page.draft[i].name, "label": page.draft[i].name });
        }
        return out;
    }

    // --- action bar ---------------------------------------------------------
    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        height: 60
        radius: 14
        color: page.dirty ? Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.08) : Theme.surfaceLo
        border.width: 1
        border.color: page.dirty ? Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.4) : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.medium } }
        Behavior on border.color { ColorAnimation { duration: Theme.medium } }

        Rectangle {
            id: dot
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 9; height: 9; radius: 4.5
            color: page.dirty ? Theme.ember : Theme.ok
        }
        Text {
            anchors.left: dot.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: page.dirty ? "Unapplied layout changes" : "Layout matches your displays"
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
                onClicked: page.reload()
            }
            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Apply"
                icon: "check"
                primary: true
                enabled: page.dirty
                onClicked: page.apply()
            }
        }
    }
}
