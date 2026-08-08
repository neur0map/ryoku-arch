import QtQuick

// Shared text element for STATIC UI labels: native (FreeType) glyph rendering is
// crisp at small sizes (10-13px), where the Qt default distance-field rendering
// looks soft. Drop-in for `Text {}` — only changes renderType, nothing else.
//
// Do NOT use for animated/scaled/width-animated text (e.g. the bar pills with
// `Behavior on implicitWidth` + centerIn): native has no sub-pixel positioning
// and would blur during motion. Those stay on plain `Text {}` (distance-field).
Text {
    renderType: Text.NativeRendering
}
