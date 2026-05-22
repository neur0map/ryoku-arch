import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs.services
import qs.settings
import Quickshell.Io

Scope{
    id: root
    Loader{
        id: loader
        active: false
        property bool animation: false
        sourceComponent:PanelWindow{
            id: panelWindow
            implicitHeight: 600
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Normal
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            HyprlandFocusGrab{
                id: grab
                windows: [panelWindow]
                active: loader.active
                onCleared: () => {
                    if(!active) {
                        loader.animation = false
                    }
                }
            }

            WallhavenPanel{
                implicitHeight:loader.animation ?  parent.height : 0
            }


        }
    }

    Timer {
        id: animationTimer
        interval: 250
        onTriggered: loader.active = false
    }

    IpcHandler {
        target: "wallhavenPanel"

        function toggle(): void {
            if (!loader.active) {
                loader.active = true
                loader.animation = true
            } else {
                loader.animation = false
                animationTimer.start()
            }
        }
    }

}