pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Ryoku.Blobs
import shell.services
import "../../components"

// Draggable, shaped webcam bubble on a per-screen layer surface: it stays put
// across workspace switches and gsr captures it into recordings. The live feed
// is the native CameraFeed (a scene-graph texture, so it can be masked), shaped
// by a MultiEffect mask from square corners to a full circle. Interactive, so
// the input mask covers only the bubble and the rest of the screen stays
// click-through.
PanelWindow {
    id: win

    required property var modelData

    // this screen's Hyprland monitor, for global<->screen-local mapping (logical).
    readonly property var mon: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === (modelData ? modelData.name : ""))
                return mons[i];
        return null;
    }
    readonly property real monX: mon ? mon.x : 0
    readonly property real monY: mon ? mon.y : 0
    readonly property real monScale: mon && mon.scale > 0 ? mon.scale : 1
    readonly property real screenW: mon ? mon.width / win.monScale : (modelData ? modelData.width : 0)
    readonly property real screenH: mon ? mon.height / win.monScale : (modelData ? modelData.height : 0)

    // bubble size: free-form width/height, dragged via the resize grip; capped
    // so it can never fill the monitor (also clamps a size persisted from a
    // larger screen).
    readonly property real maxEdge: Math.min(win.screenW, win.screenH) * 0.6
    readonly property real bw: Math.max(Camera.minEdge, Math.min(Camera.bw, win.maxEdge))
    readonly property real bh: Math.max(Camera.minEdge, Math.min(Camera.bh, win.maxEdge))

    // global logical position; default to the bottom-right corner when unplaced.
    readonly property real defX: win.monX + win.screenW - bw - 40
    readonly property real defY: win.monY + win.screenH - bh - 40
    readonly property real gx: isNaN(Camera.px) ? defX : Camera.px
    readonly property real gy: isNaN(Camera.py) ? defY : Camera.py
    // screen-local, clamped inside this screen.
    readonly property real bx: Math.max(0, Math.min(win.screenW - bw, gx - win.monX))
    readonly property real by: Math.max(0, Math.min(win.screenH - bh, gy - win.monY))
    // the bubble lives on whichever monitor its centre falls in.
    readonly property real cxLocal: gx + bw / 2 - win.monX
    readonly property real cyLocal: gy + bh / 2 - win.monY
    readonly property bool onScreen: cxLocal >= 0 && cxLocal < win.screenW && cyLocal >= 0 && cyLocal < win.screenH

    screen: modelData
    visible: Camera.active && win.onScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-camera"

    anchors { top: true; bottom: true; left: true; right: true }

    // input only on the bubble; the rest of the screen passes clicks through.
    mask: Region { item: bubble }

    Item {
        id: bubble

        x: win.bx
        y: win.by
        width: win.bw
        height: win.bh

        readonly property real rad: Camera.roundness * Math.min(width, height) / 2
        property string dragMode: "" // "" | move | resize | round -- from the drag below

        // rounded backdrop + cue, shown until the first camera frame arrives (the
        // feed is transparent while the camera warms up).
        Rectangle {
            anchors.fill: parent
            radius: bubble.rad
            color: Theme.frameBg
        }
        GlyphIcon {
            anchors.centerIn: parent
            width: 28
            height: 28
            name: "webcam"
            color: Theme.onSurfaceVariant
            stroke: 1.7
        }

        // live feed, rendered as a scene-graph texture so the mask applies.
        CameraFeed {
            anchors.fill: parent
            active: Camera.active
            mirror: Camera.flipped
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: maskRect
            }
        }
        Rectangle {
            id: maskRect
            anchors.fill: parent
            radius: bubble.rad
            visible: false
            layer.enabled: true
        }

        // rim tracing the same shape.
        Rectangle {
            anchors.fill: parent
            radius: bubble.rad
            color: "transparent"
            border.width: 2
            border.color: Theme.primary
        }

        // Figma-style edit handles (roundness dot, resize grip, flip): pure
        // visuals; the single DragHandler below moves / resizes / rounds by press
        // zone. Revealed on hover, hidden while recording (never in the shot).
        CameraHandles {
            anchors.fill: parent
            mode: bubble.dragMode
            opacity: (bubbleHov.hovered && !Recorder.anyActive) ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }

        HoverHandler {
            id: bubbleHov
            cursorShape: Qt.SizeAllCursor
        }

        // one drag, three modes chosen by press zone: the bottom-right corner
        // resizes (free-form w/h), the top-left dot sets roundness, anywhere else
        // moves. a single handler avoids nested-drag grab fights, and the move
        // write survives workspace switches (every per-screen overlay tracks it).
        DragHandler {
            id: drag
            target: null
            dragThreshold: 6
            property real ox: 0 // value at press: gx (move) or bw (resize)
            property real oy: 0 // value at press: gy (move) or bh (resize)
            property real ax: 0 // scene x at press
            property real ay: 0 // scene y at press
            onActiveChanged: {
                if (!drag.active) {
                    bubble.dragMode = "";
                    return;
                }
                const cx = drag.centroid.pressPosition.x;
                const cy = drag.centroid.pressPosition.y;
                const w = bubble.width;
                const h = bubble.height;
                if (Recorder.anyActive)
                    bubble.dragMode = "move"; // no shape edits mid-recording
                else if (cx > w - 30 && cy > h - 30)
                    bubble.dragMode = "resize";
                else if (Math.hypot(cx - bubble.rad, cy - bubble.rad) < 20)
                    bubble.dragMode = "round";
                else
                    bubble.dragMode = "move";
                drag.ax = drag.centroid.scenePosition.x;
                drag.ay = drag.centroid.scenePosition.y;
                drag.ox = bubble.dragMode === "resize" ? win.bw : win.gx;
                drag.oy = bubble.dragMode === "resize" ? win.bh : win.gy;
            }
            onCentroidChanged: {
                if (!drag.active)
                    return;
                const dx = drag.centroid.scenePosition.x - drag.ax;
                const dy = drag.centroid.scenePosition.y - drag.ay;
                if (bubble.dragMode === "resize") {
                    Camera.bw = Math.max(Camera.minEdge, Math.min(win.maxEdge, drag.ox + dx));
                    Camera.bh = Math.max(Camera.minEdge, Math.min(win.maxEdge, drag.oy + dy));
                } else if (bubble.dragMode === "round") {
                    const mr = Math.min(bubble.width, bubble.height) / 2;
                    const d = Math.max(0, Math.min(mr, (drag.centroid.position.x + drag.centroid.position.y) / 2));
                    Camera.roundness = mr > 0 ? d / mr : 0;
                } else {
                    Camera.px = Math.max(win.monX, Math.min(win.monX + win.screenW - win.bw, drag.ox + dx));
                    Camera.py = Math.max(win.monY, Math.min(win.monY + win.screenH - win.bh, drag.oy + dy));
                }
            }
        }
    }
}
