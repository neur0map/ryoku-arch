import QtQuick
import "Singletons"
import "popouts"

// washi power surface: the session column (reused Power content) wrapped as a
// morph surface. Power is a fixed vertical column, so the surface size is fixed.
PillSurface {
    id: root

    implicitWidth: 74 * s
    implicitHeight: 312 * s

    ameForm: "dock"
    amePoint: Qt.point(width / 2, height / 2)

    Power {
        anchors.fill: parent
        s: root.s
        onClosed: root.requestClose()
    }
}
