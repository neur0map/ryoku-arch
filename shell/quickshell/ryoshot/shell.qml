import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "lib/coords.js" as Coords
import "lib/AnnotationModel.js" as Ann

ShellRoot {
    id: root

    property var globalSel: null
    property var pressPoint: null
    property bool capturing: false
    property string phase: "selecting"
    property string activeTool: "rect"
    property color activeColor: vermilion
    property int activeWidth: 4

    property var model: Ann.create()
    property var draft: null
    property int annRevision: 0
    property bool settingsOpen: false
    property bool textEditing: false

    property var selectedIndex: null
    property var moveOffset: null
    property var moveStart: null
    property var hoverWindow: null
    property var windowRects: []
    property bool dialogMode: false
    property string savedAuto: ""

    function textSize() { return activeWidth * 5 + 8; }

    property var overlays: []
    property int frozenCount: 0

    readonly property bool testRect: Quickshell.env("RYOSHOT_TESTRECT") === "1"
    readonly property string mode: Quickshell.env("RYOSHOT_MODE") === "monitor" ? "monitor" : "region"
    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string shotsDir: homeDir + "/Pictures/Screenshots"
    readonly property string ryoshotLuaPath: homeDir + "/.config/hypr/modules/ryoshot.lua"

    readonly property color vermilion: "#e0563b"

    function beginSelection(gx, gy) {
        pressPoint = { x: gx, y: gy };
        capturing = true;
        globalSel = { x: gx, y: gy, w: 0, h: 0 };
    }
    function updateSelection(gx, gy) {
        if (!pressPoint) return;
        globalSel = Coords.rectFromPoints(pressPoint, { x: gx, y: gy });
    }
    function endSelection() {
        capturing = false;
        pressPoint = null;
        if (globalSel && globalSel.w > 2 && globalSel.h > 2) { phase = "editing"; hoverWindow = null; }
        else if (hoverWindow) {
            globalSel = { x: hoverWindow.x, y: hoverWindow.y, w: hoverWindow.w, h: hoverWindow.h };
            phase = "editing";
            hoverWindow = null;
        } else globalSel = null;
    }

    function clampToSel(gx, gy) {
        var x = Math.max(globalSel.x, Math.min(gx, globalSel.x + globalSel.w));
        var y = Math.max(globalSel.y, Math.min(gy, globalSel.y + globalSel.h));
        return { x: x, y: y };
    }
    function isFreehand(t) { return t === "pen"; }

    function placeText(gx, gy) {
        if (textEditing) { commitText(); return; }
        var p = clampToSel(gx, gy);
        draft = { type: "text", points: [p], color: String(activeColor), text: "", size: textSize() };
        textEditing = true;
        bumpAnn();
    }
    function commitText() {
        if (draft && draft.type === "text") {
            if (draft.text && draft.text.length > 0) model.add(draft);
        }
        draft = null;
        textEditing = false;
        bumpAnn();
    }
    function cancelText() {
        draft = null;
        textEditing = false;
        bumpAnn();
    }

    function bboxOf(a) {
        var xs = a.points.map(function (p) { return p.x; });
        var ys = a.points.map(function (p) { return p.y; });
        var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs);
        var y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);
        if (a.type === "text") {
            var size = a.size || 16;
            var w = Math.max((a.text ? a.text.length : 1) * size * 0.6, size);
            return { x: x0, y: y0, w: w, h: size * 1.4 };
        }
        return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
    }

    function distToSeg(px, py, a, b) {
        var dx = b.x - a.x, dy = b.y - a.y;
        var len2 = dx * dx + dy * dy;
        if (len2 === 0) return Math.hypot(px - a.x, py - a.y);
        var t = ((px - a.x) * dx + (py - a.y) * dy) / len2;
        t = Math.max(0, Math.min(1, t));
        return Math.hypot(px - (a.x + t * dx), py - (a.y + t * dy));
    }

    function inBox(gx, gy, b, pad) {
        return gx >= b.x - pad && gx <= b.x + b.w + pad
            && gy >= b.y - pad && gy <= b.y + b.h + pad;
    }

    function hitOne(a, gx, gy) {
        var tol = Math.max(a.width || 4, 8);
        if (a.type === "rect" || a.type === "marker" || a.type === "blur" || a.type === "text")
            return inBox(gx, gy, bboxOf(a), a.type === "text" ? 0 : tol);
        if (a.type === "line" || a.type === "arrow")
            return distToSeg(gx, gy, a.points[0], a.points[1]) <= tol;
        if (a.type === "pen") {
            for (var i = 1; i < a.points.length; i++)
                if (distToSeg(gx, gy, a.points[i - 1], a.points[i]) <= tol) return true;
            return false;
        }
        if (a.type === "ellipse") {
            var b = bboxOf(a);
            var rx = b.w / 2 + tol, ry = b.h / 2 + tol;
            if (rx <= 0 || ry <= 0) return false;
            var nx = (gx - (b.x + b.w / 2)) / rx, ny = (gy - (b.y + b.h / 2)) / ry;
            return nx * nx + ny * ny <= 1;
        }
        return false;
    }

    function hitTest(gx, gy) {
        var its = model.items;
        for (var i = its.length - 1; i >= 0; i--)
            if (hitOne(its[i], gx, gy)) return i;
        return null;
    }

    function clearSelection() {
        if (selectedIndex !== null) { selectedIndex = null; bumpAnn(); }
    }

    function deleteSelected() {
        if (selectedIndex === null) return;
        model.remove(selectedIndex);
        selectedIndex = null;
        bumpAnn();
    }

    function beginSelect(gx, gy) {
        var idx = hitTest(gx, gy);
        selectedIndex = idx;
        if (idx !== null) {
            capturing = true;
            moveStart = { x: gx, y: gy };
            moveOffset = { x: 0, y: 0 };
        }
        bumpAnn();
    }
    function updateSelect(gx, gy) {
        if (selectedIndex === null || !moveStart) return;
        moveOffset = { x: gx - moveStart.x, y: gy - moveStart.y };
        bumpAnn();
    }
    function endSelect() {
        capturing = false;
        if (selectedIndex !== null && moveOffset
            && (moveOffset.x !== 0 || moveOffset.y !== 0)) {
            model.move(selectedIndex, moveOffset.x, moveOffset.y);
        }
        moveOffset = null;
        moveStart = null;
        bumpAnn();
    }

    function beginDraw(gx, gy) {
        if (!globalSel || activeTool === "select") return;
        if (activeTool === "text") { placeText(gx, gy); return; }
        var p = clampToSel(gx, gy);
        pressPoint = p;
        capturing = true;
        if (isFreehand(activeTool))
            draft = { type: activeTool, points: [p], color: String(activeColor), width: activeWidth };
        else if (activeTool === "marker")
            draft = { type: "marker", points: [p, p], color: "#f5d020", width: activeWidth, filled: true };
        else
            draft = { type: activeTool, points: [p, p], color: String(activeColor), width: activeWidth, filled: false };
        bumpAnn();
    }
    function updateDraw(gx, gy) {
        if (!draft || !pressPoint || draft.type === "text") return;
        var p = clampToSel(gx, gy);
        if (isFreehand(draft.type)) {
            var last = draft.points[draft.points.length - 1];
            if (Math.abs(p.x - last.x) < 2 && Math.abs(p.y - last.y) < 2) return;
            draft.points = draft.points.concat([p]);
        } else {
            draft.points = [pressPoint, p];
        }
        bumpAnn();
    }
    function endDraw() {
        capturing = false;
        if (!draft || draft.type === "text") return;
        if (isFreehand(draft.type)) {
            if (draft.points.length >= 2) model.add(draft);
        } else {
            var p0 = draft.points[0], p1 = draft.points[1];
            var dx = Math.abs(p1.x - p0.x), dy = Math.abs(p1.y - p0.y);
            var big = draft.type === "line" || draft.type === "arrow"
                ? Math.hypot(dx, dy) > 4
                : dx > 2 && dy > 2;
            if (big) model.add(draft);
        }
        draft = null;
        pressPoint = null;
        bumpAnn();
    }
    function bumpAnn() { annRevision += 1; }

    function undo() { if (model.undo()) { selectedIndex = null; moveOffset = null; moveStart = null; bumpAnn(); } }
    function redo() { if (model.redo()) { selectedIndex = null; moveOffset = null; moveStart = null; bumpAnn(); } }

    function windowAt(gx, gy) {
        var best = null;
        for (var i = 0; i < windowRects.length; i++) {
            var r = windowRects[i];
            if (gx >= r.x && gx < r.x + r.w && gy >= r.y && gy < r.y + r.h) {
                if (best === null || r.z < best.z) best = r;
            }
        }
        return best ? { x: best.x, y: best.y, w: best.w, h: best.h } : null;
    }
    function monitorAt(gx, gy) {
        var scr = Quickshell.screens;
        for (var i = 0; i < scr.length; i++) {
            var s = scr[i];
            if (gx >= s.x && gx < s.x + s.width && gy >= s.y && gy < s.y + s.height)
                return { x: s.x, y: s.y, w: s.width, h: s.height };
        }
        return null;
    }
    function selectMonitor(gx, gy) {
        var m = monitorAt(gx, gy);
        if (!m) return;
        globalSel = m;
        phase = "editing";
        hoverWindow = null;
    }
    function pointerHover(gx, gy) {
        if (phase !== "selecting") { if (hoverWindow !== null) hoverWindow = null; return; }
        hoverWindow = mode === "monitor" ? monitorAt(gx, gy) : windowAt(gx, gy);
    }
    function parseWindows(activeWs, json) {
        var rects = [];
        try {
            var arr = JSON.parse(json);
            for (var i = 0; i < arr.length; i++) {
                var c = arr[i];
                if (!c.mapped || c.hidden) continue;
                if (!c.workspace || activeWs.indexOf(c.workspace.id) === -1) continue;
                if (!c.size || c.size[0] <= 0 || c.size[1] <= 0) continue;
                rects.push({ x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1], z: c.focusHistoryID });
            }
        } catch (e) { console.log("ryoshot: parseWindows failed: " + e); }
        windowRects = rects;
    }
    function parseActiveWs(json) {
        var ids = [];
        try {
            var arr = JSON.parse(json);
            for (var i = 0; i < arr.length; i++)
                if (arr[i].activeWorkspace) ids.push(arr[i].activeWorkspace.id);
        } catch (e) { console.log("ryoshot: parseActiveWs failed: " + e); }
        return ids;
    }
    function pointerPressed(gx, gy) {
        if (phase === "selecting") {
            if (mode === "monitor") selectMonitor(gx, gy);
            else beginSelection(gx, gy);
        }
        else if (activeTool === "select") beginSelect(gx, gy);
        else beginDraw(gx, gy);
    }
    function pointerMoved(gx, gy) {
        if (phase === "selecting") updateSelection(gx, gy);
        else if (activeTool === "select") updateSelect(gx, gy);
        else updateDraw(gx, gy);
    }
    function pointerReleased() {
        if (phase === "selecting") endSelection();
        else if (activeTool === "select") endSelect();
        else endDraw();
    }

    function timestampName() {
        var d = new Date();
        function p(n) { return (n < 10 ? "0" : "") + n; }
        return "shot-" + d.getFullYear() + p(d.getMonth() + 1) + p(d.getDate())
            + "-" + p(d.getHours()) + p(d.getMinutes()) + p(d.getSeconds()) + ".png";
    }
    readonly property string defaultPath: shotsDir + "/" + timestampName()

    function anchorOverlay() {
        if (!globalSel) return null;
        for (var i = 0; i < overlays.length; i++) {
            var w = overlays[i];
            var s = w.modelData;
            if (globalSel.x >= s.x && globalSel.x < s.x + s.width
                && globalSel.y >= s.y && globalSel.y < s.y + s.height) return w;
        }
        return overlays.length ? overlays[0] : null;
    }

    function spansMonitors() {
        if (!globalSel) return false;
        var hit = 0;
        for (var i = 0; i < overlays.length; i++) {
            var s = overlays[i].modelData;
            if (Coords.intersectRect(globalSel, { x: s.x, y: s.y, width: s.width, height: s.height })) hit++;
        }
        return hit > 1;
    }

    function grabTo(path, after) {
        var w = anchorOverlay();
        if (!w) { if (after) after(false); return; }
        if (spansMonitors()) { seamStitch(path, after); return; }
        w.grabExport(path, function (ok) {
            console.log("ryoshot: grab " + path + " => " + ok);
            if (after) after(ok);
        });
    }

    function seamStitch(path, after) {
        var slices = [];
        for (var i = 0; i < overlays.length; i++) {
            var s = overlays[i].modelData;
            var inter = Coords.intersectRect(globalSel, { x: s.x, y: s.y, width: s.width, height: s.height });
            if (!inter) continue;
            slices.push({
                win: overlays[i],
                tmp: "/tmp/ryoshot-seam-" + i + ".png",
                ox: Math.round(s.x + inter.x - globalSel.x),
                oy: Math.round(s.y + inter.y - globalSel.y)
            });
        }
        if (slices.length === 0) { if (after) after(false); return; }
        if (slices.length === 1) { slices[0].win.grabExport(path, after); return; }
        var done = 0, okAll = true;
        for (var j = 0; j < slices.length; j++) {
            (function (sl) {
                sl.win.grabExport(sl.tmp, function (ok) {
                    if (!ok) okAll = false;
                    done += 1;
                    if (done === slices.length) compositeSlices(slices, path, okAll, after);
                });
            })(slices[j]);
        }
    }

    function compositeSlices(slices, path, okAll, after) {
        if (!okAll) { console.log("ryoshot: seam-stitch slice grab failed"); if (after) after(false); return; }
        var args = ["magick", "-size", Math.round(globalSel.w) + "x" + Math.round(globalSel.h), "xc:black"];
        for (var i = 0; i < slices.length; i++)
            args = args.concat([slices[i].tmp, "-geometry", "+" + slices[i].ox + "+" + slices[i].oy, "-composite"]);
        args.push(path);
        stitchProc.runWith(args, after);
    }

    function doCopy() {
        var auto = defaultPath;
        grabTo(auto, function (ok) {
            if (ok) copyProc.run(auto);
            else Qt.quit();
        });
    }

    function doSave() {
        var auto = root.defaultPath;
        grabTo(auto, function (ok) {
            if (!ok) { Qt.quit(); return; }
            root.savedAuto = auto;
            root.dialogMode = true;
            saveDialog.open();
        });
    }

    function doUpload() {
        var tmp = "/tmp/ryoshot-upload.png";
        grabTo(tmp, function (ok) {
            if (ok) uploadProc.run(tmp);
            else Qt.quit();
        });
    }

    Process {
        id: saveDialog
        stdout: StdioCollector { id: saveOut }
        function open() {
            command = ["kdialog", "--getsavefilename", root.savedAuto, "*.png"];
            running = true;
        }
        onExited: (code) => {
            var chosen = saveOut.text.trim();
            console.log("ryoshot: kdialog exit " + code + " path=" + JSON.stringify(chosen));
            if (code === 0 && chosen.length > 0) {
                if (chosen !== root.savedAuto) copyFileProc.run(root.savedAuto, chosen);
                else Qt.quit();
            } else {
                root.dialogMode = false;
            }
        }
    }

    Process {
        id: copyFileProc
        function run(src, dst) { command = ["cp", "--", src, dst]; running = true; }
        onExited: () => Qt.quit()
    }

    Process {
        id: copyProc
        function run(file) {
            command = ["sh", "-c",
                "wl-copy --type image/png < \"$1\"; "
                + "if [ \"$(stat -c%s \"$1\")\" -ge 4900000 ]; then magick \"$1\" -quality 92 jpeg:- | cliphist store; "
                + "else cliphist store < \"$1\"; fi",
                "_", file];
            running = true;
        }
        onExited: (code) => { console.log("ryoshot: wl-copy exit " + code); Qt.quit(); }
    }

    Process {
        id: uploadProc
        stdout: StdioCollector { id: uploadOut }
        function run(file) {
            command = ["curl", "-sf", "--max-time", "30", "-A", "Mozilla/5.0", "-F", "reqtype=fileupload",
                "-F", "time=72h", "-F", "fileToUpload=@" + file,
                "https://litterbox.catbox.moe/resources/internals/api.php"];
            running = true;
        }
        onExited: (code) => {
            var url = uploadOut.text.trim();
            console.log("ryoshot: upload exit " + code + " url=" + JSON.stringify(url));
            if (code === 0 && url.indexOf("http") === 0) urlCopyProc.run(url);
            else Qt.quit();
        }
    }

    Process {
        id: urlCopyProc
        function run(url) {
            command = ["sh", "-c", "printf %s " + JSON.stringify(url) + " | wl-copy"];
            running = true;
        }
        onExited: () => Qt.quit()
    }

    Process {
        id: monitorsProc
        running: true
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { id: monitorsOut }
        onExited: { clientsProc.activeWs = root.parseActiveWs(monitorsOut.text); clientsProc.running = true; }
    }

    Process {
        id: clientsProc
        property var activeWs: []
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector { id: clientsOut }
        onExited: root.parseWindows(activeWs, clientsOut.text)
    }

    Process {
        id: stitchProc
        property var cb: null
        function runWith(args, after) { cb = after; command = args; running = true; }
        onExited: (code) => {
            console.log("ryoshot: seam-stitch composite exit " + code);
            var f = cb;
            cb = null;
            if (f) f(code === 0);
        }
    }

    function noteFrozen() {
        frozenCount += 1;
        if (testRect && frozenCount >= Quickshell.screens.length) testDriver.start();
    }

    function toolbarFor(win) {
        if (phase !== "editing" || !globalSel) return { visible: false, x: 0, y: 0 };
        if (anchorOverlay() !== win) return { visible: false, x: 0, y: 0 };
        return { visible: true };
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: !root.dialogMode

            anchors { top: true; left: true; right: true; bottom: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "ryoshot"

            readonly property string scrName: win.modelData.name
            readonly property bool showToolbar: root.toolbarFor(win).visible

            readonly property var selLocal: root.globalSel
                ? Coords.intersectRect(root.globalSel,
                    { x: win.modelData.x, y: win.modelData.y, width: win.width, height: win.height })
                : null

            FocusScope {
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: {
                    if (root.textEditing) root.cancelText();
                    else if (root.settingsOpen) root.settingsOpen = false;
                    else if (root.selectedIndex !== null) root.clearSelection();
                    else Qt.quit();
                }
                Keys.onPressed: (e) => {
                    if (root.textEditing) return;
                    if (e.key === Qt.Key_C && (e.modifiers & Qt.ControlModifier)) { root.doCopy(); e.accepted = true; }
                    else if (e.key === Qt.Key_Z && (e.modifiers & Qt.ControlModifier)) { root.undo(); e.accepted = true; }
                    else if (e.key === Qt.Key_Y && (e.modifiers & Qt.ControlModifier)) { root.redo(); e.accepted = true; }
                    else if ((e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) && root.selectedIndex !== null) { root.deleteSelected(); e.accepted = true; }
                }

                Overlay {
                    id: ov
                    anchors.fill: parent
                    screenData: win.modelData
                    globalSel: root.globalSel
                    capturing: root.capturing
                    model: root.model
                    draft: root.draft
                    annRevision: root.annRevision
                    textEditing: root.textEditing
                    selectedIndex: root.selectedIndex
                    moveOffset: root.moveOffset
                    hoverWindow: root.hoverWindow

                    onPressedAt: (gx, gy) => root.pointerPressed(gx, gy)
                    onMovedTo: (gx, gy) => root.pointerMoved(gx, gy)
                    onHovered: (gx, gy) => root.pointerHover(gx, gy)
                    onReleased: root.pointerReleased()
                    onFrozen: root.noteFrozen()
                    onTextChanged: (t) => { if (root.draft && root.draft.type === "text") { root.draft.text = t; root.bumpAnn(); } }
                    onTextCommitted: root.commitText()
                }

                Toolbar {
                    id: toolbar
                    visible: win.showToolbar && win.selLocal !== null
                    activeTool: root.activeTool
                    activeColor: root.activeColor
                    activeWidth: root.activeWidth
                    canUndo: { root.annRevision; return root.model ? root.model.canUndo() : false; }
                    canRedo: { root.annRevision; return root.model ? root.model.canRedo() : false; }
                    settingsOpen: root.settingsOpen

                    x: {
                        if (!win.selLocal) return 0;
                        var cx = win.selLocal.x + win.selLocal.w / 2 - width / 2;
                        return Math.max(8, Math.min(cx, win.width - width - 8));
                    }
                    y: {
                        if (!win.selLocal) return 0;
                        var below = win.selLocal.y + win.selLocal.h + 12;
                        if (below + height > win.height - 8) below = win.selLocal.y - height - 12;
                        return Math.max(8, below);
                    }

                    onToolPicked: (t) => { if (root.textEditing) root.commitText(); root.clearSelection(); root.activeTool = t; }
                    onColorPicked: (c) => root.activeColor = c
                    onWidthPicked: (w) => root.activeWidth = w
                    onUndoRequested: root.undo()
                    onRedoRequested: root.redo()
                    onCopyRequested: root.doCopy()
                    onSaveRequested: root.doSave()
                    onUploadRequested: root.doUpload()
                    onSettingsRequested: root.settingsOpen = toolbar.settingsOpen
                }

                SettingsPanel {
                    id: hotkeyPopover
                    visible: toolbar.visible && root.settingsOpen
                    luaPath: root.ryoshotLuaPath
                    x: Math.max(8, Math.min(toolbar.x + toolbar.gearCenterX - width / 2,
                                            win.width - width - 8))
                    y: toolbar.y - height - 6
                    onCloseRequested: root.settingsOpen = false
                    onRebound: Qt.quit()
                }
            }

            Component.onCompleted: root.overlays.push(win)

            function grabExport(path, cb) { ov.grabExport(path, cb); }
            function grabToolbar(path, cb) {
                var sched = toolbar.grabToImage(function (r) {
                    var ok = false;
                    try { ok = r ? r.saveToFile(path) : false; } catch (e) { ok = false; }
                    if (cb) cb(ok);
                });
                if (!sched && cb) cb(false);
            }
        }
    }

    Timer {
        id: testDriver
        interval: 400
        repeat: false
        onTriggered: {
            root.globalSel = { x: 2750, y: 350, w: 760, h: 480 };
            root.phase = "editing";
            var bx = 2750, by = 350;
            root.model.add({
                type: "ellipse",
                points: [{ x: bx + 40, y: by + 40 }, { x: bx + 240, y: by + 180 }],
                color: "#4f8fe0", width: 4, filled: false
            });
            root.model.add({
                type: "line",
                points: [{ x: bx + 300, y: by + 60 }, { x: bx + 700, y: by + 200 }],
                color: "#f2c14e", width: 7, filled: false
            });
            root.model.add({
                type: "arrow",
                points: [{ x: bx + 60, y: by + 440 }, { x: bx + 360, y: by + 260 }],
                color: "#e23b3b", width: 5, filled: false
            });
            var pen = [];
            for (var i = 0; i <= 40; i++) {
                var t = i / 40;
                pen.push({ x: bx + 300 + t * 380, y: by + 320 + Math.sin(t * 6.2832) * 60 });
            }
            root.model.add({ type: "pen", points: pen, color: "#5bbf73", width: 3 });
            var mk = [];
            for (var j = 0; j <= 20; j++) {
                var u = j / 20;
                mk.push({ x: bx + 100 + u * 560, y: by + 410 });
            }
            root.model.add({ type: "marker", points: mk, color: "#f2c14e", width: 4 });
            root.model.add({
                type: "blur",
                points: [{ x: bx + 40, y: by + 230 }, { x: bx + 360, y: by + 330 }]
            });
            root.model.add({
                type: "text",
                points: [{ x: bx + 60, y: by + 20 }],
                color: "#ffffff", text: "ryoshot p3b", size: 28
            });
            root.bumpAnn();
            grabTimer.start();
        }
    }

    Timer {
        id: grabTimer
        interval: 250
        repeat: false
        onTriggered: {
            root.grabTo("/tmp/ryoshot-p3b.png", function (ok) {
                console.log("ryoshot-test: annotated grab ok=" + ok);
                var w = root.anchorOverlay();
                if (w) w.grabToolbar("/tmp/ryoshot-toolbar.png", function (tok) {
                    console.log("ryoshot-test: toolbar grab ok=" + tok);
                });
            });
        }
    }
}
