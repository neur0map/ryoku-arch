pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services

// Draggable desktop-widget wrapper. Hosts arbitrary content on the background
// layer, handles edit-mode drag + grid snap, and persists position/scale to the
// given config object (`cfg`) via setProperty + GlobalConfig.save().
Item {
    id: root

    required property var cfg          // e.g. GlobalConfig.background.desktopClock or .widgets.media
    required property Item canvas      // bounds to position within
    property string label: ""
    property real margin: Tokens.padding.large * 2
    property real leftInset: 0         // left-edge inset (bar width) for anchored placement
    // When the content scales itself from cfg.scale (e.g. the clock), the
    // wrapper must NOT scale too, or it double-applies.
    property bool selfScales: false

    default property alias content: holder.data

    readonly property bool editMode: Visibilities.widgetEditMode
    readonly property bool locked: cfg.locked ?? false
    readonly property bool draggable: editMode && !locked
    readonly property real widgetScale: cfg.scale ?? 1.0

    property bool _releaseGuard: false
    property bool _menuOpen: false

    function setScale(v: real): void {
        const s = Math.max(0.5, Math.min(2.0, Math.round(v * 20) / 20));
        cfg.scale = s;
        GlobalConfig.save();
    }

    function toggleLock(): void {
        cfg.locked = !cfg.locked;
        GlobalConfig.save();
    }

    function resetToAnchor(): void {
        cfg.freePosition = false;
        GlobalConfig.save();
        root.applyPosition();
    }

    implicitWidth: holder.childrenRect.width
    implicitHeight: holder.childrenRect.height
    width: implicitWidth
    height: implicitHeight
    scale: selfScales ? 1 : widgetScale
    transformOrigin: Item.TopLeft

    function _anchoredX(): real {
        const pos = String(cfg.position ?? "center");
        const usableLeft = root.leftInset + root.margin;
        const span = root.width * root.scale;
        if (pos.endsWith("left"))
            return usableLeft;
        if (pos.endsWith("right"))
            return canvas.width - span - root.margin;
        return usableLeft + (canvas.width - usableLeft - root.margin - span) / 2;
    }

    function _anchoredY(): real {
        const pos = String(cfg.position ?? "center");
        const span = root.height * root.scale;
        if (pos.startsWith("top"))
            return root.margin;
        if (pos.startsWith("bottom"))
            return canvas.height - span - root.margin;
        return (canvas.height - span) / 2;
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

    function persist(): void {
        const grid = GlobalConfig.background.widgets.gridSize;
        const snap = GlobalConfig.background.widgets.snap;
        let nx = root.x;
        let ny = root.y;
        if (snap && grid > 1) {
            nx = Math.round(nx / grid) * grid;
            ny = Math.round(ny / grid) * grid;
        }
        nx = Math.round(Math.max(0, Math.min(nx, canvas.width - root.width * root.scale)));
        ny = Math.round(Math.max(0, Math.min(ny, canvas.height - root.height * root.scale)));
        root.x = nx;
        root.y = ny;
        // CONFIG_PROPERTY exposes writable Q_PROPERTYs; assign directly (the
        // C++ ConfigObject has no setProperty()), then persist the root config.
        cfg.x = nx;
        cfg.y = ny;
        if (!cfg.freePosition)
            cfg.freePosition = true;
        GlobalConfig.save();
    }

    Component.onCompleted: applyPosition()
    onWidthChanged: if (!dragHandler.active) applyPosition()
    onHeightChanged: if (!dragHandler.active) applyPosition()

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

    // Content host. childrenRect drives the widget's size.
    Item {
        id: holder
    }

    // Edit-mode chrome: accent outline (red when locked) + grab affordance.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -Tokens.padding.small
        visible: root.editMode
        radius: Tokens.rounding.normal
        color: root.locked ? Qt.alpha(Colours.palette.m3error, 0.08) : Qt.alpha(Colours.palette.m3primary, 0.10)
        border.width: 2
        border.color: root.locked ? Colours.palette.m3error : Colours.palette.m3primary

        StyledText {
            anchors.left: parent.left
            anchors.bottom: parent.top
            anchors.bottomMargin: 2
            anchors.leftMargin: 2
            visible: root.label.length > 0
            text: root.label + (root.locked ? "  (locked)" : "")
            color: root.locked ? Colours.palette.m3error : Colours.palette.m3primary
            font.pointSize: Tokens.font.size.small
            font.weight: Font.Bold
        }
    }

    DragHandler {
        id: dragHandler

        enabled: root.draggable
        target: root
        cursorShape: Qt.OpenHandCursor

        onActiveChanged: {
            if (active) {
                root._releaseGuard = true;
            } else {
                root.persist();
                root._releaseGuard = false;
            }
        }
    }

    // Right-click (edit mode) opens the per-widget edit menu. A right-button
    // MouseArea is deterministic; left events fall through to the DragHandler.
    MouseArea {
        anchors.fill: parent
        enabled: root.editMode
        acceptedButtons: Qt.RightButton
        onClicked: root._menuOpen = !root._menuOpen
    }

    // Per-widget edit popover: size, lock, reset, settings.
    // Parented to the full-screen canvas so it stays within input bounds (a
    // child rendered outside the widget's own geometry would not receive clicks).
    StyledRect {
        id: editMenu

        parent: root.canvas
        visible: root.editMode && root._menuOpen
        x: Math.min(root.x, root.canvas.width - width - Tokens.padding.normal)
        y: {
            const below = root.y + root.height * root.scale + Tokens.padding.small;
            return (below + height < root.canvas.height) ? below : Math.max(0, root.y - height - Tokens.padding.small);
        }
        implicitWidth: menuCol.implicitWidth + Tokens.padding.normal * 2
        implicitHeight: menuCol.implicitHeight + Tokens.padding.normal * 2
        radius: Tokens.rounding.normal
        color: Colours.palette.m3surfaceContainer
        border.width: 1
        border.color: Colours.palette.m3outlineVariant
        z: 1000

        ColumnLayout {
            id: menuCol

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            StyledText {
                text: (root.label.length > 0 ? root.label : "Widget")
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.small
                font.weight: Font.Bold
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: "Size"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                }

                MenuIconButton {
                    icon: "remove"
                    onActivated: root.setScale(root.widgetScale - 0.1)
                }

                StyledText {
                    text: Math.round(root.widgetScale * 100) + "%"
                    color: Colours.palette.m3onSurface
                    font.pointSize: Tokens.font.size.small
                    font.weight: Font.DemiBold
                }

                MenuIconButton {
                    icon: "add"
                    onActivated: root.setScale(root.widgetScale + 0.1)
                }
            }

            MenuRowButton {
                icon: root.locked ? "lock" : "lock_open"
                text: root.locked ? "Unlock" : "Lock"
                onActivated: root.toggleLock()
            }

            MenuRowButton {
                icon: "restart_alt"
                text: "Reset position"
                onActivated: root.resetToAnchor()
            }

            MenuRowButton {
                icon: "tune"
                text: "Settings"
                onActivated: {
                    root._menuOpen = false;
                    Visibilities.widgetEditMode = false;
                    const v = Visibilities.getForActive();
                    if (v)
                        v.settings = true;
                }
            }
        }
    }

    component MenuIconButton: StyledRect {
        id: miBtn

        required property string icon
        signal activated

        implicitWidth: 26
        implicitHeight: 26
        radius: width / 2
        color: Colours.palette.m3surfaceContainerHighest

        StateLayer {
            color: Colours.palette.m3onSurface
            onClicked: miBtn.activated()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: miBtn.icon
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.small
        }
    }

    component MenuRowButton: StyledRect {
        id: mrBtn

        required property string icon
        required property string text
        signal activated

        Layout.fillWidth: true
        implicitHeight: 30
        radius: Tokens.rounding.small
        color: "transparent"

        StateLayer {
            color: Colours.palette.m3onSurface
            onClicked: mrBtn.activated()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.small
            anchors.rightMargin: Tokens.padding.small
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: mrBtn.icon
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }

            StyledText {
                Layout.fillWidth: true
                text: mrBtn.text
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.small
            }
        }
    }
}
