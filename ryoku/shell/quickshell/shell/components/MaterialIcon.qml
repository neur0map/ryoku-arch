import QtQuick
import shell.services

// Material Symbols Rounded ligature. The glyph name is the text and the
// variable axes carry fill. Shipped by ttf-material-symbols-variable.
Text {
    property real fill: 0

    font.family: "Material Symbols Rounded"
    font.weight: 500
    font.variableAxes: ({ "FILL": fill, "opsz": 20 })
    color: Theme.onSurfaceVariant
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
