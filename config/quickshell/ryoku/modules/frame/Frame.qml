import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    surfaceFormat.opaque: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Left strip: opaque, full height. Waybar covers its top portion (y=0..waybarHeight)
    // since Waybar sits on WlrLayer.Top above this.
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Config.frameThickness
        color: Config.frameColor
    }

    // Right strip: mirror of the left.
    Rectangle {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: Config.frameThickness
        color: Config.frameColor
    }

    // Bottom strip: spans full width.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Config.frameThickness
        color: Config.frameColor
    }
}
