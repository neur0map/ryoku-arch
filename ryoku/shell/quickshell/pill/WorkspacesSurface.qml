pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "Singletons"

/**
 * Workspace switcher grown from the pill centre (Super+Tab). A filmstrip of
 * workspace tiles for this monitor, each a scaled mini-map of that workspace
 * with its windows drawn where they actually sit. Click a window to focus it,
 * click a tile to switch to that workspace, or drag a window onto another tile
 * to move it there; a trailing "+" tile sends a window to a fresh workspace.
 *
 * Windows on inactive workspaces are unmapped in Hyprland, so they cannot be
 * live thumbnails: each is an icon card placed at its real scaled geometry.
 *
 * The drag is tracked by hand rather than with Qt's Drag/DropArea: the pill is a
 * layer-shell surface and reparenting a dragged item into an overlay mid-grab
 * loses the pointer, so the press-grabbing MouseArea instead drives a cursor
 * ghost and hit-tests the tile under the pointer on release.
 */
PillSurface {
    id: root

    mTop: 16
    mLeft: 16
    mRight: 16
    mBottom: 16

    ameForm: "off"

    // Set by the pill: the monitor this surface lives on, so the strip shows
    // that screen's workspaces (matching the pill's WorkspaceWave).
    property string screenName: ""

    // ── Monitor geometry (logical, matching hyprctl client coords) ─────────
    readonly property var mon: {
        var ms = Hyprland.monitors.values;
        for (var i = 0; i < ms.length; i++)
            if (ms[i].name === root.screenName)
                return ms[i];
        return null;
    }
    readonly property var monObj: root.mon ? root.mon.lastIpcObject : null
    readonly property real monScale: (root.monObj && root.monObj.scale > 0) ? root.monObj.scale : 1
    readonly property real monLW: (root.monObj && root.monObj.width > 0) ? root.monObj.width / root.monScale : 2560
    readonly property real monLH: (root.monObj && root.monObj.height > 0) ? root.monObj.height / root.monScale : 1600
    readonly property real monX: root.monObj ? root.monObj.x : 0
    readonly property real monY: root.monObj ? root.monObj.y : 0
    readonly property real aspect: root.monLW > 0 ? root.monLH / root.monLW : 0.625
    readonly property int activeWsId: (root.mon && root.mon.activeWorkspace) ? root.mon.activeWorkspace.id : -1

    // ── Workspaces on this monitor, low id first ───────────────────────────
    readonly property var wsList: {
        var out = [];
        var all = Hyprland.workspaces.values;
        for (var i = 0; i < all.length; i++) {
            var w = all[i];
            if (w && w.id > 0 && w.monitor && w.monitor.name === root.screenName)
                out.push(w);
        }
        out.sort(function (a, b) { return a.id - b.id; });
        return out;
    }
    // The next free workspace id, the target of the trailing "+" tile.
    readonly property int newWsId: {
        var m = 0;
        for (var i = 0; i < root.wsList.length; i++)
            if (root.wsList[i].id > m)
                m = root.wsList[i].id;
        return m + 1;
    }

    // ── Tile sizing: a row that shrinks each tile to stay bounded ──────────
    readonly property real gap: 10 * root.s
    readonly property real labelH: 17 * root.s
    readonly property real maxRowW: 760 * root.s
    readonly property real minTileW: 92 * root.s
    readonly property real maxTileW: 156 * root.s
    readonly property int tileCount: root.wsList.length + 1
    readonly property real tileW: Math.max(root.minTileW,
        Math.min(root.maxTileW, (root.maxRowW - (root.tileCount - 1) * root.gap) / root.tileCount))
    readonly property real tileH: Math.round(root.tileW * root.aspect)
    readonly property real innerW: root.tileCount * root.tileW + (root.tileCount - 1) * root.gap

    // Read by the pill's surfaceSize: full pill width and content height.
    readonly property real desiredW: root.innerW + (root.mLeft + root.mRight) * root.s
    implicitHeight: root.labelH + root.tileH

    // Open with fresh geometry: the pill refreshes toplevels on open/close/move,
    // not on in-place moves, so a window's position could otherwise be stale.
    onOpenChanged: if (open) {
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    // ── Drag state (a window card being carried to another tile) ───────────
    readonly property int noWs: -999
    property bool dragging: false
    property string dragAddr: ""
    property int dragSrcWs: noWs
    property int dragTargetWs: noWs
    property real dragX: 0
    property real dragY: 0
    property var dragTl: null

    function endDrag() {
        root.dragging = false;
        root.dragTargetWs = root.noWs;
        root.dragSrcWs = root.noWs;
        root.dragAddr = "";
        root.dragTl = null;
    }

    // Which workspace tile sits under a point in `strip` coordinates, or noWs
    // for a gap / off the strip. The "+" tile (index == wsList.length) targets
    // a fresh workspace.
    function tileAt(px, py) {
        if (py < 0 || py > root.labelH + root.tileH || px < 0)
            return root.noWs;
        var unit = root.tileW + root.gap;
        var i = Math.floor(px / unit);
        if (px - i * unit > root.tileW)
            return root.noWs;
        if (i < root.wsList.length)
            return root.wsList[i].id;
        if (i === root.wsList.length)
            return root.newWsId;
        return root.noWs;
    }

    function normAddr(addr) {
        return (addr && addr.indexOf("0x") === 0) ? addr : "0x" + addr;
    }
    function moveWindow(addr, wsId) {
        if (!addr)
            return;
        Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + wsId + ', window = "address:' + root.normAddr(addr) + '" })');
    }
    function focusWindow(addr) {
        if (!addr)
            return;
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + root.normAddr(addr) + '" })');
        root.requestClose();
    }
    function switchWs(wsId) {
        Hyprland.dispatch('hl.dsp.focus({ workspace = ' + wsId + ' })');
        root.requestClose();
    }

    Row {
        id: strip
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        spacing: root.gap

        Repeater {
            model: root.wsList

            delegate: Item {
                id: tile
                required property var modelData

                readonly property int wsId: tile.modelData.id
                readonly property bool active: tile.wsId === root.activeWsId
                readonly property bool hot: root.dragging && root.dragTargetWs === tile.wsId && tile.wsId !== root.dragSrcWs

                width: root.tileW
                height: root.labelH + root.tileH

                // Windows on this workspace as fraction-of-monitor rects.
                readonly property var cards: {
                    var out = [];
                    if (!root.mon)
                        return out;
                    var tl = Hyprland.toplevels.values;
                    for (var i = 0; i < tl.length; i++) {
                        var t = tl[i];
                        var o = t && t.lastIpcObject;
                        if (!t || !t.workspace || t.workspace.id !== tile.wsId)
                            continue;
                        if (!o || !o.at || !o.size || o.mapped === false)
                            continue;
                        out.push({
                            addr: t.address, tl: t,
                            fx: Math.max(0, Math.min(0.97, (o.at[0] - root.monX) / root.monLW)),
                            fy: Math.max(0, Math.min(0.97, (o.at[1] - root.monY) / root.monLH)),
                            fw: Math.max(0.05, Math.min(1, o.size[0] / root.monLW)),
                            fh: Math.max(0.05, Math.min(1, o.size[1] / root.monLH))
                        });
                    }
                    return out;
                }

                Text {
                    id: wsLabel
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.leftMargin: 1 * root.s
                    text: tile.wsId
                    color: tile.active ? Theme.brand : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: wsLabel.verticalCenter
                    anchors.rightMargin: 1 * root.s
                    visible: tile.cards.length > 0
                    text: tile.cards.length
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.Medium
                }

                // Switch-to-workspace on the tile body; the cards above grab
                // their own presses, so only empty space falls through to here.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchWs(tile.wsId)
                }

                Rectangle {
                    id: minimap
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: root.tileH
                    radius: Motion.rTile * root.s
                    color: tile.active ? Qt.alpha(Theme.brand, 0.12) : Theme.cardBot
                    border.width: 1
                    border.color: tile.hot ? Theme.brand
                        : (tile.active ? Theme.frameBorder : Theme.border)
                    clip: true

                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                    Text {
                        anchors.centerIn: parent
                        visible: tile.cards.length === 0
                        text: "empty"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 9 * root.s
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.2 * root.s
                    }

                    Repeater {
                        model: tile.cards

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property string addr: card.modelData.addr

                            x: card.modelData.fx * minimap.width
                            y: card.modelData.fy * minimap.height
                            width: Math.max(16 * root.s, card.modelData.fw * minimap.width)
                            height: Math.max(14 * root.s, card.modelData.fh * minimap.height)
                            radius: 5 * root.s
                            color: ma.containsMouse ? Theme.frameBg : Theme.tileBg
                            border.width: 1
                            border.color: ma.containsMouse ? Theme.brand : Theme.border
                            antialiasing: true
                            // Fade the carried window in place while it is dragged.
                            opacity: (root.dragging && card.addr === root.dragAddr) ? 0.3 : 1

                            Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                            Behavior on opacity { NumberAnimation { duration: Motion.fast } }

                            Image {
                                anchors.centerIn: parent
                                readonly property real box: Math.min(card.width, card.height) * 0.62
                                width: Math.max(10 * root.s, Math.min(24 * root.s, box))
                                height: width
                                sourceSize.width: Math.round(width * 2)
                                sourceSize.height: Math.round(width * 2)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                source: Apps.iconFor(card.modelData.tl)
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor

                                property real downX: 0
                                property real downY: 0
                                property bool armed: false

                                onPressed: (m) => {
                                    ma.armed = true;
                                    ma.downX = m.x;
                                    ma.downY = m.y;
                                }
                                onPositionChanged: (m) => {
                                    if (!ma.armed)
                                        return;
                                    if (!root.dragging) {
                                        if (Math.abs(m.x - ma.downX) + Math.abs(m.y - ma.downY) < 6 * root.s)
                                            return;
                                        root.dragging = true;
                                        root.dragAddr = card.addr;
                                        root.dragSrcWs = tile.wsId;
                                        root.dragTl = card.modelData.tl;
                                    }
                                    var g = ma.mapToItem(dragLayer, m.x, m.y);
                                    root.dragX = g.x;
                                    root.dragY = g.y;
                                    var sp = ma.mapToItem(strip, m.x, m.y);
                                    root.dragTargetWs = root.tileAt(sp.x, sp.y);
                                }
                                onReleased: {
                                    if (root.dragging) {
                                        if (root.dragTargetWs !== root.noWs && root.dragTargetWs !== root.dragSrcWs)
                                            root.moveWindow(root.dragAddr, root.dragTargetWs);
                                        root.endDrag();
                                    } else if (ma.armed) {
                                        root.focusWindow(card.addr);
                                    }
                                    ma.armed = false;
                                }
                                onCanceled: {
                                    root.endDrag();
                                    ma.armed = false;
                                }
                            }
                        }
                    }
                }
            }
        }

        // Trailing tile: drag a window here to send it to a fresh workspace, or
        // click to create and switch to one.
        Item {
            id: addTile
            readonly property bool hot: root.dragging && root.dragTargetWs === root.newWsId
            width: root.tileW
            height: root.labelH + root.tileH

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: root.tileH
                radius: Motion.rTile * root.s
                color: addTile.hot ? Theme.frameBg : "transparent"
                border.width: 1
                border.color: addTile.hot ? Theme.brand : Theme.hair

                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                // A plus mark, drawn so the strip needs no extra glyph asset.
                Rectangle {
                    anchors.centerIn: parent
                    width: 15 * root.s
                    height: 2 * root.s
                    radius: height / 2
                    color: addTile.hot ? Theme.brand : Theme.faint
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 2 * root.s
                    height: 15 * root.s
                    radius: width / 2
                    color: addTile.hot ? Theme.brand : Theme.faint
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchWs(root.newWsId)
                }
            }
        }
    }

    // The carried window's ghost, riding above the strip and following the
    // cursor while a drag is in flight.
    Item {
        id: dragLayer
        anchors.fill: parent
        z: 50

        Rectangle {
            id: ghost
            visible: root.dragging
            width: 56 * root.s
            height: 42 * root.s
            x: root.dragX - width / 2
            y: root.dragY - height / 2
            radius: 7 * root.s
            color: Theme.frameBg
            border.width: 1
            border.color: Theme.brand
            antialiasing: true
            opacity: 0.96

            Image {
                anchors.centerIn: parent
                width: 26 * root.s
                height: 26 * root.s
                sourceSize.width: Math.round(width * 2)
                sourceSize.height: Math.round(height * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
                source: (root.dragging && root.dragTl) ? Apps.iconFor(root.dragTl) : ""
            }
        }
    }
}
