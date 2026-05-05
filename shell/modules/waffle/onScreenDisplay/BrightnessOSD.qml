import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services
import qs.modules.waffle.looks

OSDValue {
    id: root
    property var focusedScreen: CompositorService.isNiri 
        ? (Quickshell.screens.find(s => s.name === NiriService.currentOutput) ?? GlobalStates.primaryScreen)
        : (Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? GlobalStates.primaryScreen)
    property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)
    iconName: "weather-sunny"
    value: brightnessMonitor?.brightness ?? 0
    showNumber: true

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            root.timer.restart();
        }
    }
}
