// Ryoku Quickshell Config
//
// Singleton exposing every tunable knob for the Phase 1 decorative frame.
// Everything else in the shell (Frame.qml, ExclusionZones.qml) binds to
// these values. Edit them, then apply with:
//
//     ryoku-refresh-quickshell      # mirror this file into ~/.config
//     ryoku-restart-shell           # reload the running shell
//
// If you also change the frame geometry (thickness, matboard), keep the
// Hyprland drop-in in sync. It lives in ryoku-toggle-frame's
// write_dropin() function and controls how far Hyprland pushes windows
// away from the screen edge. The invariant:
//
//     gaps_out side  =  frameThickness + matboard
//     gaps_out top   =  topMatboard
//
// Any drift here and the wallpaper gap will not match on the four sides.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    // --- Visual tunables ---------------------------------------------------

    // Thickness of the opaque colored strip on the left, right, and bottom
    // edges of the screen. The top edge is covered by Waybar so no separate
    // strip is drawn there.
    // Spec 2 follow-up: reduced from 4 to 1 for a slim hairline look
    // matching internal dashboard divider weight. Run `ryoku-toggle-frame`
    // twice (off then on) to regenerate the Hyprland gaps drop-in if you
    // also want windows to come closer to the screen edge.
    readonly property int frameThickness: 6

    // Thickness of the wallpaper-visible strip between the frame and the
    // window (on the left, right, and bottom edges).
    readonly property int matboard: 8

    // Thickness of the wallpaper-visible strip between Waybar and the
    // window (top edge). Keep equal to `matboard` for symmetric look.
    readonly property int topMatboard: 8

    // Height of the Waybar surface. Only used to start the Frame cutout
    // below Waybar so the rounded top inner corners appear right under it.
    // If you change Waybar's height (waybar config.jsonc `height`), change
    // this too.
    // Spec 2: kept at 0 so the Frame does NOT paint a top strip behind
    // the Brain_Shell TopBar's transparent notch gaps. Floating-notch
    // design preserved. Trade-off: corner where bar bottom meets side
    // frame is sharp. Spec 2.7 (queued in docs/TODO.md) handles the
    // proper Caelestia-style Frame-bar shape connection.
    readonly property int waybarHeight: 0

    // Corner radius applied to all four inner corners of the Frame cutout
    // (where the window area begins). Also used by the Hyprland drop-in
    // for window corner rounding so app corners echo the frame curve.
    // Bumped to 16 to match the Hyprland decoration:rounding bumped in
    // bin/ryoku-toggle-frame so window corners and Frame inner cutout
    // corners curve at the same radius.
    readonly property int rounding: 16

    // --- Derived exclusions (do not edit directly) -------------------------

    // Top edge reservation. Only the matboard; Waybar already reserves
    // its own space on the top layer.
    readonly property int topExclusion: topMatboard

    // Side/bottom edge reservation. Frame strip plus matboard.
    readonly property int sideExclusion: frameThickness + matboard

    // --- Theme-driven color -----------------------------------------------

    // Fallback color used before the theme file loads (first boot, or a
    // missing theme render). Replaced by the theme's `background` token
    // via the FileView below. The live color matches Waybar's background
    // so the bar and frame read as one continuous piece.
    property color frameColor: "#171717"

    // Ryoku theme templates render a one-property QML singleton at the
    // path below on every `ryoku-theme-set`. We parse it dynamically so
    // the frame recolor atomically. Theme swaps are handled at the
    // process level (ryoku-theme-set calls ryoku-restart-shell) because
    // the swap is a symlink change that inotify cannot detect.
    FileView {
        id: themeColors
        path: Quickshell.env("HOME") + "/.config/ryoku/current/theme/quickshell-colors.qml"
        watchChanges: true

        onLoaded: {
            try {
                const loaded = Qt.createQmlObject(themeColors.text(), root, "quickshell-colors.qml")
                if (loaded !== null && loaded.frame !== undefined) {
                    root.frameColor = loaded.frame
                    loaded.destroy()
                }
            } catch (e) {
                console.warn("Config: failed to parse theme colors:", e.message)
            }
        }
    }
}
