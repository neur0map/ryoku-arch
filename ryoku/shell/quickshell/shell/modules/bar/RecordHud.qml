pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services
import "../../components"

// Draggable recording control that lives just inside the frame. At rest it is a
// crisp card fused near a frame edge -- the frame's own surface + 2px outline,
// matching FrameChrome and the frame-edge cards (music / bluetooth) rather than
// the old liquid blob. Grab it to pull it into a floating island; let go and it
// drifts to the nearest edge and docks. On a side edge it turns vertical while
// held. Hide slides it off to a pulsing nub that hovering the edge pops back out.
// It melts (slides + fades) into the frame when recording ends, leaving no mark.
Item {
    id: hud

    property real s: 1
    property real radius: Theme.radiusWindow
    // the frame reserve (bar band + border) per edge, so the card docks just
    // inside the frame on whichever edge it lands, clearing any bar there.
    property real clearanceTop: 0
    property real clearanceBottom: 0
    property real clearanceLeft: 0
    property real clearanceRight: 0

    readonly property int moveDur: 560
    readonly property int meltDur: 620
    readonly property int mergeDur: 1700

    anchors.fill: parent

    // the card floats a small gap off the frame reserve, like the other frame-edge
    // cards (FrameSurface edgeGap), so it never clips the border or a bar.
    readonly property real edgeGap: 10 * hud.s
    function lipFor(e) {
        var c = e === "top" ? hud.clearanceTop : e === "bottom" ? hud.clearanceBottom
            : e === "left" ? hud.clearanceLeft : hud.clearanceRight;
        return c + hud.edgeGap;
    }
    readonly property real lipT: hud.lipFor("top")
    readonly property real lipB: hud.lipFor("bottom")
    readonly property real lipL: hud.lipFor("left")
    readonly property real lipR: hud.lipFor("right")

    property string dockEdge: "bottom"
    property real alongPx: 0
    property bool placed: false
    readonly property bool dragging: dragH.active
    property bool hidden: false

    onWidthChanged: hud.reposition()
    onHeightChanged: hud.reposition()
    function reposition() {
        if (hud.placed || hud.width <= 0)
            return;
        hud.alongPx = (hud.width - hud.bodyW) / 2;
        hud.px = hud.dockX;
        hud.py = hud.dockY;
        hud.placed = true;
    }

    // --- reveal + melt: 0 tucked behind the edge, 1 fully out, a small nub cue
    // when hidden.
    property bool revealHeld: false
    readonly property bool revealed: bodyHov.hovered || edgeHov.hovered
    // tucked = hidden and not currently being revealed by a hover.
    readonly property bool tucked: hud.hidden && !hud.revealHeld
    onRevealedChanged: {
        if (hud.revealed) { revealGrace.stop(); hud.revealHeld = true; }
        else revealGrace.restart();
    }
    Timer { id: revealGrace; interval: 260; onTriggered: hud.revealHeld = false }

    readonly property real nubProg: 0.1
    readonly property real wantProg: {
        if (Recorder.anyActive) return (!hud.hidden || hud.revealHeld) ? 1 : hud.nubProg;
        return (Recorder.chooserOpen || hud.starting) ? 1 : 0;
    }
    property real prog: hud.wantProg
    Behavior on prog { NumberAnimation { duration: hud.meltDur; easing.type: Easing.InOutCubic } }
    readonly property bool live: hud.prog > 0.002
    visible: hud.live

    // Chooser state: the Super+S capture card opens this island before recording.
    // Quick records via gsr; Studio and Edit hand off to ryomotion. `starting`
    // holds the island up through the short beat between closing the chooser and
    // gsr coming up, so it never blinks out.
    property bool starting: false
    function startQuick() {
        Recorder.chooserOpen = false;
        if (Recorder.regionGeom !== "") {
            Recorder.start(["--region", "--geometry", Recorder.regionGeom].concat(Recorder.recordArgs()));
        } else {
            hud.starting = true;
            quickTimer.restart();
        }
    }
    Timer { id: quickTimer; interval: 420; onTriggered: { Recorder.start(Recorder.recordArgs()); hud.starting = false; } }
    // Edit opens ryomotion straight to its import screen (--edit) so you pick a
    // clip to edit; notify-send keeps a click from silently doing nothing before
    // the app is installed.
    function launchRyomotion() {
        Recorder.chooserOpen = false;
        Quickshell.execDetached(["sh", "-c",
            "command -v ryomotion >/dev/null 2>&1 && exec ryomotion --edit || notify-send 'Ryomotion' 'Not installed yet'"]);
    }
    // studio: our island is the toolbar, so ryomotion records headless (its HUD
    // hidden) with the chooser's options and we drive the stop from the control bar.
    function startStudio() {
        Recorder.chooserOpen = false;
        Recorder.pendingDiscord = false;
        Recorder.startStudio(Recorder.optDesktopAudio, Recorder.optMic, Recorder.regionGeom);
    }

    // labelled action tile for the chooser (icon + short caption).
    component Action: Rectangle {
        id: act
        property real s: 1
        property string glyph: ""
        property string label: ""
        property color tint: Theme.onSurface
        property bool primary: false
        signal tapped()
        implicitWidth: aRow.implicitWidth + 14 * act.s
        implicitHeight: 26 * act.s
        radius: 7 * act.s
        color: aHov.hovered ? Theme.frameBg
            : act.primary ? Qt.rgba(Theme.vermLit.r, Theme.vermLit.g, Theme.vermLit.b, 0.16) : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Row {
            id: aRow
            anchors.centerIn: parent
            spacing: 5 * act.s
            GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 14 * act.s
                height: 14 * act.s
                name: act.glyph
                color: act.tint
                stroke: 1.7
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: act.label
                color: act.tint
                font.family: Theme.mono
                font.pixelSize: 9.5 * act.s
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8 * act.s
            }
        }
        HoverHandler { id: aHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: act.tapped() }
    }

    // --- orientation: vertical while a side edge is nearest and within range,
    // so it reorients while held. content fades out, the layout flips at the
    // bottom of the dip (the reflow is never seen), then fades back in.
    readonly property real orientThreshold: 220 * hud.s
    // orientation comes from the dock when docked, or the drag anchor px against
    // a fixed reference width while dragging, never the live bodyW. reading the
    // morphing body here fed the layout flip back into the decision and made it
    // oscillate at the threshold, which is the binding loop and the corner glitch.
    readonly property real orientRefW: 210 * hud.s
    readonly property real orientGap: hud.nearEdge === "left" ? (hud.px - hud.lipL)
        : (hud.width - hud.lipR) - (hud.px + hud.orientRefW)
    readonly property bool vertical: hud.dragging
        ? ((hud.nearEdge === "left" || hud.nearEdge === "right") && hud.orientGap < hud.orientThreshold)
        : (hud.dockEdge === "left" || hud.dockEdge === "right")
    property bool layoutVertical: false
    // the fade chases 1 once the layout matches the orientation, 0 while it still
    // has to flip; the flip happens at the bottom of the dip. because the target
    // snaps back to 1 the instant they match, the fade can't starve at 0 however
    // fast the orientation flips around a corner, so the island is never left
    // blank and stuck.
    property real reorientFade: 1
    Behavior on reorientFade { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }
    onVerticalChanged: hud.reorientFade = (hud.layoutVertical === hud.vertical) ? 1 : 0
    onReorientFadeChanged: {
        if (hud.reorientFade <= 0.02 && hud.layoutVertical !== hud.vertical) {
            hud.layoutVertical = hud.vertical;
            hud.reorientFade = 1;
        }
    }
    Component.onCompleted: hud.layoutVertical = hud.vertical

    readonly property real curW: (Recorder.anyActive || hud.starting) ? grid.implicitWidth : chooserGrid.implicitWidth
    readonly property real curH: (Recorder.anyActive || hud.starting) ? grid.implicitHeight : chooserGrid.implicitHeight
    property real bodyW: hud.curW + 20 * hud.s
    property real bodyH: hud.curH + 14 * hud.s
    Behavior on bodyW { NumberAnimation { duration: hud.moveDur; easing.type: Easing.InOutCubic } }
    Behavior on bodyH { NumberAnimation { duration: hud.moveDur; easing.type: Easing.InOutCubic } }

    readonly property real dockX: hud.dockEdge === "left" ? hud.lipL
        : hud.dockEdge === "right" ? (hud.width - hud.lipR - hud.bodyW)
        : Math.max(hud.lipL, Math.min(hud.width - hud.lipR - hud.bodyW, hud.alongPx))
    readonly property real dockY: hud.dockEdge === "top" ? hud.lipT
        : hud.dockEdge === "bottom" ? (hud.height - hud.lipB - hud.bodyH)
        : Math.max(hud.lipT, Math.min(hud.height - hud.lipB - hud.bodyH, hud.alongPx))
    property real px: 0
    property real py: 0
    Behavior on px { enabled: !hud.dragging; NumberAnimation { duration: hud.mergeDur; easing.type: Easing.InOutCubic } }
    Behavior on py { enabled: !hud.dragging; NumberAnimation { duration: hud.mergeDur; easing.type: Easing.InOutCubic } }
    // idle/docked, px,py track the dock and animate to it; a drag frees them.
    // this is the fail-safe: the moment the pointer lifts, dragging goes false
    // and the island is pulled back onto its edge, wherever it was let go.
    Binding { target: hud; property: "px"; value: hud.dockX; when: !hud.dragging; restoreMode: Binding.RestoreNone }
    Binding { target: hud; property: "py"; value: hud.dockY; when: !hud.dragging; restoreMode: Binding.RestoreNone }
    onPxChanged: hud.settleEdge()
    onPyChanged: hud.settleEdge()

    // input-mask rects: the body while it's out, the edge strip so a hidden nub
    // can be hovered back out. shell.qml unions both.
    readonly property real hudX: hud.px
    readonly property real hudY: hud.py
    readonly property real hudW: hud.bodyW
    readonly property real hudH: hud.bodyH
    // while tucked the reveal zone grows: deeper into the screen and wider along
    // the edge, so flicking the cursor to that edge reliably pops the nub back
    // out instead of needing to land on the small nub exactly.
    readonly property real trigReach: hud.tucked ? 46 * hud.s : 18 * hud.s
    readonly property real trigPad: hud.tucked ? 44 * hud.s : 0
    readonly property real trigDepth: hud.lipFor(hud.dockEdge) + hud.trigReach
    readonly property real trigX: hud.dockEdge === "right" ? (hud.width - hud.trigDepth)
        : hud.dockEdge === "left" ? 0 : (hud.dockX - hud.trigPad)
    readonly property real trigY: hud.dockEdge === "bottom" ? (hud.height - hud.trigDepth)
        : hud.dockEdge === "top" ? 0 : (hud.dockY - hud.trigPad)
    readonly property real trigW: (hud.dockEdge === "left" || hud.dockEdge === "right") ? hud.trigDepth : (hud.bodyW + 2 * hud.trigPad)
    readonly property real trigH: (hud.dockEdge === "top" || hud.dockEdge === "bottom") ? hud.trigDepth : (hud.bodyH + 2 * hud.trigPad)

    // nearest edge = where the island docks on release; the gap to each lip also
    // feeds the orientation flip. (No more liquid merge-reach: the card is crisp.)
    readonly property real gapT: hud.py - hud.lipT
    readonly property real gapB: (hud.height - hud.lipB) - (hud.py + hud.bodyH)
    readonly property real gapL: hud.px - hud.lipL
    readonly property real gapR: (hud.width - hud.lipR) - (hud.px + hud.bodyW)
    function gapOf(e) { return e === "top" ? hud.gapT : e === "bottom" ? hud.gapB : e === "left" ? hud.gapL : hud.gapR; }
    readonly property string rawNearEdge: {
        var m = Math.min(hud.gapT, hud.gapB, hud.gapL, hud.gapR);
        return m === hud.gapT ? "top" : m === hud.gapB ? "bottom" : m === hud.gapL ? "left" : "right";
    }
    property string nearEdge: "bottom"
    // hysteresis: keep the current edge until another is clearly closer, so a
    // drag along a diagonal or through the centre doesn't flip-flop.
    function settleEdge() {
        if (hud.rawNearEdge === hud.nearEdge)
            return;
        if (hud.gapOf(hud.rawNearEdge) < hud.gapOf(hud.nearEdge) - 30 * hud.s)
            hud.nearEdge = hud.rawNearEdge;
    }

    // crisp reveal: the card slides in from its docked edge and fades. at prog 0
    // it is tucked fully behind that edge (off-screen); at prog 1 it rests at
    // (px, py). the nub state (hidden mid-record) leaves it mostly tucked with
    // the pulsing dot below as the "tucked here" cue.
    readonly property real revealX: hud.dockEdge === "left" ? -(1 - hud.prog) * (hud.bodyW + hud.lipL)
        : hud.dockEdge === "right" ? (1 - hud.prog) * (hud.bodyW + hud.lipR) : 0
    readonly property real revealY: hud.dockEdge === "top" ? -(1 - hud.prog) * (hud.bodyH + hud.lipT)
        : hud.dockEdge === "bottom" ? (1 - hud.prog) * (hud.bodyH + hud.lipB) : 0
    readonly property real cardOpacity: Math.max(0, Math.min(1, (hud.prog - 0.04) / 0.5))

    // the crisp card: the frame's surface, a 2px outline and rounded corners,
    // matching FrameChrome and the frame-edge cards. clips its content so the
    // slide-in reveals it edge-first.
    Rectangle {
        id: card
        x: hud.px + hud.revealX
        y: hud.py + hud.revealY
        width: hud.bodyW
        height: hud.bodyH
        radius: hud.radius
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.outline
        opacity: hud.cardOpacity
        clip: true

        // hover keeps the card revealed (nub un-tuck grace).
        HoverHandler { id: bodyHov; cursorShape: Qt.SizeAllCursor }
        // the whole card is the drag surface, not the reflowing 6-dot grip: when
        // it turns vertical the grip moves under the pointer, and a handler riding
        // it would lose the grab mid-drag and hang the island floating. buttons
        // keep their taps since a drag has to clear the threshold first.
        DragHandler {
            id: dragH
            target: null
            dragThreshold: 8
            enabled: Recorder.anyActive || Recorder.chooserOpen
            cursorShape: Qt.SizeAllCursor
            property real sx: 0
            property real sy: 0
            property real ax: 0
            property real ay: 0
            onActiveChanged: {
                if (dragH.active) {
                    dragH.sx = hud.px;
                    dragH.sy = hud.py;
                    dragH.ax = dragH.centroid.scenePosition.x;
                    dragH.ay = dragH.centroid.scenePosition.y;
                } else {
                    // dock to the edge nearest at the instant of release, read
                    // fresh so a let-go at a corner or dead centre always resolves.
                    var e = hud.rawNearEdge;
                    hud.nearEdge = e;
                    hud.alongPx = (e === "top" || e === "bottom") ? hud.px : hud.py;
                    hud.dockEdge = e;
                }
            }
            onCentroidChanged: {
                if (!dragH.active)
                    return;
                hud.px = Math.max(hud.lipL, Math.min(hud.width - hud.lipR - hud.bodyW, dragH.sx + (dragH.centroid.scenePosition.x - dragH.ax)));
                hud.py = Math.max(hud.lipT, Math.min(hud.height - hud.lipB - hud.bodyH, dragH.sy + (dragH.centroid.scenePosition.y - dragH.ay)));
            }
        }

        // content: fades out and back across the orientation flip.
        Item {
            anchors.fill: parent
            opacity: hud.reorientFade

            Grid {
                id: grid
                visible: Recorder.anyActive || hud.starting
                anchors.centerIn: parent
                columns: hud.layoutVertical ? 1 : 99
                rowSpacing: 7 * hud.s
                columnSpacing: 8 * hud.s
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                Item {
                    width: 16 * hud.s
                    height: 20 * hud.s
                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        rowSpacing: 3 * hud.s
                        columnSpacing: 3 * hud.s
                        Repeater {
                            model: 6
                            Rectangle {
                                width: 3 * hud.s
                                height: 3 * hud.s
                                radius: width / 2
                                color: gripHov.hovered ? Theme.onSurface : Theme.onSurfaceVariant
                            }
                        }
                    }
                    HoverHandler { id: gripHov; cursorShape: Qt.SizeAllCursor }
                }

                Rectangle {
                    width: 9 * hud.s
                    height: 9 * hud.s
                    radius: width / 2
                    color: Recorder.paused ? Theme.onSurfaceVariant : Theme.vermLit
                    opacity: Recorder.paused ? 1 : Recorder.pulse
                }

                Text {
                    text: Recorder.elapsedText
                    color: Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: 13 * hud.s
                    font.features: { "tnum": 1 }
                }

                RecordButton {
                    visible: Recorder.canPause
                    s: hud.s
                    glyph: Recorder.paused ? "play" : "pause"
                    tint: Theme.onSurface
                    onTapped: Recorder.togglePause()
                }
                RecordButton {
                    s: hud.s
                    glyph: "stop"
                    tint: Theme.vermLit
                    onTapped: Recorder.studioActive ? Recorder.stopStudio() : Recorder.stop()
                }
                RecordButton {
                    s: hud.s
                    glyph: hud.sinkMuted ? "speaker-off" : "speaker"
                    tint: hud.sinkMuted ? Theme.onSurfaceVariant : Theme.onSurface
                    onTapped: hud.toggleSink()
                }
                RecordButton {
                    s: hud.s
                    glyph: hud.micMuted ? "mic-off" : "mic"
                    tint: hud.micMuted ? Theme.onSurfaceVariant : Theme.onSurface
                    onTapped: hud.toggleMic()
                }
                RecordButton {
                    s: hud.s
                    glyph: "compress"
                    tint: Theme.onSurfaceVariant
                    onTapped: hud.hidden = !hud.hidden
                }
            }

            // pre-record chooser: capture toggles, then Quick (gsr) / Studio / Edit
            // (both open ryomotion). Same icon-tile idiom and orientation flip as the
            // live control bar, so it reads as one island in two states.
            Grid {
                id: chooserGrid
                anchors.centerIn: parent
                visible: Recorder.chooserOpen && !Recorder.anyActive && !hud.starting
                columns: hud.layoutVertical ? 1 : 99
                rowSpacing: 7 * hud.s
                columnSpacing: 6 * hud.s
                horizontalItemAlignment: Grid.AlignHCenter
                verticalItemAlignment: Grid.AlignVCenter

                RecordButton { s: hud.s; glyph: Recorder.regionGeom !== "" ? "region" : "monitor"; tint: Recorder.regionGeom !== "" ? Theme.onSurface : Theme.onSurfaceVariant; onTapped: { if (Recorder.regionGeom !== "") Recorder.regionGeom = ""; else Recorder.pickRegion(); } }
                RecordButton { s: hud.s; glyph: Recorder.optDesktopAudio ? "speaker" : "speaker-off"; tint: Recorder.optDesktopAudio ? Theme.onSurface : Theme.onSurfaceVariant; onTapped: Recorder.optDesktopAudio = !Recorder.optDesktopAudio }
                RecordButton { s: hud.s; glyph: Recorder.optMic ? "mic" : "mic-off"; tint: Recorder.optMic ? Theme.onSurface : Theme.onSurfaceVariant; onTapped: Recorder.optMic = !Recorder.optMic }
                RecordButton { s: hud.s; glyph: "webcam"; tint: Camera.active ? Theme.onSurface : Theme.onSurfaceVariant; onTapped: Camera.toggle() }

                Rectangle {
                    width: (hud.layoutVertical ? 18 : 1) * hud.s
                    height: (hud.layoutVertical ? 1 : 18) * hud.s
                    radius: 0.5 * hud.s
                    color: Theme.onSurfaceVariant
                    opacity: 0.35
                }

                Action { s: hud.s; glyph: "record"; label: "Quick"; tint: Theme.vermLit; primary: true; onTapped: hud.startQuick() }
                Action { s: hud.s; glyph: "film"; label: "Studio"; onTapped: hud.startStudio() }
                Action { s: hud.s; glyph: "folder"; label: "Edit"; onTapped: hud.launchRyomotion() }

                RecordButton { s: hud.s; glyph: "close"; tint: Theme.onSurfaceVariant; onTapped: Recorder.chooserOpen = false }
            }
        }
    }

    // edge strip: hovering here pops a hidden nub back out.
    Item {
        x: hud.trigX
        y: hud.trigY
        width: hud.trigW
        height: hud.trigH
        HoverHandler { id: edgeHov }
    }

    // tucked cue: a record dot pulses at the docked edge so a hidden island still
    // reads as "recording, tucked here" rather than gone. it fades out as the card
    // reveals.
    Rectangle {
        readonly property real dot: 8 * hud.s
        width: dot
        height: dot
        radius: dot / 2
        x: hud.dockEdge === "left" ? (hud.lipL + dot * 0.5)
            : hud.dockEdge === "right" ? (hud.width - hud.lipR - dot * 1.5)
            : (hud.px + hud.bodyW / 2 - dot / 2)
        y: hud.dockEdge === "top" ? (hud.lipT + dot * 0.5)
            : hud.dockEdge === "bottom" ? (hud.height - hud.lipB - dot * 1.5)
            : (hud.py + hud.bodyH / 2 - dot / 2)
        color: Recorder.paused ? Theme.onSurfaceVariant : Theme.vermLit
        opacity: Recorder.anyActive ? Math.max(0, 1 - hud.prog / 0.4) * (Recorder.paused ? 0.9 : Recorder.pulse) : 0
        visible: opacity > 0.01
    }

    // audio mute through the shared Pipewire graph.
    readonly property bool sinkMuted: !!(Audio.sink && Audio.sink.audio && Audio.sink.audio.muted)
    readonly property bool micMuted: !!(Audio.source && Audio.source.audio && Audio.source.audio.muted)
    function toggleSink() { if (Audio.sink && Audio.sink.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted; }
    function toggleMic() { if (Audio.source && Audio.source.audio) Audio.source.audio.muted = !Audio.source.audio.muted; }
}
