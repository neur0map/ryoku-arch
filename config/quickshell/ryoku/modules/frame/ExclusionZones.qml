import QtQuick
import Quickshell
import Quickshell.Wayland
Scope {
    id: root

    required property ShellScreen modelData

    // Left edge (frame + matboard)
    PanelWindow {
        screen: root.modelData
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"
        mask: Region {}
        exclusiveZone: Config.sideExclusion
        implicitWidth: 1
        implicitHeight: 1
        anchors { top: true; bottom: true; left: true }
    }

    // Right edge (frame + matboard)
    PanelWindow {
        screen: root.modelData
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"
        mask: Region {}
        exclusiveZone: Config.sideExclusion
        implicitWidth: 1
        implicitHeight: 1
        anchors { top: true; bottom: true; right: true }
    }

    // Bottom edge (frame + matboard)
    PanelWindow {
        screen: root.modelData
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"
        mask: Region {}
        exclusiveZone: Config.sideExclusion
        implicitWidth: 1
        implicitHeight: 1
        anchors { bottom: true; left: true; right: true }
    }

    // No top ExclusionZone: Waybar owns the top edge. Our bottom-layer
    // exclusions apply to all upper layers, so reserving space on top
    // would push Waybar away from the screen edge and break the
    // "frame is an extension of the bar" look.
}
