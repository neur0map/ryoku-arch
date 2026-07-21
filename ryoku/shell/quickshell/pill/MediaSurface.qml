import QtQuick
import "Singletons"
import "popouts"

// washi media surface: the now-playing transport (reused MediaPopout content)
// wrapped as a morph surface so the pill warps into it. the content brings its
// own padding, so the base margins stay 0.
PillSurface {
    id: root

    implicitWidth: media.implicitWidth
    implicitHeight: media.implicitHeight

    ameForm: "seam"
    amePoint: Qt.point(width / 2, height - 22 * s)

    MediaPopout {
        id: media
        anchors.fill: parent
        s: root.s
        open: root.open
        rich: true
    }
}
