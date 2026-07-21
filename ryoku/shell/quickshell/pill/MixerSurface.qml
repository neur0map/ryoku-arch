import QtQuick
import "Singletons"
import "popouts"

// washi mixer surface: the audio + display control centre (reused Mixer content)
// wrapped as a morph surface. content carries its own padding; margins stay 0.
PillSurface {
    id: root

    implicitWidth: mixer.implicitWidth
    implicitHeight: mixer.implicitHeight

    ameForm: "dock"
    amePoint: Qt.point(width / 2, height / 2)

    Mixer {
        id: mixer
        anchors.fill: parent
        s: root.s
        open: root.open
    }
}
