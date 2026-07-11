import QtQuick
import "Singletons"

// The walkthrough's CTA. Three kinds, the website's AppLinkButton family:
//   solid   — a vermillion block with a hard black offset shadow (the primary act)
//   outline — a hairline chip whose border warms to ember on hover
//   ghost   — label only, dims->brightens (Skip, tertiary)
// Mono uppercase label, wide tracking: the technical/poster voice.
Item {
    id: btn

    property string label: ""
    property string kind: "outline"   // solid | outline | ghost
    signal clicked()

    readonly property bool solid: kind === "solid"
    readonly property bool ghost: kind === "ghost"

    implicitWidth: label_.implicitWidth + (ghost ? 20 : 36)
    implicitHeight: ghost ? 30 : 40

    opacity: enabled ? 1 : 0.4
    scale: tap.pressed && btn.enabled ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }

    // hard brutalist offset shadow, solid kind only.
    Rectangle {
        visible: btn.solid
        x: Theme.shadowStep
        y: Theme.shadowStep
        width: face.width
        height: face.height
        radius: Theme.radiusChip
        color: Theme.shadow
        antialiasing: false
    }

    Rectangle {
        id: face
        anchors.fill: parent
        radius: Theme.radiusChip
        color: btn.solid ? (hover.hovered ? Theme.ember : Theme.brand)
             : btn.ghost ? "transparent"
             : (hover.hovered ? Theme.frameBg : "transparent")
        border.width: btn.ghost ? 0 : 1
        border.color: btn.solid ? Theme.brand
             : (hover.hovered ? Theme.ember : Theme.line)
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
    }

    Text {
        id: label_
        anchors.centerIn: parent
        text: btn.label
        color: btn.solid ? Theme.onAccent
             : btn.ghost ? (hover.hovered ? Theme.cream : Theme.dim)
             : (hover.hovered ? Theme.bright : Theme.cream)
        font.family: Theme.mono
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.letterSpacing: 1.6
        font.capitalization: Font.AllUppercase
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    HoverHandler { id: hover; enabled: btn.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; enabled: btn.enabled; onTapped: btn.clicked() }
}
