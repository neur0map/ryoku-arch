pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "Singletons"

/**
 * Desktop placement frame for one plugin widget on the wallpaper layer. Measures
 * its plugin content's natural size, pads it, draws an optional card/glass
 * backing with a soft lift, and carries drag-to-move (snapped to a grid). The
 * free position persists to the user's plugins.json via the host. Mirrors the
 * desktop widgets' WidgetSlot idiom so plugin tiles feel identical to the shipped
 * clock/weather widgets.
 */
Item {
    id: slot

    property string pluginId: ""
    property real freeX: 80
    property real freeY: 80
    property real pad: 18
    property string bg: "card"            // none | card | glass
    property real radius: 16
    property real gridSize: 32

    signal moved(real x, real y)

    default property alias content: holder.data

    readonly property Item item: holder.children.length > 0 ? holder.children[0] : null
    readonly property real cw: slot.item ? slot.item.implicitWidth : 100
    readonly property real ch: slot.item ? slot.item.implicitHeight : 100

    property bool dragging: false
    property real dragX: 0
    property real dragY: 0

    width: Math.max(1, slot.cw + slot.pad * 2)
    height: Math.max(1, slot.ch + slot.pad * 2)

    function clampX(v) { return Math.max(0, Math.min(v, (slot.parent ? slot.parent.width : v + slot.width) - slot.width)); }
    function clampY(v) { return Math.max(0, Math.min(v, (slot.parent ? slot.parent.height : v + slot.height) - slot.height)); }
    function snap(v) { return Math.round(v / slot.gridSize) * slot.gridSize; }

    x: slot.dragging ? slot.dragX : slot.clampX(slot.freeX)
    y: slot.dragging ? slot.dragY : slot.clampY(slot.freeY)
    Behavior on x { enabled: !slot.dragging; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: !slot.dragging; NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

    scale: slot.dragging ? 1.03 : 1.0
    transformOrigin: Item.Center
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutExpo } }

    MultiEffect {
        source: backing
        anchors.fill: backing
        visible: slot.bg !== "none"
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.5)
        shadowBlur: 1.0
        shadowVerticalOffset: 6
        blurMax: 32
        autoPaddingEnabled: true
    }

    Rectangle {
        id: backing
        anchors.fill: parent
        visible: slot.bg !== "none"
        radius: slot.radius
        color: slot.bg === "card" ? Theme.cardTop : Qt.rgba(16 / 255, 16 / 255, 24 / 255, 0.26)
        border.width: 1
        border.color: Theme.hair
    }

    Item {
        id: holder
        x: slot.pad
        y: slot.pad
        width: slot.cw
        height: slot.ch
    }

    MouseArea {
        id: grip
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        cursorShape: slot.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property bool down: false
        property real grabOX: 0
        property real grabOY: 0
        onPressed: (mouse) => {
            grip.down = true;
            const p = slot.mapToItem(slot.parent, mouse.x, mouse.y);
            grip.grabOX = p.x - slot.x;
            grip.grabOY = p.y - slot.y;
        }
        onPositionChanged: (mouse) => {
            if (!grip.down) return;
            const p = slot.mapToItem(slot.parent, mouse.x, mouse.y);
            const nx = p.x - grip.grabOX;
            const ny = p.y - grip.grabOY;
            if (!slot.dragging) {
                if (Math.abs(nx - slot.x) < 6 && Math.abs(ny - slot.y) < 6) return;
                slot.dragging = true;
            }
            slot.dragX = slot.clampX(slot.snap(nx));
            slot.dragY = slot.clampY(slot.snap(ny));
        }
        onReleased: () => {
            if (slot.dragging) {
                slot.moved(Math.round(slot.dragX), Math.round(slot.dragY));
                slot.dragging = false;
            }
            grip.down = false;
        }
    }
}
