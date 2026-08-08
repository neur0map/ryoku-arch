//@ pragma DefaultEnv QSG_RENDER_LOOP = threaded

import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons"

// desktop audio visualiser module entry. click-through, palette-tinted cava
// spectrum across the bottom of one monitor. mode drives visibility and layer:
// "off" hides it, "desktop" draws on the wallpaper behind every window
// (WlrLayer.Bottom), "overlay" raises it over windows (WlrLayer.Top). the
// controller instantiates one per screen and binds `screen`/`mode`; cava only
// runs while enabled.
Item {
    id: root

    // monitor this instance draws on, supplied by the controller.
    property var screen

    // off | desktop | overlay. defaults from Config so a standalone instance
    // still honours the persisted enabled flag; the controller overrides it.
    property string mode: Config.enabled ? "desktop" : "off"

    readonly property bool active: root.mode !== "off"
    readonly property bool raised: root.mode === "overlay"

    // Phase 10: the daemon IpcHandler (target "visualizer") that toggled the
    // persisted Config.enabled is removed; ShellState.visualizerMode (bound to
    // `mode`) drives visibility and layer now, flipped by the shell's visualizer
    // and visualizer-overlay shortcuts. Config still seeds the standalone default.

    // cava runs whenever the visualiser is enabled. Gating on "audio playing"
    // needs a probe (pactl / pw-dump) that is either broken or costs a periodic
    // graph dump here, while cava itself is ~1% idle and the render already
    // freezes on silence, so an always-on analyser is cheaper than polling.
    Binding {
        target: Spectrum
        property: "active"
        value: root.active
    }

    // configured band count; changing it restarts cava with the new bars.
    Binding {
        target: Spectrum
        property: "bars"
        value: Config.bars
    }

    // cava's framerate follows the render ceiling: no point sampling faster than
    // the spectrum draws.
    Binding {
        target: Spectrum
        property: "fps"
        value: Config.fps
    }

    // the line style draws the actual playback waveform; capture the monitor
    // only while that style is selected and the visualiser is on.
    Binding {
        target: Waveform
        property: "active"
        value: root.active && Config.style === "line"
    }

    PanelWindow {
        id: win

        screen: root.screen
        visible: root.active
        color: "transparent"

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: root.raised ? WlrLayer.Top : WlrLayer.Bottom
        WlrLayershell.namespace: "ryoku-visualizer"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // empty input region: every click falls through to windows above, so the
        // visualiser shares the desktop without ever intercepting it.
        mask: emptyRegion
        Region { id: emptyRegion }

        anchors { top: true; left: true; right: true; bottom: true }

        VisualizerView {
            anchors.fill: parent
        }
    }
}
