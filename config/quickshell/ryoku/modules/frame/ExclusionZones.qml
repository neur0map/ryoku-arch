import QtQuick
import Quickshell

// Phase 1 intentionally uses Hyprland per-edge gaps_out (managed by
// ryoku-toggle-frame) to inset windows inside the frame. Layer-shell
// exclusion zones were evaluated and rejected: because our frame lives
// on WlrLayer.Bottom, reserving space on any edge constrains Waybar
// (top layer) too, which visually detaches Waybar from the side frame
// strips and breaks the "frame is an extension of the bar" design goal.
//
// This file remains as an empty Scope so shell.qml's Variants pattern
// stays structurally identical, leaving room for Phase 2 to re-introduce
// compositor-agnostic exclusions (e.g., for a QS-native bar that should
// coexist with zones without pushing Waybar).
Scope {
    id: root

    required property ShellScreen modelData
}
