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

    // Top edge (matboard only; Waybar reserves its own 26 px above this)
    PanelWindow {
        screen: root.modelData
        WlrLayershell.layer: WlrLayer.Bottom
        color: "transparent"
        mask: Region {}
        exclusiveZone: Config.topExclusion
        implicitWidth: 1
        implicitHeight: 1
        anchors { top: true; left: true; right: true }
    }
}
