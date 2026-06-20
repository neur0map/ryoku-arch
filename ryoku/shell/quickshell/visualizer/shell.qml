import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Singletons"

/**
 * Desktop audio visualiser. A click-through, wallust-tinted cava spectrum across
 * the bottom of each monitor. By default it sits on the wallpaper behind every
 * window (WlrLayer.Bottom); `ryoku-shell visualizer-overlay` raises it over the
 * windows (WlrLayer.Top) on demand and flips back. On by default; `ryoku-shell
 * visualizer` toggles it, and cava only runs while it is enabled.
 */
ShellRoot {
    id: root

    property bool enabled: true
    property bool raised: false

    IpcHandler {
        target: "visualizer"
        function toggle(mon: string): void { root.enabled = !root.enabled; }
        function show(mon: string): void { root.enabled = true; }
        function hide(): void { root.enabled = false; }
        function overlay(mon: string): void { root.raised = !root.raised; if (root.raised) root.enabled = true; }
    }

    // Run cava only while the visualiser is live on the desktop.
    Binding {
        target: Spectrum
        property: "active"
        value: root.enabled
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

            // Empty input region: every click falls through to the windows above,
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
