import QtQuick
import QtQuick.Effects

// Dark analytic drop-shadow for a widget pill, shown only in border-less style.
// Placed as a CHILD of the pill Rectangle: z:-1 renders it behind the parent,
// anchors.fill matches the pill, and the blur spreads outside the (unclipped)
// parent bounds. RectangularShadow is analytic — no offscreen FBO per pill,
// which is why it's safe at 144 Hz on this NVIDIA/Wayland setup (see P0).
RectangularShadow {
    required property var theme
    anchors.fill: parent
    radius: parent.radius
    visible: theme.styleShadow
    blur: 8
    spread: 0
    // cast away from the screen edge the bar sits on (down for a top bar, up for
    // a bottom bar) so the blur isn't tucked under the screen edge
    offset: Qt.vector2d(0, theme.barPosition === "bottom" ? -1 : 1)
    color: theme.pillShadow
    z: -1
}
