import QtQuick
import "Singletons"
import "popouts"

// washi resources surface: the CPU / memory / temperature readout (reused
// ResourcesPopout content) wrapped as a morph surface. margins stay 0.
PillSurface {
    id: root

    implicitWidth: res.implicitWidth
    implicitHeight: res.implicitHeight

    ameForm: "dock"
    amePoint: Qt.point(width / 2, height / 2)

    ResourcesPopout {
        id: res
        anchors.fill: parent
        s: root.s
        open: root.open
    }
}
