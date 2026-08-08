import QtQuick
import Qt5Compat.GraphicalEffects

// One symbolic glyph from the shell's icon set (framebars/icons, freedesktop
// names without the -symbolic suffix), flattened to a single colour. This is
// the bar and menu glyph primitive; the glyph set is the source of the exact
// shapes the frame renders, so nothing here falls back to a font.
Item {
    id: root

    property string name: ""
    property color color: "#cacccc"
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        visible: false
        source: root.name.length > 0
            ? Qt.resolvedUrl("icons/" + root.name + "-symbolic.svg") : ""
        sourceSize.width: Math.round(root.size * Screen.devicePixelRatio)
        sourceSize.height: Math.round(root.size * Screen.devicePixelRatio)
        smooth: true
        asynchronous: false
    }

    ColorOverlay {
        anchors.fill: img
        visible: root.name.length > 0
        source: img
        color: root.color
    }
}
