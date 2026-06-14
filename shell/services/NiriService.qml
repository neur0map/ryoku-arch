pragma Singleton

import Quickshell
import qs.services

// Ryoku NiriService: Ryoku runs Hyprland; currentOutput maps to the focused
// Hyprland monitor name. Niri-only actions (fps limiter, anim toggles) are no-ops.
Singleton {
    readonly property string currentOutput: Hypr.focusedMonitor?.name ?? (Screens.screens[0]?.name ?? "")
}
