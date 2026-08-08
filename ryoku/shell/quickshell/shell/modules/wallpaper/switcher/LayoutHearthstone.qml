pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Wall hand: the wallpapers dealt as a fan of cards, Hearthstone-style. Portrait
// cards splay along a shallow arc, each pivoting from its bottom edge so the tops
// spread wider than the feet; the centre card sits upright at the front, lifted
// and scaled up as the pick, while neighbours rotate out, slide along the pitch
// and recede down the curve into the dark with distance. A wheel flick or the
// arrows deal the focused card to centre-front (host drives selIndex; every card
// glides its rotation/x/y/scale over OutCubic). Cells reuse WallCell / ThemeCell,
// so live previews, the on-air dot and the seal-lift border ride along for free.
Item {
    id: hand

    required property real s
    required property var model
    required property string kind            // "wall" | "theme"
    required property color bg
    property int selIndex: 0
    property bool active: true
    property string activeKey: ""
    property bool interactive: true
    signal focusIndex(int i)
    signal chosen(int i)

    readonly property int count: model ? model.length : 0

    // ── card geometry: portrait cards sized off the stage, detail off s ──
    readonly property real cardH: Math.round(height * 0.46)
    readonly property real cardW: Math.round(cardH * 0.68)
    readonly property real focusScale: 1.24                       // centre card front-and-up
    readonly property real focusLift: Math.round(cardH * 0.16)
    readonly property real stepX: Math.round(cardW * 0.55)        // pitch along the fan
    readonly property real spreadDeg: 6.0                         // per-card angle step
    readonly property real arcRadius: Math.round(height * 0.72)   // curve radius; larger = flatter
    readonly property int maxSide: 5                              // cards shown each side of centre

    // depth of a card's drop down the arc, from its angle off the apex.
    function arcDrop(rel) {
        return Math.round(hand.arcRadius * (1 - Math.cos(rel * hand.spreadDeg * Math.PI / 180)));
    }

    // ── deal motion gate: cards are sliding for one ease after a focus change,
    // which holds live video off (beltMoving) until the hand settles ──
    property bool moving: false
    onSelIndexChanged: { hand.moving = true; settle.restart(); }
    Timer { id: settle; interval: Motion.beltEase; onTriggered: hand.moving = false }

    // wheel deals the next / previous card to centre-front.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            if (hand.count <= 1) return;
            var dir = e.angleDelta.y < 0 ? 1 : -1;
            var next = Math.max(0, Math.min(hand.count - 1, hand.selIndex + dir));
            if (next !== hand.selIndex) hand.focusIndex(next);
        }
    }

    // ── pointer-move gate: only a real cursor move focuses a card, so a card
    // sliding under a still cursor never fights the arrow keys ──
    property bool pointerLive: false
    property point hoverPt: areaHover.point.position
    onHoverPtChanged: { hand.pointerLive = true; pointerCool.restart(); }
    HoverHandler { id: areaHover }
    Timer { id: pointerCool; interval: 130; onTriggered: hand.pointerLive = false }

    Repeater {
        model: hand.model
        delegate: Item {
            id: card
            required property int index
            required property var modelData
            readonly property int rel: index - hand.selIndex          // signed distance from centre
            readonly property int ad: Math.abs(rel)
            readonly property bool focused: rel === 0
            readonly property bool near: ad <= hand.maxSide

            visible: near
            width: hand.cardW
            height: hand.cardH
            transformOrigin: Item.Bottom
            // bottoms rest near the hand's floor; centre lifts, off-cards drop the arc.
            x: (hand.width - hand.cardW) / 2 + rel * hand.stepX
            y: (hand.height - hand.cardH) + card.arcY - (focused ? hand.focusLift : 0)
            readonly property real arcY: hand.arcDrop(rel)
            rotation: rel * hand.spreadDeg
            scale: focused ? hand.focusScale : 1
            z: focused ? 1000 : 500 - card.ad
            opacity: near ? 1 : 0

            Behavior on x        { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on y        { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on rotation { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on scale    { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on opacity  { NumberAnimation { duration: 200 } }

            Loader {
                anchors.fill: parent
                sourceComponent: hand.kind === "theme" ? themeC : wallC
            }
            Component {
                id: wallC
                WallCell {
                    s: hand.s; item: card.modelData; bg: hand.bg
                    selected: card.focused
                    live: card.visible
                    beltMoving: hand.moving
                    onEntered: if (hand.pointerLive) hand.focusIndex(card.index)
                    onChosen: hand.chosen(card.index)
                }
            }
            Component {
                id: themeC
                ThemeCell {
                    s: hand.s; item: card.modelData; bg: hand.bg
                    selected: card.focused
                    active: !!card.modelData && card.modelData.id === hand.activeKey
                    interactive: hand.interactive
                    onEntered: if (hand.pointerLive) hand.focusIndex(card.index)
                    onChosen: hand.chosen(card.index)
                }
            }

            // recede the off-centre cards into the dark, depth by distance.
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusWidget
                color: "black"
                opacity: card.focused ? 0 : Math.min(0.55, 0.16 + card.ad * 0.09)
                Behavior on opacity { NumberAnimation { duration: Motion.beltEase } }
            }
        }
    }

    // red seal brushed beneath the front card, marking the pick.
    Rectangle {
        visible: hand.count > 0
        width: hand.cardW * hand.focusScale * 0.66
        height: Math.max(2, Math.round(3 * hand.s))
        x: (hand.width - width) / 2
        y: hand.height - hand.focusLift + Math.round(9 * hand.s)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(Theme.seal, 0) }
            GradientStop { position: 0.5; color: Theme.seal }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.seal, 0) }
        }
    }
}
