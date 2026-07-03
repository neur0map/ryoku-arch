pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "Singletons"

/**
 * One workspace as a scaled mini-desktop. A large Fraunces workspace numeral is
 * the identity (vermillion when active); windows sit at their real fractional
 * positions, each a LIVE ScreencopyView over an app-icon fallback. Every cell
 * carries a hard solid-black offset shadow (Ryoku brutalist depth, no blur), and
 * lifts on hover. Each window tile has a hover ✕ that closes just that window.
 * Click empty space to switch here; click a window to focus it; press-drag a
 * window onto another cell to move it. The trailing cell (wsId -1) is the "+"
 * that opens a fresh workspace. Tiles glide via Behaviors so a move/drop/reflow
 * animates instead of snapping.
 */
Item {
    id: cell

    property real s: 1
    property var ov: null
    property int wsId: -1
    property int idx: 0
    property bool selected: false
    property bool isAdd: false
    property bool full: true
    readonly property int targetWs: cell.isAdd ? (cell.ov ? cell.ov.newWsId : 0) : cell.wsId
    readonly property bool active: !!cell.ov && cell.wsId === cell.ov.activeWsId
    readonly property bool hot: !!cell.ov && cell.ov.dragging
        && cell.ov.dragTargetWs === cell.targetWs && cell.ov.dragTargetWs !== cell.ov.dragSrcWs
    property bool hovered: false
    readonly property bool lifted: cell.hovered || cell.hot || cell.selected || cell.active

    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

    // staggered entrance: each cell settles in a beat after the last.
    property bool appeared: false
    Timer {
        interval: 40 + cell.idx * 55
        running: !!cell.ov && cell.ov.active && cell.ov.dataReady && !cell.appeared
        repeat: false
        onTriggered: cell.appeared = true
    }
    opacity: cell.appeared ? 1 : 0
    scale: cell.appeared ? 1 : 0.92
    Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
    Behavior on scale { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }

    // windows on this ws as fraction-of-monitor rects (empty for the add cell).
    readonly property var cards: {
        var out = [];
        if (cell.isAdd || !cell.full || !cell.ov || !cell.ov.mon)
            return out;
        var tl = Hyprland.toplevels.values;
        for (var i = 0; i < tl.length; i++) {
            var t = tl[i];
            var o = t && t.lastIpcObject;
            if (!t || !t.workspace || t.workspace.id !== cell.wsId)
                continue;
            if (!o || !o.at || !o.size || o.mapped === false)
                continue;
            out.push({
                addr: o.address, tl: t, cls: (o.class || "").toLowerCase(),
                fx: cell.clamp((o.at[0] - cell.ov.monX) / cell.ov.monLW, 0, 0.98),
                fy: cell.clamp((o.at[1] - cell.ov.monY) / cell.ov.monLH, 0, 0.98),
                fw: cell.clamp(o.size[0] / cell.ov.monLW, 0.03, 1),
                fh: cell.clamp(o.size[1] / cell.ov.monLH, 0.03, 1)
            });
        }
        return out;
    }

    // distinct app icons open on this workspace (dedup by class, capped), for the
    // small roster under the number badge.
    readonly property var appIcons: {
        var seen = ({});
        var out = [];
        for (var i = 0; i < cell.cards.length && out.length < 6; i++) {
            var c = cell.cards[i].cls;
            if (!c || seen[c])
                continue;
            seen[c] = true;
            var e = DesktopEntries.heuristicLookup(c);
            var p = (e && e.icon) ? Quickshell.iconPath(e.icon, true) : Quickshell.iconPath(c, true);
            if (p)
                out.push(p);
        }
        return out;
    }

    // hard offset shadow behind EVERY cell (solid black, no blur; the depth is
    // the offset, per docs/ui-ux.md). Deepens as the cell lifts.
    Rectangle {
        x: cell.lifted ? 10 * cell.s : 7 * cell.s
        y: cell.lifted ? 10 * cell.s : 7 * cell.s
        width: mini.width
        height: mini.height
        radius: Theme.radius
        color: Theme.shadow
        opacity: cell.active ? 0.9 : (cell.lifted ? 0.8 : 0.6)
        antialiasing: false
        Behavior on x { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on opacity { NumberAnimation { duration: Motion.fast } }
    }

    Rectangle {
        id: mini
        anchors.fill: parent
        radius: Theme.radius
        color: cell.active ? Qt.alpha(Theme.brand, 0.08) : Theme.cardBot
        border.width: (cell.active || cell.hot || cell.selected) ? 2 : 1
        border.color: cell.hot ? Theme.brand
            : cell.active ? Theme.brand
            : cell.selected ? Theme.vermLit
            : cell.hovered ? Theme.frameBorder
            : Theme.border
        clip: true

        Behavior on border.color { ColorAnimation { duration: Motion.highlight } }
        Behavior on color { ColorAnimation { duration: Motion.highlight } }

        // Ryoku-style workspace numeral: a bold zero-padded mono ordinal in the
        // top-left, vermillion when active/hovered (mirrors the Hub ThemeTile).
        // Above the previews (z), on a faint chip so it reads over any window.
        Rectangle {
            id: numChip
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 8 * cell.s
            visible: !cell.isAdd && cell.full
            width: numText.implicitWidth + 12 * cell.s
            height: numText.implicitHeight + 5 * cell.s
            radius: Theme.radius
            color: Qt.rgba(0, 0, 0, 0.5)
            border.width: 1
            border.color: cell.active ? Theme.brand : Theme.hair
            z: 3
            Behavior on border.color { ColorAnimation { duration: Motion.highlight } }
            Text {
                id: numText
                anchors.centerIn: parent
                // position within the desktop (ws11 on desktop 2 reads "01"), so
                // every desktop counts its own 01, 02, 03... Ryoku-style padded.
                readonly property int pos: cell.ov ? (((cell.wsId - 1) % cell.ov.perDesktop) + 1) : cell.wsId
                text: (numText.pos < 10 ? "0" : "") + numText.pos
                color: (cell.active || cell.hovered) ? Theme.brand : Theme.cream
                font.family: Theme.mono
                font.pixelSize: 22 * cell.s
                font.weight: Font.DemiBold
                Behavior on color { ColorAnimation { duration: Motion.highlight } }
            }
        }

        // app-icon roster: the distinct apps open on this workspace, drawn small
        // (below the number badge, smaller than it) as a quick glance of what
        // lives here beyond the live previews.
        Row {
            anchors.top: numChip.bottom
            anchors.left: numChip.left
            anchors.topMargin: 6 * cell.s
            spacing: 5 * cell.s
            visible: !cell.isAdd && cell.full && cell.cards.length > 0
            z: 3
            Repeater {
                model: cell.appIcons
                delegate: Rectangle {
                    id: appIco
                    required property var modelData
                    width: 22 * cell.s
                    height: 22 * cell.s
                    radius: Theme.radius
                    color: Qt.rgba(0, 0, 0, 0.5)
                    border.width: 1
                    border.color: Theme.hair
                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 15 * cell.s
                        source: appIco.modelData
                    }
                }
            }
        }

        // thin-slat identity: an empty/gap workspace shows just its number,
        // centered. The slat keeps the gap visible + reachable (click/drop
        // creates it) without a full preview cell's footprint.
        Text {
            anchors.centerIn: parent
            visible: !cell.isAdd && !cell.full
            readonly property int pos: cell.ov ? (((cell.wsId - 1) % cell.ov.perDesktop) + 1) : cell.wsId
            text: (pos < 10 ? "0" : "") + pos
            color: (cell.active || cell.hovered || cell.selected) ? Theme.brand : Theme.faint
            font.family: Theme.mono
            font.pixelSize: 19 * cell.s
            font.weight: Font.DemiBold
            Behavior on color { ColorAnimation { duration: Motion.highlight } }
        }

        // "EMPTY" note for a windowless workspace.
        Text {
            anchors.centerIn: parent
            visible: !cell.isAdd && cell.full && cell.cards.length === 0
            text: "EMPTY"
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10 * cell.s
            font.letterSpacing: 2 * cell.s
        }

        // click empty space -> switch here (windows above capture their own).
        MouseArea {
            anchors.fill: parent
            visible: !cell.isAdd
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: cell.hovered = true
            onExited: cell.hovered = false
            onClicked: if (cell.ov) cell.ov.switchWs(cell.wsId)
        }

        // ---- live window tiles ----
        Repeater {
            model: cell.cards
            delegate: Rectangle {
                id: tile
                required property var modelData
                readonly property string addr: tile.modelData.addr

                x: tile.modelData.fx * mini.width
                y: tile.modelData.fy * mini.height
                width: Math.max(20 * cell.s, tile.modelData.fw * mini.width)
                height: Math.max(16 * cell.s, tile.modelData.fh * mini.height)
                radius: Theme.radius
                color: Theme.tileBg
                border.width: (tileMa.containsMouse || closeMa.containsMouse) ? 2 : 1
                border.color: (tileMa.containsMouse || closeMa.containsMouse) ? Theme.brand : Theme.hair
                antialiasing: true
                clip: true
                z: (tileMa.containsMouse || closeMa.containsMouse) ? 2 : 1
                // fade the carried window in place while it is being dragged.
                opacity: (cell.ov && cell.ov.dragging && tile.addr === cell.ov.dragAddr) ? 0.22 : 1

                // glide when the model reflows (a move/drop rearranges tiles).
                // enabled only after entrance, so the first layout doesn't slide
                // every tile in from the corner.
                Behavior on x { enabled: cell.appeared; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
                Behavior on y { enabled: cell.appeared; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
                Behavior on width { enabled: cell.appeared; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
                Behavior on height { enabled: cell.appeared; NumberAnimation { duration: Motion.standard; easing.type: Motion.easeExpo } }
                Behavior on border.color { ColorAnimation { duration: Motion.highlight } }
                Behavior on opacity { NumberAnimation { duration: Motion.highlight } }

                // icon fallback, beneath the live capture.
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Math.max(16 * cell.s, Math.min(48 * cell.s, Math.min(tile.width, tile.height) * 0.5))
                    source: {
                        var c = tile.modelData.cls;
                        var e = c ? DesktopEntries.heuristicLookup(c) : null;
                        var p = (e && e.icon) ? Quickshell.iconPath(e.icon, true) : "";
                        if (!p && c)
                            p = Quickshell.iconPath(c, true);
                        return p;
                    }
                }

                // the live window texture (covers the icon once it captures).
                ScreencopyView {
                    anchors.fill: parent
                    captureSource: tile.modelData.tl ? tile.modelData.tl.wayland : null
                    live: true
                    visible: (tile.modelData.tl && tile.modelData.tl.wayland) !== null
                }

                MouseArea {
                    id: tileMa
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    property real downX: 0
                    property real downY: 0
                    property bool armed: false

                    onPressed: (m) => { tileMa.armed = true; tileMa.downX = m.x; tileMa.downY = m.y; }
                    onPositionChanged: (m) => {
                        if (!tileMa.armed || !cell.ov)
                            return;
                        if (!cell.ov.dragging) {
                            if (Math.abs(m.x - tileMa.downX) + Math.abs(m.y - tileMa.downY) < 7 * cell.s)
                                return;
                            cell.ov.dragging = true;
                            cell.ov.dragAddr = tile.addr;
                            cell.ov.dragSrcWs = cell.wsId;
                            cell.ov.dragTl = tile.modelData.tl ? tile.modelData.tl.wayland : null;
                        }
                        var rp = tileMa.mapToItem(cell.ov, m.x, m.y);
                        cell.ov.updateDrag(rp.x, rp.y);
                    }
                    onReleased: {
                        if (cell.ov && cell.ov.dragging) {
                            cell.ov.commitDrop();
                            cell.ov.endDrag();
                        } else if (tileMa.armed && cell.ov) {
                            cell.ov.focusWindow(tile.modelData.tl, tile.addr);
                        }
                        tileMa.armed = false;
                    }
                    onCanceled: { if (cell.ov) cell.ov.endDrag(); tileMa.armed = false; }
                }

                // hover ✕ close, top-right. Above tileMa, so it eats its own click.
                Rectangle {
                    id: closeBtn
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 3 * cell.s
                    width: 18 * cell.s
                    height: 18 * cell.s
                    radius: Theme.radius
                    visible: (tileMa.containsMouse || closeMa.containsMouse) && !(cell.ov && cell.ov.dragging)
                    color: closeMa.containsMouse ? Theme.brand : Qt.rgba(0, 0, 0, 0.72)
                    border.width: 1
                    border.color: closeMa.containsMouse ? Theme.brand : Theme.frameBorder
                    Text {
                        anchors.centerIn: parent
                        text: "\u2715"
                        color: closeMa.containsMouse ? Theme.bright : Theme.cream
                        font.family: Theme.mono
                        font.pixelSize: 11 * cell.s
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (cell.ov) cell.ov.closeWindow(tile.modelData.tl, tile.addr)
                    }
                }
            }
        }

        // ---- the "+" add cell ----
        Item {
            anchors.fill: parent
            visible: cell.isAdd
            Rectangle {
                anchors.centerIn: parent
                width: 26 * cell.s; height: 3 * cell.s; radius: height / 2
                color: cell.hot || cell.hovered ? Theme.brand : Theme.faint
                Behavior on color { ColorAnimation { duration: Motion.highlight } }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 3 * cell.s; height: 26 * cell.s; radius: width / 2
                color: cell.hot || cell.hovered ? Theme.brand : Theme.faint
                Behavior on color { ColorAnimation { duration: Motion.highlight } }
            }
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: cell.hovered = true
                onExited: cell.hovered = false
                onClicked: if (cell.ov) cell.ov.switchWs(cell.ov.newWsId)
            }
        }
    }
}
