pragma Singleton

import Quickshell

// RYOKU compat shim for iNiR's `CompositorService`. ryoku runs Hyprland.
Singleton {
    readonly property bool isHyprland: true
    readonly property bool isNiri: false
}
