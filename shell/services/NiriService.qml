pragma Singleton

import Quickshell
import qs.services

// RYOKU compat shim for iNiR's `NiriService` (iNiR targets Niri). ryoku runs
// Hyprland; currentOutput maps to the focused Hyprland monitor name. Niri-only
// actions (fps limiter, anim toggles) are no-ops here.
Singleton {
    readonly property string currentOutput: Hypr.focusedMonitor?.name ?? (Screens.screens[0]?.name ?? "")
}
