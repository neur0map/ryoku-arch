pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.Blobs
import "Singletons"

// the delos bar: the whole bar collapsed into one floating island in the
// frame's blob field. it is the recorder island (RecordHud) generalised and
// always live -- fused to a frame edge at rest, grab it to pull it off and it
// and a frame bump reach for each other and merge like two drops, let go and it
// drifts to the nearest edge, on a side edge it turns vertical, tap the grip to
// tuck it to a nub that hovering the edge pops back. it carries the modules the
// user picks (Config.islandModules, in order); power is not one of them, it
// opens on Super+Esc. it seeds its dock from Config and writes it back, and
// publishes its live edge + thickness to IslandDock so the window reserve
// follows it. nothing snaps.
Item {
    id: hud

    required property var group
    property real s: 1
    property bool active: true
    property real radius: Config.islandRadius * s
    property real smoothing: 30
    // delos never pre-thickens an edge (the island is the bar), so every lip is
    // just the frame border.
    property real barBand: 0
    property string barEdge: ""

    // module inputs the same way Bar.qml feeds its clusters.
    readonly property int activeWsId: Workspaces.activeId
    required property var trayWindow

    // a module was tapped / hovered: shell.qml grows the popout from the
    // island's docked edge at `along`.
    signal popoutRequested(string name)
    signal hoverPopoutRequested(string name, bool hovered)

    readonly property int moveDur: 560
    readonly property int meltDur: 620
    readonly property int mergeDur: 1700

    // --- contextual dynamic-island state (ActivSpot port). the island face
    // follows the active context (recording / discord call / music) and springs
    // to fit; any secondary contexts ride alongside as minibubbles, and a
    // rotation cycles which one is primary. contextual only on a horizontal dock
    // -- a vertical (side) island keeps the module column.
    readonly property var ctxActive: {
        var a = [];
        if (Recorder.anyActive) a.push("recording");
        if (VoiceCall.active) a.push("call");
        if (Media.playing) a.push("music");
        return a;
    }
    property string primaryCtx: ""
    onCtxActiveChanged: {
        if (hud.ctxActive.indexOf(hud.primaryCtx) < 0)
            hud.primaryCtx = hud.ctxActive.length > 0 ? hud.ctxActive[0] : "";
    }
    readonly property string context: (hud.ctxActive.indexOf(hud.primaryCtx) >= 0) ? hud.primaryCtx
        : (hud.ctxActive.length > 0 ? hud.ctxActive[0] : "idle")
    readonly property bool contextual: hud.context !== "idle" && !hud.layoutVertical
    readonly property var bubbleCtx: hud.ctxActive.filter(function (c) { return c !== hud.context; })
    Timer {
        interval: 4200
        running: hud.ctxActive.length > 1 && !hud.dragging && !hud.tucked
        repeat: true
        onTriggered: {
            var a = hud.ctxActive;
            var i = a.indexOf(hud.primaryCtx);
            hud.primaryCtx = a[(i + 1) % a.length];
        }
    }

    anchors.fill: parent

    readonly property real baseLip: Math.max(0, Config.frameBorder - 50)
    function lipFor(e) { return hud.baseLip + (e === hud.barEdge ? hud.barBand : 0); }
    readonly property real lipT: hud.lipFor("top")
    readonly property real lipB: hud.lipFor("bottom")
    readonly property real lipL: hud.lipFor("left")
    readonly property real lipR: hud.lipFor("right")

    property string dockEdge: "top"
    property real alongPx: 0
    property bool placed: false
    readonly property bool dragging: dragH.active
    property bool hidden: false

    onWidthChanged: hud.reposition()
    onHeightChanged: hud.reposition()
    // seed the dock from Config on first layout: edge, hidden, and the saved
    // along (else centre on the edge).
    function reposition() {
        if (hud.placed || hud.width <= 0)
            return;
        hud.dockEdge = Config.islandEdge;
        hud.hidden = Config.islandHidden;
        hud.alongPx = Config.islandAlong >= 0 ? Config.islandAlong
            : (hud.vertical ? (hud.height - hud.bodyH) / 2 : (hud.width - hud.bodyW) / 2);
        hud.nearEdge = hud.dockEdge;
        hud.px = hud.dockX;
        hud.py = hud.dockY;
        hud.placed = true;
    }
    // write the dock back so it survives a restart.
    function persistDock() {
        Config.islandEdge = hud.dockEdge;
        Config.islandAlong = hud.alongPx;
        Config.islandHidden = hud.hidden;
        Config.persist();
    }

    // --- reveal + melt: 0 in the border, 1 fully out, a small nub when hidden.
    property bool revealHeld: false
    readonly property bool revealed: bodyHov.hovered || edgeHov.hovered
    readonly property bool tucked: hud.hidden && !hud.revealHeld
    onRevealedChanged: {
        if (hud.revealed) { revealGrace.stop(); hud.revealHeld = true; }
        else revealGrace.restart();
    }
    Timer { id: revealGrace; interval: 260; onTriggered: hud.revealHeld = false }

    readonly property real nubProg: 0.14
    readonly property real wantProg: !hud.active ? 0 : ((!hud.hidden || hud.revealHeld) ? 1 : hud.nubProg)
    property real prog: hud.wantProg
    Behavior on prog { NumberAnimation { duration: hud.meltDur; easing.type: Easing.InOutCubic } }
    readonly property bool live: hud.active && hud.prog > 0.002
    visible: hud.live

    // --- orientation: vertical on a side edge; content fades out, flips at the
    // bottom of the dip, fades back.
    // orientation follows the docked edge, and does not flip mid-drag: the grip
    // is the sole drag handle, so reflowing the layout under the pointer would
    // drop the grab. the island keeps its shape while held and reorients on
    // release (cross-faded), once the dock edge is known.
    readonly property bool vertical: hud.dragging ? hud.layoutVertical : (hud.dockEdge === "left" || hud.dockEdge === "right")
    property bool layoutVertical: false
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

    property real bodyW: grid.implicitWidth + 22 * hud.s
    property real bodyH: grid.implicitHeight + 13 * hud.s
    Behavior on bodyW { SpringAnimation { spring: 4; damping: 0.42; mass: 1; epsilon: 0.5 } }
    Behavior on bodyH { SpringAnimation { spring: 4; damping: 0.42; mass: 1; epsilon: 0.5 } }

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
    Binding { target: hud; property: "px"; value: hud.dockX; when: !hud.dragging; restoreMode: Binding.RestoreNone }
    Binding { target: hud; property: "py"; value: hud.dockY; when: !hud.dragging; restoreMode: Binding.RestoreNone }
    onPxChanged: hud.settleEdge()
    onPyChanged: hud.settleEdge()

    // --- publish live dock state to the window reserve (a separate window).
    readonly property real fullExtent: (hud.dockEdge === "left" || hud.dockEdge === "right") ? hud.bodyW : hud.bodyH
    // reserve tracks the tucked state, not the transient hover-reveal, so a
    // window never jumps when you flick the cursor to a hidden island.
    readonly property real reserveThickness: hud.lipFor(hud.dockEdge) + (hud.hidden ? hud.fullExtent * hud.nubProg : hud.fullExtent)
    readonly property real alongCentre: (hud.dockEdge === "left" || hud.dockEdge === "right") ? (hud.py + hud.bodyH / 2) : (hud.px + hud.bodyW / 2)
    Binding { target: IslandDock; property: "active"; value: hud.active }
    Binding { target: IslandDock; property: "edge"; value: hud.dockEdge }
    Binding { target: IslandDock; property: "thickness"; value: hud.active ? hud.reserveThickness : 0 }
    Binding { target: IslandDock; property: "along"; value: hud.alongCentre }
    Binding { target: IslandDock; property: "hidden"; value: hud.hidden }

    // input-mask rects: the body while out, the edge strip so a hidden nub can
    // be hovered back. shell.qml unions both.
    readonly property real hudX: hud.px
    readonly property real hudY: hud.py
    readonly property real hudW: hud.bodyW
    readonly property real hudH: hud.bodyH
    readonly property real trigReach: hud.tucked ? 46 * hud.s : 18 * hud.s
    readonly property real trigPad: hud.tucked ? 44 * hud.s : 0
    readonly property real trigDepth: hud.lipFor(hud.dockEdge) + hud.trigReach
    readonly property real trigX: hud.dockEdge === "right" ? (hud.width - hud.trigDepth)
        : hud.dockEdge === "left" ? 0
        : (hud.tucked ? 0 : (hud.dockX - hud.trigPad))
    readonly property real trigY: hud.dockEdge === "bottom" ? (hud.height - hud.trigDepth)
        : hud.dockEdge === "top" ? 0
        : (hud.tucked ? 0 : (hud.dockY - hud.trigPad))
    // tucked: the whole docked edge is the peek zone, so the cursor reaching
    // that edge anywhere pops the nub back; open: a tight strip around it.
    readonly property real trigW: (hud.dockEdge === "left" || hud.dockEdge === "right") ? hud.trigDepth
        : (hud.tucked ? hud.width : (hud.bodyW + 2 * hud.trigPad))
    readonly property real trigH: (hud.dockEdge === "top" || hud.dockEdge === "bottom") ? hud.trigDepth
        : (hud.tucked ? hud.height : (hud.bodyH + 2 * hud.trigPad))

    readonly property real gapT: hud.py - hud.lipT
    readonly property real gapB: (hud.height - hud.lipB) - (hud.py + hud.bodyH)
    readonly property real gapL: hud.px - hud.lipL
    readonly property real gapR: (hud.width - hud.lipR) - (hud.px + hud.bodyW)
    function gapOf(e) { return e === "top" ? hud.gapT : e === "bottom" ? hud.gapB : e === "left" ? hud.gapL : hud.gapR; }
    readonly property string rawNearEdge: {
        var m = Math.min(hud.gapT, hud.gapB, hud.gapL, hud.gapR);
        return m === hud.gapT ? "top" : m === hud.gapB ? "bottom" : m === hud.gapL ? "left" : "right";
    }
    property string nearEdge: "top"
    function settleEdge() {
        if (hud.rawNearEdge === hud.nearEdge)
            return;
        if (hud.gapOf(hud.rawNearEdge) < hud.gapOf(hud.nearEdge) - 30 * hud.s)
            hud.nearEdge = hud.rawNearEdge;
    }
    readonly property real nearGap: Math.max(0, hud.gapOf(hud.nearEdge))
    readonly property real nearLip: hud.lipFor(hud.nearEdge)
    readonly property real threshold: 90 * hud.s
    readonly property real approach: Math.max(0, Math.min(1, 1 - hud.nearGap / hud.threshold))
    readonly property real pull: hud.approach * hud.approach
    readonly property real islandReach: (hud.nearGap / 2 + hud.nearLip + hud.smoothing) * hud.pull
    readonly property real bumpReach: (hud.nearGap / 2 + hud.smoothing) * hud.pull
    readonly property real extT: hud.nearEdge === "top" ? hud.islandReach : 0
    readonly property real extB: hud.nearEdge === "bottom" ? hud.islandReach : 0
    readonly property real extL: hud.nearEdge === "left" ? hud.islandReach : 0
    readonly property real extR: hud.nearEdge === "right" ? hud.islandReach : 0

    readonly property bool vDock: hud.dockEdge === "left" || hud.dockEdge === "right"
    readonly property real faceW: hud.vDock ? hud.bodyW * hud.prog : hud.bodyW
    readonly property real faceH: hud.vDock ? hud.bodyH : hud.bodyH * hud.prog
    readonly property real faceX: hud.dockEdge === "right" ? (hud.px + hud.bodyW - hud.faceW) : hud.px
    readonly property real faceY: hud.dockEdge === "bottom" ? (hud.py + hud.bodyH - hud.faceH) : hud.py

    readonly property bool bumpVert: hud.nearEdge === "top" || hud.nearEdge === "bottom"
    readonly property real bumpLen: hud.bumpReach + hud.nearLip + hud.smoothing
    readonly property real bumpX: hud.nearEdge === "right" ? (hud.width - hud.lipR - hud.bumpReach)
        : hud.nearEdge === "left" ? -hud.smoothing
        : hud.px
    readonly property real bumpY: hud.nearEdge === "bottom" ? (hud.height - hud.lipB - hud.bumpReach)
        : hud.nearEdge === "top" ? -hud.smoothing
        : hud.py

    SystemClock { id: clock; precision: SystemClock.Minutes }

    BlobRect {
        id: bodyBlob
        group: hud.live ? hud.group : null
        stiffness: 110
        damping: 15
        deformScale: 0.00003
        x: hud.faceX - hud.extL
        y: hud.faceY - hud.extT
        implicitWidth: hud.faceW + hud.extL + hud.extR
        implicitHeight: hud.faceH + hud.extT + hud.extB
        topLeftRadius: (hud.extT > 0 || hud.extL > 0) ? 0 : hud.radius
        topRightRadius: (hud.extT > 0 || hud.extR > 0) ? 0 : hud.radius
        bottomLeftRadius: (hud.extB > 0 || hud.extL > 0) ? 0 : hud.radius
        bottomRightRadius: (hud.extB > 0 || hud.extR > 0) ? 0 : hud.radius
    }

    BlobRect {
        id: frameBump
        group: (hud.live && hud.nearGap > 2 && hud.bumpReach > 0.5) ? hud.group : null
        stiffness: 110
        damping: 15
        deformScale: 0.00003
        x: hud.bumpX
        y: hud.bumpY
        implicitWidth: hud.bumpVert ? hud.bodyW : hud.bumpLen
        implicitHeight: hud.bumpVert ? hud.bumpLen : hud.bodyH
        topLeftRadius: (hud.nearEdge === "top" || hud.nearEdge === "left") ? 0 : hud.radius
        topRightRadius: (hud.nearEdge === "top" || hud.nearEdge === "right") ? 0 : hud.radius
        bottomLeftRadius: (hud.nearEdge === "bottom" || hud.nearEdge === "left") ? 0 : hud.radius
        bottomRightRadius: (hud.nearEdge === "bottom" || hud.nearEdge === "right") ? 0 : hud.radius
    }

    // minibubbles: any active context that is not the island's current face
    // rides beside it as a satellite blob in the same field (the ActivSpot
    // dual-bubble). the primary rotates on the timer above; each bubble spawns
    // with a little spring pop.
    Repeater {
        model: (hud.live && hud.contextual && hud.prog > 0.6) ? hud.bubbleCtx : []
        delegate: Item {
            id: bub
            required property string modelData
            required property int index
            readonly property real bs: Math.round(hud.bodyH * 0.74)
            readonly property real gap: 8 * hud.s
            x: hud.vDock ? hud.px + (hud.bodyW - bs) / 2
                : hud.px + hud.bodyW + gap + index * (bs + gap)
            y: hud.vDock ? hud.py + hud.bodyH + gap + index * (bs + gap)
                : hud.py + (hud.bodyH - bs) / 2
            width: bs
            height: bs
            property bool shown: false
            scale: shown ? 1 : 0.05
            transformOrigin: Item.Center
            Behavior on scale { SpringAnimation { spring: 4; damping: 0.38 } }
            Component.onCompleted: bub.shown = true

            BlobRect {
                group: hud.live ? hud.group : null
                stiffness: 110
                damping: 15
                deformScale: 0.00003
                anchors.fill: parent
                radius: parent.height / 2
            }
            MaterialIcon {
                anchors.centerIn: parent
                text: bub.modelData === "music" ? "music_note"
                    : bub.modelData === "recording" ? "fiber_manual_record" : "call"
                fill: 1
                color: Theme.sun
                font.pixelSize: 13 * hud.s
            }
            TapHandler { onTapped: hud.primaryCtx = bub.modelData }
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

    // module components, chosen by id from Config.islandModules.
    // display-only: the island shows the workspace but does not switch on a
    // click or scroll (that is what a stray grab was doing). Super+N switches.
    Component { id: wsComp; BarWorkspaces { s: hud.s; activeWsId: hud.activeWsId; vertical: hud.layoutVertical; enabled: false } }
    Component {
        id: clockComp
        Grid {
            columns: hud.layoutVertical ? 1 : 2
            rowSpacing: 2 * hud.s
            columnSpacing: 7 * hud.s
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            // the red sun: Delos's signature, the one always-fixed accent.
            Rectangle {
                width: 7 * hud.s
                height: 7 * hud.s
                radius: width / 2
                color: Theme.sun
            }
            Text {
                text: hud.layoutVertical
                    ? clock.date.toLocaleTimeString(Qt.locale("en_US"), "HH") + "\n" + clock.date.toLocaleTimeString(Qt.locale("en_US"), "mm")
                    : clock.date.toLocaleTimeString(Qt.locale("en_US"), "HH:mm")
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 0.88
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: 14 * hud.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1
                font.features: ({ "tnum": 1 })
            }
            TapHandler { onTapped: hud.popoutRequested("calendar") }
        }
    }
    Component {
        id: dateComp
        Grid {
            columns: hud.layoutVertical ? 1 : 2
            rowSpacing: 2 * hud.s
            columnSpacing: 6 * hud.s
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter
            // engraved hairline tick, editorial.
            Rectangle {
                visible: !hud.layoutVertical
                width: Math.max(1, hud.s)
                height: 11 * hud.s
                color: Theme.hair
            }
            Text {
                text: hud.layoutVertical
                    ? (clock.date.toLocaleDateString(Qt.locale("en_US"), "ddd") + "\n" + clock.date.toLocaleDateString(Qt.locale("en_US"), "d") + "\n" + clock.date.toLocaleDateString(Qt.locale("en_US"), "MMM")).toUpperCase()
                    : clock.date.toLocaleDateString(Qt.locale("en_US"), "ddd d MMM").toUpperCase()
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.0
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 9.5 * hud.s
                font.weight: Font.Medium
                font.letterSpacing: 2
            }
            TapHandler { onTapped: hud.popoutRequested("calendar") }
        }
    }
    Component {
        id: mediaComp
        Item {
            visible: Media.present
            implicitWidth: hud.layoutVertical ? vIcon.implicitWidth : (Media.present ? med.implicitWidth : 0)
            implicitHeight: hud.layoutVertical ? vIcon.implicitHeight : med.implicitHeight
            BarMedia { id: med; s: hud.s; visible: !hud.layoutVertical; maxW: 200 * hud.s }
            MaterialIcon {
                id: vIcon
                anchors.centerIn: parent
                visible: hud.layoutVertical
                text: "music_note"
                color: Theme.cream
                font.pixelSize: 15 * hud.s
            }
            HoverHandler { id: medHov; onHoveredChanged: hud.hoverPopoutRequested("media", medHov.hovered) }
            TapHandler { onTapped: Media.toggle() }
            onVisibleChanged: if (!visible) hud.hoverPopoutRequested("media", false)
        }
    }
    Component { id: titleComp; BarTitle { s: hud.s; maxWidth: 220 * hud.s; label: Config.barShowTitle && ToplevelManager.activeToplevel ? (ToplevelManager.activeToplevel.title || "") : "" } }
    Component { id: statusComp; BarStatus { s: hud.s; vertical: hud.layoutVertical; onRequestPopout: (name, center) => hud.popoutRequested(name) } }
    Component { id: trayComp; BarTray { s: hud.s; vertical: hud.layoutVertical; trayWindow: hud.trayWindow; menuEdgeY: hud.py + hud.bodyH } }

    // contextual faces: the island morphs to carry the live context, ActivSpot
    // style, recoloured to Delos's fixed red sun. display-driven off the shared
    // singletons; the grip stays put beside them so the island is still draggable.
    Component {
        id: musicFace
        Row {
            spacing: 8 * hud.s
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 22 * hud.s; height: 22 * hud.s; radius: width / 2; clip: true
                color: Qt.alpha(Theme.bright, 0.05)
                border.width: 1
                border.color: Qt.alpha(Theme.sun, 0.85)
                Image {
                    anchors.fill: parent; anchors.margins: 1
                    source: Media.player ? (Media.player.trackArtUrl || "") : ""
                    sourceSize: Qt.size(44, 44); fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: true; visible: status === Image.Ready
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    visible: !(Media.player && (Media.player.trackArtUrl || "").length)
                    text: "music_note"; color: Theme.iconDim; font.pixelSize: 11 * hud.s
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Media.line; elide: Text.ElideRight
                width: Math.min(implicitWidth, 220 * hud.s)
                color: Theme.cream; font.family: Theme.font
                font.pixelSize: 11 * hud.s; font.weight: Font.Medium
            }
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: Media.playing ? "pause" : "play_arrow"; fill: 1
                color: Theme.sun; font.pixelSize: 14 * hud.s
            }
            TapHandler { onTapped: Media.toggle() }
            HoverHandler { id: mfHov; onHoveredChanged: hud.hoverPopoutRequested("media", mfHov.hovered) }
        }
    }
    Component {
        id: recordingFace
        Row {
            spacing: 7 * hud.s
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 9 * hud.s; height: 9 * hud.s; radius: width / 2; color: Theme.sun
                SequentialAnimation on opacity {
                    running: !Recorder.paused; loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 620; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Recorder.paused ? "PAUSED" : "REC"; color: Theme.sun
                font.family: Theme.mono; font.pixelSize: 10 * hud.s
                font.weight: Font.Bold; font.letterSpacing: 2 * hud.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Recorder.elapsedText; color: Theme.cream
                font.family: Theme.mono; font.pixelSize: 11 * hud.s
                font.weight: Font.DemiBold; font.features: ({ "tnum": 1 })
            }
        }
    }
    Component {
        id: callFace
        Row {
            spacing: 7 * hud.s
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "call"; fill: 1; color: Theme.sun; font.pixelSize: 14 * hud.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CALL"; color: Theme.sun
                font.family: Theme.mono; font.pixelSize: 10 * hud.s
                font.weight: Font.Bold; font.letterSpacing: 2 * hud.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: VoiceCall.elapsedText; color: Theme.cream
                font.family: Theme.mono; font.pixelSize: 11 * hud.s
                font.weight: Font.DemiBold; font.features: ({ "tnum": 1 })
            }
        }
    }

    Item {
        id: content
        x: hud.px
        y: hud.py
        width: hud.bodyW
        height: hud.bodyH
        opacity: hud.reorientFade * Math.max(0, Math.min(1, (hud.prog - 0.6) / 0.35))
        transform: Matrix4x4 { matrix: bodyBlob.deformMatrix }
        HoverHandler { id: bodyHov }

        Grid {
            id: grid
            anchors.centerIn: parent
            columns: hud.layoutVertical ? 1 : 99
            rowSpacing: 8 * hud.s
            columnSpacing: 12 * hud.s
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            // grip: the only drag handle. drag it to move the island; a tap
            // tucks it to a nub. the rest of the island stays free, so modules
            // keep their taps, hovers, and wheels (the audio scroll included).
            Item {
                width: 14 * hud.s
                height: 16 * hud.s
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
                            color: gripHov.hovered ? Theme.cream : Theme.dim
                        }
                    }
                }
                HoverHandler { id: gripHov; cursorShape: Qt.SizeAllCursor }
                DragHandler {
                    id: dragH
                    target: null
                    dragThreshold: 8
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
                            var e = hud.rawNearEdge;
                            hud.nearEdge = e;
                            hud.alongPx = (e === "top" || e === "bottom") ? hud.px : hud.py;
                            hud.dockEdge = e;
                            hud.persistDock();
                        }
                    }
                    onCentroidChanged: {
                        if (!dragH.active)
                            return;
                        hud.px = Math.max(hud.lipL, Math.min(hud.width - hud.lipR - hud.bodyW, dragH.sx + (dragH.centroid.scenePosition.x - dragH.ax)));
                        hud.py = Math.max(hud.lipT, Math.min(hud.height - hud.lipB - hud.bodyH, dragH.sy + (dragH.centroid.scenePosition.y - dragH.ay)));
                    }
                }
                TapHandler { onTapped: hud.hidden = !hud.hidden }
            }

            Repeater {
                model: Config.islandModules
                Loader {
                    required property var modelData
                    visible: !hud.contextual
                    enabled: !hud.dragging
                    sourceComponent: modelData === "workspaces" ? wsComp
                        : modelData === "clock" ? clockComp
                        : modelData === "date" ? dateComp
                        : modelData === "media" ? mediaComp
                        : modelData === "title" ? titleComp
                        : modelData === "status" ? statusComp
                        : modelData === "tray" ? trayComp
                        : null
                }
            }
            Loader {
                id: ctxLoader
                active: hud.contextual
                visible: hud.contextual
                sourceComponent: hud.context === "music" ? musicFace
                    : hud.context === "recording" ? recordingFace
                    : hud.context === "call" ? callFace : null
            }
        }
    }

    onHiddenChanged: hud.persistDock()

    // tucked cue: a dot on the nub so a hidden island reads as tucked, not gone.
    Rectangle {
        readonly property real cx: hud.faceX + hud.faceW / 2
        readonly property real cy: hud.faceY + hud.faceH / 2
        width: 7 * hud.s
        height: 7 * hud.s
        radius: width / 2
        x: cx - width / 2
        y: cy - height / 2
        color: Theme.brand
        opacity: hud.active ? Math.max(0, 1 - hud.prog / 0.5) * 0.9 : 0
        visible: opacity > 0.01
    }
}
