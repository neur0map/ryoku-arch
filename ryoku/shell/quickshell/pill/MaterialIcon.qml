import QtQuick
import "Singletons"

// a Material Symbols Rounded glyph, the caelestia icon idiom: the ligature
// name is the text ("calendar_month", "wifi", "power_settings_new") and the
// variable axes carry fill. ships via ttf-material-symbols-variable.
Text {
    property real fill: 0

    font.family: "Material Symbols Rounded"
    font.weight: 500
    font.variableAxes: ({ "FILL": fill, "opsz": 20 })
    color: Theme.subtle
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
