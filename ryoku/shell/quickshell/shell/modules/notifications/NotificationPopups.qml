pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import shell.services

// Notification popup surface (contract 07 sec 1/2.4, sec 8; contract 12 sec 1).
// A per-monitor overlay layer surface anchored to the top edge, on the left or
// right (or centred) per the position setting, reserving nothing (exclusive
// zone 0) and never taking keyboard focus. It holds the flat, newest-first popup
// list (newest at index 0) at a fixed 400 px content width with 14 px between
// cards, floating 16 px off the corner. Each card grows out of the anchored top
// corner (scale + fade, Motion.notifIn) and recedes back into it on close
// (Motion.notifOut). When the list empties the surface unmaps 260 ms later
// (Motion.notifHide), letting the last exit finish first; a popup arriving in
// that wait cancels the unmap.
//
// `Notifs.popups` is reassigned as a whole array on every change, which resets a
// plain view (no per-item add/remove animation). A local `cards` ListModel is
// reconciled against it incrementally so the ListView's add/remove/displaced
// transitions actually fire per card.
PanelWindow {
    id: win

    required property var modelData
    // Fixed logical px: content width 400, inter-card spacing 14, corner float
    // 16. The reference container is a fixed-size window that does not grow with
    // monitor or font scale, so no scale term.

    // Popup anchoring (contract 07 sec 7): Left -> top+left, Right (default) ->
    // top+right, Center -> top only (horizontally centred). The live setting is
    // notifications.notification_position (contract 14, owned by the settings
    // slice); it defaults to Right, the reference default, until that key lands.
    property string position: "Right"
    // popup_window_margins (contract 07 sec 8), default 0.
    property real margin: 0

    // Base breathing room off the screen corner, on top of the configurable
    // popup margin, so the toast column floats instead of sitting flush.
    readonly property real inset: 16

    // How far off its own edge a card starts and leaves. Centred popups have no
    // edge to come from, so they only fade.
    readonly property real slideFrom: position === "Left" ? -implicitWidth
        : position === "Center" ? 0 : implicitWidth

    readonly property var popups: Notifs.popups
    property bool mapped: false

    screen: modelData
    visible: mapped && Config.barStyle !== "nacre"
    color: "transparent"
    // Exclusive zone 0: reserve nothing, respect other layers' zones (contract
    // 12 sec 1). ExclusionMode.Ignore would request -1 instead.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-notifications"

    anchors.top: true
    anchors.left: position === "Left"
    anchors.right: position === "Right"
    margins.top: inset + margin
    margins.left: inset + margin
    margins.right: inset + margin

    implicitWidth: 400
    implicitHeight: Math.max(1, list.contentHeight)
    // Only follow the height once cards are already up: growing from nothing
    // wiped the first toast open top-down, which read as the card unrolling
    // rather than arriving. With cards present the ease still keeps a leaving
    // one from being clipped by the surface shrinking under it.
    Behavior on implicitHeight {
        enabled: cards.count > 1
        NumberAnimation { duration: Motion.rowReveal; easing.type: Motion.rowRevealCurve }
    }

    // Newest-first card view, reconciled from Notifs.popups by id.
    ListModel { id: cards }

    function indexOfId(id) {
        for (var i = 0; i < cards.count; i++)
            if (cards.get(i).nid === id)
                return i;
        return -1;
    }
    function sync() {
        var incoming = win.popups;
        // Drop cards whose notification is gone (this triggers the remove slide).
        for (var i = cards.count - 1; i >= 0; i--) {
            var id = cards.get(i).nid;
            var keep = false;
            for (var k = 0; k < incoming.length; k++)
                if (incoming[k].id === id) { keep = true; break; }
            if (!keep)
                cards.remove(i);
        }
        // Insert new cards and reorder to match the newest-first incoming order.
        for (var j = 0; j < incoming.length; j++) {
            var p = incoming[j];
            var cur = win.indexOfId(p.id);
            if (cur < 0)
                cards.insert(j, { nid: p.id, entry: p });
            else if (cur !== j)
                cards.move(cur, j, 1);
        }
    }

    // Map immediately on the first popup; unmap 260 ms after the list empties,
    // re-checking emptiness so a popup arriving during the wait cancels it.
    // Map before the first card lands. A ListView does not animate its initial
    // population, so syncing in the same frame the surface maps skipped the
    // arrival entirely and left the window resize as the only motion.
    onPopupsChanged: {
        if (popups.length > 0) {
            unmapTimer.stop();
            if (!mapped) {
                mapped = true;
                Qt.callLater(win.sync);
                return;
            }
        } else {
            unmapTimer.restart();
        }
        sync();
    }
    Component.onCompleted: {
        sync();
        mapped = popups.length > 0;
    }

    Timer {
        id: unmapTimer
        interval: Motion.notifHide
        onTriggered: if (win.popups.length === 0) win.mapped = false
    }

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: contentHeight
        spacing: 14
        interactive: false
        model: cards

        // Corner grow (contract 12 sec 5, eye-candy pass): a new card fades and
        // scales up from the anchored corner (transformOrigin set on the card);
        // siblings slide down to fill. A leaving card fades and scales back into
        // the corner. displaced restores opacity and scale, so a card interrupted
        // mid-arrival by a newer one still settles solid and in place, never left
        // half-faded or overlapping. The 260 ms unmap delay outlasts the exit.
        add: Transition {
            NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: Motion.notifIn; easing.type: Motion.easeType; easing.bezierCurve: Motion.notifInCurve }
            NumberAnimation { property: "x"; from: win.slideFrom; to: 0; duration: Motion.notifIn; easing.type: Motion.easeType; easing.bezierCurve: Motion.notifInCurve }
        }
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: Motion.notifIn; easing.type: Motion.easeType; easing.bezierCurve: Motion.notifInCurve }
            NumberAnimation { properties: "opacity"; to: 1; duration: Motion.notifIn; easing.type: Motion.easeType; easing.bezierCurve: Motion.notifInCurve }
            NumberAnimation { property: "x"; to: 0; duration: Motion.notifIn; easing.type: Motion.easeType; easing.bezierCurve: Motion.notifInCurve }
        }
        remove: Transition {
            NumberAnimation { properties: "opacity"; to: 0; duration: Motion.notifOut; easing.type: Motion.notifOutCurve }
            NumberAnimation { property: "x"; to: win.slideFrom; duration: Motion.notifOut; easing.type: Motion.notifOutCurve }
        }
        removeDisplaced: Transition {
            NumberAnimation { properties: "y"; duration: Motion.notifIn; easing.type: Motion.easeType; easing.bezierCurve: Motion.notifInCurve }
            NumberAnimation { properties: "opacity"; to: 1; duration: Motion.notifIn; easing.type: Motion.easeType; easing.bezierCurve: Motion.notifInCurve }
            NumberAnimation { property: "x"; to: 0; duration: Motion.notifIn; easing.type: Motion.easeType; easing.bezierCurve: Motion.notifInCurve }
        }

        delegate: NotificationCard {
            required property var entry
            width: ListView.view ? ListView.view.width : implicitWidth
            notif: entry
            // Popups are compact and expand on demand; the grow/collapse scales
            // about the anchored corner (top-right, top-left or top-centre).
            compact: true
            transformOrigin: win.position === "Left" ? Item.TopLeft
                : win.position === "Center" ? Item.Top : Item.TopRight
            // The popup drains its countdown frame over its own display lifespan;
            // a persistent popup (ttl -1) passes 0 and draws no frame.
            lifespanMs: { const t = Notifs.popupTtl(entry); return t < 0 ? 0 : t; }
            // The popup has no menu to close, so it ignores actionInvoked.
        }
    }
}
