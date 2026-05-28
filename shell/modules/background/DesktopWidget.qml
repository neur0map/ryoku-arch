pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Config
import qs.components
import qs.services

// Draggable desktop-widget wrapper. Hosts arbitrary content on the background
// layer and, in edit mode, draws a selection outline, a floating toolbar and
// corner resize handles. Position + scale persist to the given config object
// (`cfg`) via direct property assignment (the C++ ConfigObject has no
// setProperty) followed by GlobalConfig.save().
Item {
    id: root

    required property var cfg          // e.g. GlobalConfig.background.desktopClock or .widgets.media
    required property Item canvas      // bounds to position within
    property string label: ""
    property real margin: Tokens.padding.large * 2
    property real leftInset: 0         // left-edge inset (bar width) for anchored placement
    // When the content scales itself from cfg.scale (e.g. the clock), the
    // holder must NOT scale too, or it double-applies.
    property bool selfScales: false

    default property alias content: holder.data

    readonly property bool editMode: Visibilities.widgetEditMode
    readonly property bool locked: cfg.locked ?? false
    // Widgets drag any time (not just in edit mode); edit mode only adds the
    // resize handles, grid and toolbar.
    readonly property bool draggable: !locked
    readonly property real scaleF: cfg.scale ?? 1.0
    readonly property real holderScale: selfScales ? 1 : scaleF

    readonly property int gridSize: GlobalConfig.background.widgets.gridSize
    readonly property bool snap: GlobalConfig.background.widgets.snap

    property bool _releaseGuard: false

    // RYOKU: custom (file-backed) widgets supply a saveFn so geometry/lock persist
    // to their own manifest.json; built-in widgets leave it null and fall back to
    // GlobalConfig.save().
    property var saveFn: null
    function _save(): void {
        if (root.saveFn)
            root.saveFn();
        else
            GlobalConfig.save();
    }

    function _clampScale(v: real): real {
        return Math.max(0.4, Math.min(2.5, v));
    }

    function applyScale(v: real, doSave: bool): void {
        cfg.scale = root._clampScale(v);
        if (doSave)
            root._save();
    }

    function setScale(v: real): void {
        root.applyScale(Math.round(v * 20) / 20, true);
    }

    function toggleLock(): void {
        cfg.locked = !cfg.locked;
        root._save();
    }

    function resetToAnchor(): void {
        cfg.freePosition = false;
        root._save();
        root.applyPosition();
    }

    function _snapTo(v: real): real {
        return (root.snap && root.gridSize > 1) ? Math.round(v / root.gridSize) * root.gridSize : v;
    }

    implicitWidth: holder.childrenRect.width * holderScale
    implicitHeight: holder.childrenRect.height * holderScale
    width: implicitWidth
    height: implicitHeight

    function _anchoredX(): real {
        const pos = String(cfg.position ?? "center");
        const usableLeft = root.leftInset + root.margin;
        if (pos.endsWith("left"))
            return usableLeft;
        if (pos.endsWith("right"))
            return canvas.width - root.width - root.margin;
        return usableLeft + (canvas.width - usableLeft - root.margin - root.width) / 2;
    }

    function _anchoredY(): real {
        const pos = String(cfg.position ?? "center");
        if (pos.startsWith("top"))
            return root.margin;
        if (pos.startsWith("bottom"))
            return canvas.height - root.height - root.margin;
        return (canvas.height - root.height) / 2;
    }

    function applyPosition(): void {
        if (root._releaseGuard)
            return;
        if (cfg.freePosition) {
            root.x = cfg.x;
            root.y = cfg.y;
        } else {
            root.x = root._anchoredX();
            root.y = root._anchoredY();
        }
    }

    // Persist current geometry: snap + clamp to canvas, write x/y/scale.
    function persist(doSnap: bool): void {
        let nx = doSnap ? root._snapTo(root.x) : root.x;
        let ny = doSnap ? root._snapTo(root.y) : root.y;
        nx = Math.round(Math.max(0, Math.min(nx, canvas.width - root.width)));
        ny = Math.round(Math.max(0, Math.min(ny, canvas.height - root.height)));
        root.x = nx;
        root.y = ny;
        cfg.x = nx;
        cfg.y = ny;
        if (!cfg.freePosition)
            cfg.freePosition = true;
        root._save();
    }

    Component.onCompleted: applyPosition()
    onWidthChanged: if (!bodyDrag.drag.active) applyPosition()
    onHeightChanged: if (!bodyDrag.drag.active) applyPosition()

    Connections {
        target: root.cfg

        function onXChanged(): void {
            root.applyPosition();
        }
        function onYChanged(): void {
            root.applyPosition();
        }
        function onFreePositionChanged(): void {
            root.applyPosition();
        }
        function onPositionChanged(): void {
            root.applyPosition();
        }
    }

    Connections {
        target: root.canvas

        function onWidthChanged(): void {
            root.applyPosition();
        }
        function onHeightChanged(): void {
            root.applyPosition();
        }
    }

    // Content host. childrenRect drives the widget's intrinsic size; the holder
    // scales from its top-left so chrome anchored to root edges stays aligned.
    // Sits above the body-drag MouseArea so interactive content (media buttons)
    // still receives clicks while the empty card area falls through to drag.
    Item {
        id: holder

        z: 1
        transformOrigin: Item.TopLeft
        scale: root.holderScale
        width: childrenRect.width
        height: childrenRect.height
    }

    // Snap-landing preview while dragging.
    Rectangle {
        z: 48
        visible: bodyDrag.drag.active && root.snap
        x: root._snapTo(root.x) - root.x
        y: root._snapTo(root.y) - root.y
        width: root.width
        height: root.height
        radius: Tokens.rounding.normal
        color: "transparent"
        border.width: 1.5
        border.color: Qt.alpha(Colours.palette.m3primary, 0.4)
    }

    // Edit-mode selection outline.
    Rectangle {
        z: 49
        anchors.fill: parent
        anchors.margins: -4
        visible: root.editMode
        radius: Tokens.rounding.normal
        color: "transparent"
        border.width: root.locked ? 2 : 1.5
        border.color: root.locked ? Qt.alpha(Colours.palette.m3error, 0.55) : Qt.alpha(Colours.palette.m3primary, 0.5)
    }

    // Widget name badge below the widget while editing.
    StyledText {
        z: 50
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 6
        visible: root.editMode && root.label.length > 0
        text: root.label
        color: Qt.alpha(Colours.palette.m3onSurface, 0.55)
        font.pointSize: Tokens.font.size.small
    }

    // Body drag uses a MouseArea (not a DragHandler) so the higher-z corner
    // resize handles win grab arbitration deterministically. Left-only so
    // right-clicks fall through to the desktop context menu.
    MouseArea {
        id: bodyDrag

        z: 0
        anchors.fill: parent
        enabled: root.draggable
        acceptedButtons: Qt.LeftButton
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.threshold: 4

        onPressed: root._releaseGuard = true
        onReleased: {
            root.persist(true);
            root._releaseGuard = false;
        }
    }

    // ── Floating edit toolbar (above the widget) ───────────────────────────
    StyledRect {
        id: toolbar

        z: 52
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.top
        anchors.bottomMargin: 10
        visible: root.editMode
        implicitWidth: toolbarRow.implicitWidth + Tokens.padding.small * 2
        implicitHeight: 34
        radius: Tokens.rounding.full
        color: Colours.palette.m3surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.7)

        Row {
            id: toolbarRow

            anchors.centerIn: parent
            spacing: 0

            ToolButton {
                icon: root.locked ? "lock" : "lock_open"
                accent: root.locked
                onActivated: root.toggleLock()
            }

            ToolButton {
                icon: "remove"
                enabled: !root.locked
                onActivated: root.setScale(root.scaleF - 0.1)
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                horizontalAlignment: Text.AlignHCenter
                text: Math.round(root.scaleF * 100) + "%"
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.small
                font.weight: Font.DemiBold
            }

            ToolButton {
                icon: "add"
                enabled: !root.locked
                onActivated: root.setScale(root.scaleF + 0.1)
            }

            ToolButton {
                icon: "restart_alt"
                enabled: !root.locked
                onActivated: root.resetToAnchor()
            }

            ToolButton {
                icon: "tune"
                onActivated: {
                    Visibilities.widgetEditMode = false;
                    Visibilities.pendingSettingsTab = "DesktopWidgets";
                    const v = Visibilities.getForActive();
                    if (v)
                        v.settings = true;
                }
            }
        }
    }

    // ── Corner resize handles (uniform scale) ──────────────────────────────
    component ResizeHandle: Rectangle {
        id: rh

        property bool atLeft: false
        property bool atTop: false

        property real _w0: 0
        property real _h0: 0
        property real _x0: 0
        property real _y0: 0
        property real _s0: 1

        z: 53
        visible: root.editMode && !root.locked
        width: 13
        height: 13
        radius: 4
        color: Colours.palette.m3primary
        border.width: 1.5
        border.color: Colours.palette.m3surface
        opacity: rhArea.containsMouse || rhArea.pressed ? 1 : 0.8

        MouseArea {
            id: rhArea

            anchors.fill: parent
            anchors.margins: -11
            hoverEnabled: true
            preventStealing: true
            cursorShape: (rh.atLeft === rh.atTop) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor

            onPressed: {
                rh._w0 = root.width;
                rh._h0 = root.height;
                rh._x0 = root.x;
                rh._y0 = root.y;
                rh._s0 = root.scaleF;
                root._releaseGuard = true;
            }

            onPositionChanged: mouse => {
                if (!pressed)
                    return;
                const m = rhArea.mapToItem(root.canvas, mouse.x, mouse.y);
                let newW = rh.atLeft ? (rh._x0 + rh._w0 - m.x) : (m.x - rh._x0);
                if (newW < 30)
                    newW = 30;
                const ratio = rh._w0 > 0 ? newW / rh._w0 : 1;
                const ns = root._clampScale(rh._s0 * ratio);
                root.applyScale(ns, false);
                const nW = rh._w0 * ns / rh._s0;
                const nH = rh._h0 * ns / rh._s0;
                root.x = rh.atLeft ? (rh._x0 + rh._w0 - nW) : rh._x0;
                root.y = rh.atTop ? (rh._y0 + rh._h0 - nH) : rh._y0;
            }

            onReleased: {
                root.persist(false);
                root._save();
                root._releaseGuard = false;
            }
        }
    }

    ResizeHandle {
        atLeft: true
        atTop: true
        anchors.left: parent.left
        anchors.top: parent.top
    }

    ResizeHandle {
        atLeft: false
        atTop: true
        anchors.right: parent.right
        anchors.top: parent.top
    }

    ResizeHandle {
        atLeft: true
        atTop: false
        anchors.left: parent.left
        anchors.bottom: parent.bottom
    }

    ResizeHandle {
        atLeft: false
        atTop: false
        anchors.right: parent.right
        anchors.bottom: parent.bottom
    }

    component ToolButton: StyledRect {
        id: tb

        required property string icon
        property bool accent: false
        property bool enabled: true
        signal activated

        implicitWidth: 30
        implicitHeight: 30
        radius: width / 2
        color: "transparent"
        opacity: enabled ? 1 : 0.4

        StateLayer {
            disabled: !tb.enabled
            color: tb.accent ? Colours.palette.m3error : Colours.palette.m3onSurface
            onClicked: tb.activated()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: tb.icon
            color: tb.accent ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.normal
        }
    }
}
