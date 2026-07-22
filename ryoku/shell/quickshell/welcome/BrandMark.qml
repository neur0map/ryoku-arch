pragma ComponentBehavior: Bound
import QtQuick
import Qt5Compat.GraphicalEffects
import Ryoku.Ui.Singletons
import "Singletons"

// The desktop brand seal, 力 by default. Users swap it globally (their own
// glyph/text, or an image) from Ryoku Settings -> Shell -> Global; stored in
// ~/.config/ryoku/brand.json. Ryoku's own apps (the Hub, ryo* apps) never use
// this and keep the 力 brand. The mark is one of the accent's three sanctioned
// homes (frame, 力, art), so it defaults to the brand sun. Drop-in for the old
// `Text { text: "力"; font.family: Tokens.jp; color: Tokens.sun }` seal:
// pass the old pixelSize as `size` and the old colour as `color`.
Item {
    id: mark

    property real size: 13
    property color color: Tokens.sun
    property int weight: Font.Medium
    // recolour a single-colour image mark to `color` (matches the tinted 力
    // idiom); off shows a full-colour logo as-is. no effect in text mode.
    property bool tint: Theme.markTint

    readonly property bool image: Theme.markSource.length > 0
    readonly property string imageSource: !mark.image ? ""
        : (/^(file|qrc|image|https?):/.test(Theme.markSource) ? Theme.markSource
                                                              : "file://" + Theme.markSource)

    implicitWidth:  mark.image ? mark.size : glyph.implicitWidth
    implicitHeight: mark.image ? mark.size : glyph.implicitHeight

    Text {
        id: glyph
        visible: !mark.image
        anchors.centerIn: parent
        text: Theme.mark
        color: mark.color
        font.family: Tokens.jp
        font.weight: mark.weight
        font.pixelSize: mark.size
    }

    // custom image mark. tint recolours a single-colour logo to `color` (the 力
    // idiom) via an alpha-preserving overlay, so a dark OR light mark both take
    // the accent; tint off shows a full-colour logo as-is.
    Image {
        id: img
        anchors.centerIn: parent
        width: mark.size
        height: mark.size
        visible: mark.image && !mark.tint
        source: mark.imageSource
        sourceSize.width: Math.round(mark.size * 2)
        sourceSize.height: Math.round(mark.size * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    ColorOverlay {
        anchors.fill: img
        visible: mark.image && mark.tint
        source: img
        color: mark.color
    }
}
