//@ pragma DefaultEnv QSG_RENDER_LOOP = threaded

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"

// desktop audio visualiser. click-through, wallust-tinted cava spectrum across
// the bottom of each monitor. default = on the wallpaper, behind every window
// (WlrLayer.Bottom). `ryoku-shell visualizer-overlay` raises it over windows
// (WlrLayer.Top) on demand and flips back. on by default; `ryoku-shell
// visualizer` toggles. cava only runs while enabled.
ShellRoot {
    id: root

    property bool enabled: Config.enabled
    property bool raised: false

    IpcHandler {
        target: "visualizer"
        function toggle(mon: string): void { Config.setEnabled(!Config.enabled); }
        function show(mon: string): void { Config.setEnabled(true); }
        function hide(): void { Config.setEnabled(false); }
        function overlay(mon: string): void { root.raised = !root.raised; if (root.raised) Config.setEnabled(true); }
    }

    // run cava only while the visualiser is live on the desktop.
    Binding {
        target: Spectrum
        property: "active"
        value: root.enabled
    }

    // configured band count; changing it restarts cava with the new bars.
    Binding {
        target: Spectrum
        property: "bars"
        value: Config.bars
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            screen: modelData
            visible: root.enabled
            color: "transparent"

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: root.raised ? WlrLayer.Top : WlrLayer.Bottom
            WlrLayershell.namespace: "ryoku-visualizer"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // empty input region: every click falls through to windows above,
            // so the visualiser shares the desktop without ever intercepting it.
            mask: emptyRegion
            Region { id: emptyRegion }

            anchors { top: true; left: true; right: true; bottom: true }

            Visualizer {
                anchors.fill: parent
            }
        }
    }
}
