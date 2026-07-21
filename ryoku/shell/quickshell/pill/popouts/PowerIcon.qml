import QtQuick
import Ryoku.Ui.Singletons

// A Material Symbols Rounded glyph for the power panel. Its own copy (not the
// pill's MaterialIcon) so it can carry the optical-size axis the panel wants.
// The ligature name is the text; the variable axes carry fill and optical size.
Text {
    property real fill: 0
    property int opsz: 24

    font.family: "Material Symbols Rounded"
    font.weight: 500
    font.variableAxes: ({ "FILL": fill, "opsz": opsz })
    color: Tokens.inkDim
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
