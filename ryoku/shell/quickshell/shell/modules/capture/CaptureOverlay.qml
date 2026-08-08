pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import shell.services

// One fullscreen selection overlay per output (contract 09 sec 1b/4a), raised on
// the Overlay layer with no exclusive zone so it floats over the bars and app
// windows and reserves nothing. It dims the output and lets the user pick a
// capture target for the frame's screenshot menu:
//
//   region  a single click-drag-release rubber band, each axis clamped to this
//           output, committing only when both width and height exceed 5px and
//           cancelled by Escape. Deliberately NO resize handles and NO snapping
//           (contract 09 confirms their absence); a too-small release just
//           resets and the overlay stays open to try again.
//   monitor click anywhere on an output to pick that whole output.
//   window  hit-test the hovered toplevel and pick its global rect.
//
// One overlay is mapped per output while Capture.selecting is set; a commit or
// Escape on any one clears Capture.selecting, which tears every sibling down at
// once. The clear cutout is drawn as four dim bands framing the selection, so
// the selected pixels carry no overlay tint and show the live screen through the
// transparent surface.
PanelWindow {
    id: win

    required property var modelData

    readonly property string sel: Capture.selecting

    // This output's Hyprland monitor gives the logical layout origin (the space
    // grim -g and Recorder expect) and, as a fallback before the surface maps,
    // the logical size. Never gate `visible` on width/height: they are 0 until
    // the surface maps, which would deadlock (never sized -> never visible).
    readonly property var mon: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === (win.modelData ? win.modelData.name : ""))
                return mons[i];
        return null;
    }
    readonly property real monX: win.mon ? win.mon.x : 0
    readonly property real monY: win.mon ? win.mon.y : 0
    readonly property real monScale: win.mon && win.mon.scale > 0 ? win.mon.scale : 1
    readonly property real scrW: win.width > 0 ? win.width : (win.mon ? win.mon.width / win.monScale : 0)
    readonly property real scrH: win.height > 0 ? win.height : (win.mon ? win.mon.height / win.monScale : 0)

    screen: modelData
    visible: win.sel !== ""
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "ryoku-capture"

    anchors { top: true; bottom: true; left: true; right: true }

    // --- region drag (output-local logical px, clamped to this output) --------
    property bool dragging: false
    property real sx: 0
    property real sy: 0
    property real cx: 0
    property real cy: 0
    readonly property real rx: Math.min(win.sx, win.cx)
    readonly property real ry: Math.min(win.sy, win.cy)
    readonly property real rw: Math.abs(win.cx - win.sx)
    readonly property real rh: Math.abs(win.cy - win.sy)

    property bool hovering: false

    function clampX(x) { return Math.max(0, Math.min(win.scrW, x)); }
    function clampY(y) { return Math.max(0, Math.min(win.scrH, y)); }

    // A fresh open (or a family teardown) must never inherit a stale drag/hover.
    onSelChanged: {
        win.dragging = false;
        win.hovering = false;
        win.hoverWin = -1;
    }

    // --- window selector: this output's toplevels, snapshotted while open -----
    // Global logical rects from Hyprland, filtered to mapped, unhidden, sized
    // windows that intersect this output, converted to output-local for drawing
    // and hit-testing. Snapshotted reactively; overlays are transient so the
    // next invocation re-queries (hotplug mid-selection is out of scope).
    readonly property var wins: {
        if (win.sel !== "window")
            return [];
        var out = [];
        var tl = Hyprland.toplevels.values;
        for (var i = 0; i < tl.length; i++) {
            var o = tl[i] && tl[i].lastIpcObject;
            if (!o || o.mapped === false || o.hidden === true)
                continue;
            if (!o.at || !o.size || o.size[0] <= 0 || o.size[1] <= 0)
                continue;
            var lx = o.at[0] - win.monX;
            var ly = o.at[1] - win.monY;
            if (lx + o.size[0] <= 0 || ly + o.size[1] <= 0 || lx >= win.scrW || ly >= win.scrH)
                continue;
            out.push({ x: lx, y: ly, w: o.size[0], h: o.size[1] });
        }
        return out;
    }
    property int hoverWin: -1
    function hitTest(x, y) {
        // Reverse order: the front-most window under the pointer wins.
        for (var i = win.wins.length - 1; i >= 0; i--) {
            var r = win.wins[i];
            if (x >= r.x && x < r.x + r.w && y >= r.y && y < r.y + r.h)
                return i;
        }
        return -1;
    }

    // The highlighted rect (output-local) driving the cutout + border.
    readonly property bool hasRect: win.sel === "region" ? (win.dragging && win.rw > 1 && win.rh > 1)
        : win.sel === "window" ? (win.hoverWin >= 0)
        : false
    readonly property real hlx: (win.sel === "window" && win.hoverWin >= 0) ? win.wins[win.hoverWin].x : win.rx
    readonly property real hly: (win.sel === "window" && win.hoverWin >= 0) ? win.wins[win.hoverWin].y : win.ry
    readonly property real hlw: (win.sel === "window" && win.hoverWin >= 0) ? win.wins[win.hoverWin].w : win.rw
    readonly property real hlh: (win.sel === "window" && win.hoverWin >= 0) ? win.wins[win.hoverWin].h : win.rh

    readonly property color dimC: Qt.rgba(0, 0, 0, 0.45)
    readonly property color liteC: Qt.rgba(0, 0, 0, 0.05)

    // --- scrim ----------------------------------------------------------------
    // Monitor: the whole output dims light while this overlay is hovered, dark
    // otherwise. Region/window before a selection: a plain full-cover scrim.
    Rectangle {
        anchors.fill: parent
        visible: win.sel === "monitor" || !win.hasRect
        color: win.sel === "monitor" ? (win.hovering ? win.liteC : win.dimC) : win.dimC
    }
    // Region/window with a selection: four dim bands frame the clear cutout.
    Item {
        anchors.fill: parent
        visible: win.hasRect
        Rectangle { color: win.dimC; x: 0; y: 0; width: win.scrW; height: Math.max(0, win.hly) }
        Rectangle { color: win.dimC; x: 0; y: win.hly + win.hlh; width: win.scrW; height: Math.max(0, win.scrH - (win.hly + win.hlh)) }
        Rectangle { color: win.dimC; x: 0; y: win.hly; width: Math.max(0, win.hlx); height: win.hlh }
        Rectangle { color: win.dimC; x: win.hlx + win.hlw; y: win.hly; width: Math.max(0, win.scrW - (win.hlx + win.hlw)); height: win.hlh }
    }

    // Selection / hover outline: 2px for region, 3px for monitor/window.
    Rectangle {
        visible: win.hasRect || (win.sel === "monitor" && win.hovering)
        color: "transparent"
        border.width: win.sel === "region" ? 2 : 3
        border.color: Theme.outline
        x: win.sel === "monitor" ? 1.5 : win.hlx
        y: win.sel === "monitor" ? 1.5 : win.hly
        width: win.sel === "monitor" ? win.scrW - 3 : win.hlw
        height: win.sel === "monitor" ? win.scrH - 3 : win.hlh
    }

    // Region dimension readout "W×H" (U+00D7), centred under the selection.
    Text {
        visible: win.sel === "region" && win.hasRect
        text: Math.round(win.hlw) + "\u00d7" + Math.round(win.hlh)
        color: Theme.outline
        font.family: Theme.fontPrimary
        font.pixelSize: Theme.fontSm
        x: win.hlx + (win.hlw - width) / 2
        y: win.hly + win.hlh + 20
    }

    // --- input ----------------------------------------------------------------
    MouseArea {
        anchors.fill: parent
        enabled: win.sel !== ""
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: win.sel === "region" ? Qt.CrossCursor : Qt.PointingHandCursor

        onEntered: win.hovering = true
        onExited: {
            win.hovering = false;
            if (win.sel === "window")
                win.hoverWin = -1;
        }
        onPositionChanged: mouse => {
            win.hovering = true;
            if (win.sel === "window")
                win.hoverWin = win.hitTest(mouse.x, mouse.y);
            else if (win.sel === "region" && win.dragging) {
                win.cx = win.clampX(mouse.x);
                win.cy = win.clampY(mouse.y);
            }
        }
        onPressed: mouse => {
            if (win.sel === "region") {
                win.sx = win.cx = win.clampX(mouse.x);
                win.sy = win.cy = win.clampY(mouse.y);
                win.dragging = true;
            }
        }
        onReleased: mouse => {
            if (win.sel === "region") {
                if (!win.dragging)
                    return;
                win.dragging = false;
                if (win.rw > 5 && win.rh > 5)
                    Capture.commit({ mode: "region", output: win.modelData.name, monX: win.monX, monY: win.monY, x: win.rx, y: win.ry, w: win.rw, h: win.rh });
                // else too small: reset above, stay open to try again.
            } else if (win.sel === "monitor") {
                Capture.commit({ mode: "monitor", output: win.modelData.name, monX: win.monX, monY: win.monY, x: 0, y: 0, w: win.scrW, h: win.scrH });
            } else if (win.sel === "window") {
                var i = win.hitTest(mouse.x, mouse.y);
                if (i >= 0) {
                    var r = win.wins[i];
                    Capture.commit({ mode: "window", output: win.modelData.name, monX: win.monX, monY: win.monY, x: r.x, y: r.y, w: r.w, h: r.h });
                }
            }
        }
    }

    // Escape cancels the whole family. Keyboard mode is OnDemand (contract 09),
    // so focus is opportunistic; the press that starts a drag grants it.
    Item {
        anchors.fill: parent
        focus: win.sel !== ""
        Keys.onEscapePressed: Capture.cancel()
    }
}
