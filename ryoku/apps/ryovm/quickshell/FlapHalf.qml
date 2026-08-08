import QtQuick
import Ryoku.Ui.Singletons

// Half of a split-flap character: the full glyph, hard-clipped to its upper or
// lower half. Positioned by FlapCell; knows nothing about the mechanism.
Item {
    id: half

    property string t: " "
    property bool upper: true
    property real cellW: 15
    property real cellH: 22
    property real fontPx: 13
    property color ink: Tokens.ink

    width: half.cellW
    height: half.cellH / 2
    clip: true

    Text {
        width: half.cellW
        height: half.cellH
        y: half.upper ? 0 : -half.cellH / 2
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: half.t
        color: half.ink
        font.family: Tokens.mono
        font.pixelSize: half.fontPx
        font.weight: Font.DemiBold
    }
}
