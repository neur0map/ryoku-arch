import QtQuick

// Material Symbols icon glyph. QtRendering (distance-field) so it stays crisp when
// scaled/animated - unlike UiText (NativeRendering, static labels only). Single
// source for the icon font + render mode; callers set text/pixelSize/color.
Text {
    id: root
    property real fill: 0
    renderType: Text.QtRendering
    font.family: "Material Symbols Rounded"
    font.variableAxes: {
        "FILL": root.fill,
    }
}
