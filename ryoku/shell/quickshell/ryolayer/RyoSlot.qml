pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// One widget's frame on the board or on a pin window: the paper plate, the
// eyebrow title, the hover controls (pin, clickthrough, remove), the drag and
// the resize bracket. The body QML fills the plate and only ever reads `slot`.
Item {
    id: slot

    // the ryolayer.json entry this slot renders.
    property var entry: null
    // interaction only on the open board; a pinned window shows a static slot.
    property bool interactive: true
    property string screenName: ""
    property bool active: false

    readonly property var def: entry ? Catalog.byId(entry.id) : null

    width: entry ? entry.w : 0
    height: entry ? entry.h : 0
    x: entry && parent ? Math.round(entry.cx * parent.width - width / 2) : 0
    y: entry && parent ? Math.round(entry.cy * parent.height - height / 2) : 0

    function persistGeometry() {
        // a growth (requestHeight) can fire before the board is laid out; a
        // zero-size parent would divide the normalized center to NaN and land
        // null in ryolayer.json, so wait for a real layout before persisting.
        if (!slot.interactive || !entry || !parent || parent.width <= 0 || parent.height <= 0)
            return;
        Config.setGeometry(entry.id, slot.screenName,
                           (x + width / 2) / parent.width,
                           (y + height / 2) / parent.height,
                           width, height);
    }
    // a body panel (the EQ) may need more room than the user left it.
    function requestHeight(px) {
        if (!slot.interactive || !def)
            return;
        var target = Math.min(def.maxH, Math.max(px, height));
        if (target !== height) {
            height = target;
            persistGeometry();
        }
    }

    // IconBtn carries no engaged state, so a filled underlay marks a live
    // toggle rather than forking the shared button.
    component Ctl: Item {
        id: ctl
        property string glyph: ""
        property bool on: false
        signal act()
        implicitWidth: inner.implicitWidth
        implicitHeight: inner.implicitHeight
        Rectangle {
            anchors.fill: parent
            radius: Tokens.radius
            visible: ctl.on
            color: Tokens.tint16
            border { width: Tokens.border; color: Tokens.lineStrong }
        }
        IconBtn { id: inner; anchors.fill: parent; glyph: ctl.glyph; onAct: ctl.act() }
    }

    // ── plate ────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Tokens.paper
        radius: Tokens.radius
        border.width: Tokens.border
        border.color: hoverProbe.hovered ? Tokens.lineStrong : Tokens.line
    }
    Grain { anchors.fill: parent; opacity: Tokens.grainOpacity }

    // the plate keeps its own clicks; only the scrim behind dismisses the board.
    MouseArea { anchors.fill: parent }

    Row {
        id: eyebrow
        anchors { top: parent.top; left: parent.left; margins: Tokens.s3 }
        spacing: Tokens.s2
        Text {
            text: slot.def ? slot.def.kanji : ""
            color: Tokens.inkFaint
            font { family: Tokens.jp; pixelSize: Tokens.fMicro }
        }
        Text {
            text: slot.def ? slot.def.title : ""
            color: Tokens.inkFaint
            font { family: Tokens.mono; pixelSize: Tokens.fTiny; letterSpacing: Tokens.trackLabel }
        }
        Rectangle {
            width: Tokens.s1; height: Tokens.s1; radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: slot.entry && slot.entry.pinned ? Tokens.sun : "transparent"
            border { width: 1; color: Tokens.lineSoft }
        }
    }

    // body loads under the eyebrow.
    Loader {
        id: body
        anchors { fill: parent; topMargin: eyebrow.height + Tokens.s4; margins: Tokens.s3 }
        clip: true
        source: slot.def ? Qt.resolvedUrl(slot.def.source) : ""
        onLoaded: {
            item.slot = slot;
            item.active = Qt.binding(function () { return slot.active; });
        }
    }

    HoverHandler { id: hoverProbe }

    // ── hover controls (board only) ─────────────────────────────────────
    Row {
        anchors { top: parent.top; right: parent.right; margins: Tokens.s2 }
        spacing: Tokens.s1
        visible: slot.interactive && hoverProbe.hovered
        Ctl {
            glyph: "\u25cf"
            on: slot.entry ? slot.entry.pinned : false
            onAct: Config.setPinned(slot.entry.id, slot.screenName, !slot.entry.pinned)
        }
        Ctl {
            glyph: "\u25c9"
            visible: slot.entry ? slot.entry.pinned : false
            on: slot.entry ? !slot.entry.clickthrough : false
            onAct: Config.setClickthrough(slot.entry.id, slot.screenName, !slot.entry.clickthrough)
        }
        IconBtn {
            glyph: "\u2715"
            onAct: Config.remove(slot.entry.id, slot.screenName)
        }
    }

    // ── drag (grid-snapped) and resize bracket ───────────────────────────
    DragHandler {
        id: drag
        enabled: slot.interactive
        target: slot
        xAxis.minimum: 0
        xAxis.maximum: slot.parent ? slot.parent.width - slot.width : 0
        yAxis.minimum: 0
        yAxis.maximum: slot.parent ? slot.parent.height - slot.height : 0
        onActiveChanged: if (!active) {
            slot.x = Math.round(slot.x / Tokens.s2) * Tokens.s2;
            slot.y = Math.round(slot.y / Tokens.s2) * Tokens.s2;
            slot.persistGeometry();
        }
    }
    z: drag.active || sizeArea.pressed ? 2 : 1

    Item {
        id: bracket
        width: Tokens.s5; height: Tokens.s5
        anchors { right: parent.right; bottom: parent.bottom }
        visible: slot.interactive && (hoverProbe.hovered || sizeArea.pressed)
        // the corner tick pair, the desktop-widget resize affordance redrawn.
        Rectangle { anchors { right: parent.right; bottom: parent.bottom; margins: Tokens.s1 } width: Tokens.s3; height: Tokens.border; color: Tokens.lineStrong }
        Rectangle { anchors { right: parent.right; bottom: parent.bottom; margins: Tokens.s1 } width: Tokens.border; height: Tokens.s3; color: Tokens.lineStrong }
        MouseArea {
            id: sizeArea
            anchors.fill: parent
            cursorShape: Qt.SizeFDiagCursor
            property real pw: 0
            property real ph: 0
            property point origin
            onPressed: (e) => { pw = slot.width; ph = slot.height; origin = mapToItem(slot.parent, e.x, e.y); }
            onPositionChanged: (e) => {
                if (!pressed || !slot.def)
                    return;
                var now = mapToItem(slot.parent, e.x, e.y);
                slot.width = Math.max(slot.def.minW, Math.min(slot.def.maxW, pw + (now.x - origin.x)));
                slot.height = Math.max(slot.def.minH, Math.min(slot.def.maxH, ph + (now.y - origin.y)));
            }
            onReleased: slot.persistGeometry()
        }
    }

    Behavior on x { enabled: !drag.active; NumberAnimation { duration: Motion.settle; easing.type: Motion.easeStandard } }
    Behavior on y { enabled: !drag.active; NumberAnimation { duration: Motion.settle; easing.type: Motion.easeStandard } }
    Behavior on height { enabled: !sizeArea.pressed; NumberAnimation { duration: Motion.settle; easing.type: Motion.easeStandard } }
}
