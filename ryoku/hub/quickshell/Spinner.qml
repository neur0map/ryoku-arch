import QtQuick
import "Singletons"

// A small indeterminate spinner: the refresh glyph rotating in place. Stops when
// hidden so it never spins off-screen.
Item {
    id: spin

    property real size: 18
    property color tint: Theme.ember

    implicitWidth: size
    implicitHeight: size

    Icon {
        anchors.centerIn: parent
        name: "refresh"
        size: spin.size
        weight: 2
        tint: spin.tint
    }

    RotationAnimator on rotation {
        from: 0
        to: 360
        duration: 900
        loops: Animation.Infinite
        running: spin.visible
    }
}
