import Quickshell
import Quickshell.Wayland
import QtQuick
import "../"

PanelWindow {
    id: root

    color: "transparent"

    anchors {
        top:    true
        left:   true
        right:  true
        bottom: true
    }

    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay

    visible: blackout.opacity > 0

    Rectangle {
        id: blackout

        anchors.fill: parent
        color: "#000000"
        opacity: PowerProfile.displayTransitionActive ? 1 : 0

        Behavior on opacity {
            enabled: !Theme.staticMode
            NumberAnimation {
                duration: PowerProfile.displayTransitionFadeDuration
                easing.type: Easing.InOutCubic
            }
        }
    }
}
