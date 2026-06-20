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
    // The next free workspace id, the drop target of the trailing "+" tile.
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
                property bool hot: false

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

                // Switch-to-workspace on the tile body; the cards above catch
                // their own clicks, so only empty space falls through to here.
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

                        delegate: Item {
                            id: slot
                            required property var modelData
                            readonly property string addr: slot.modelData.addr
                            readonly property int srcWs: tile.wsId

                            x: slot.modelData.fx * minimap.width
                            y: slot.modelData.fy * minimap.height
                            width: Math.max(16 * root.s, slot.modelData.fw * minimap.width)
                            height: Math.max(14 * root.s, slot.modelData.fh * minimap.height)

                            Rectangle {
                                id: card
                                width: slot.width
                                height: slot.height
                                radius: 5 * root.s
                                color: ma.containsMouse ? Theme.frameBg : Theme.tileBg
                                border.width: 1
                                border.color: ma.containsMouse ? Theme.brand : Theme.border
                                antialiasing: true

                                Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                                Drag.active: ma.drag.active
                                Drag.keys: ["win"]
                                Drag.source: slot
                                Drag.hotSpot.x: card.width / 2
                                Drag.hotSpot.y: card.height / 2

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
                                    source: Apps.iconFor(slot.modelData.tl)
                                }

                                // Lift the card out of its clipped tile while
                                // dragging so it rides over the whole strip.
                                states: State {
                                    name: "drag"
                                    when: ma.drag.active
                                    ParentChange { target: card; parent: dragLayer }
                                }

                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    drag.target: card
                                    drag.threshold: 4
                                    onClicked: root.focusWindow(slot.addr)
                                }
                            }
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["win"]
                    onEntered: tile.hot = true
                    onExited: tile.hot = false
                    onDropped: (drop) => {
                        tile.hot = false;
                        if (drop.source && drop.source.srcWs !== tile.wsId)
                            root.moveWindow(drop.source.addr, tile.wsId);
                    }
                }
            }
        }

        // Trailing tile: drop a window here to send it to a fresh workspace, or
        // click to create and switch to one.
        Item {
            id: addTile
            property bool hot: false
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

            DropArea {
                anchors.fill: parent
                keys: ["win"]
                onEntered: addTile.hot = true
                onExited: addTile.hot = false
                onDropped: (drop) => {
                    addTile.hot = false;
                    if (drop.source)
                        root.moveWindow(drop.source.addr, root.newWsId);
                }
            }
        }
    }

    // Cards reparent here mid-drag so they ride above every tile, unclipped.
    Item {
        id: dragLayer
        anchors.fill: parent
    }
}
