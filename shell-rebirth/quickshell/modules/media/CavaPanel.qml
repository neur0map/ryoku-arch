import QtQuick
import Quickshell
import qs.components
import Quickshell.Io
import Quickshell.Wayland
import QtQuick.Layouts
import "../../colors" as ColorsModule

PanelWindow {
    id: cavaPanel
    visible: false

    implicitWidth: 320
    implicitHeight: 110

    anchors.top: true
    anchors.left: true
    margins.top: 16
    margins.left: 400

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: 18

        color: ColorsModule.Colors.surface_container

        border.color: ColorsModule.Colors.outline_variant
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12

            CavaBars {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
    IpcHandler {
        target: "cavaPanel"
        function toggle(): void {
            cavaPanel.visible = !cavaPanel.visible
        }
    }
}
