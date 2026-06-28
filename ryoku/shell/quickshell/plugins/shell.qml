//@ pragma DefaultEnv QSG_RENDER_LOOP = threaded

import QtQuick
import Quickshell

/**
 * Plugin process entry point.
 *
 * Historically this config hosted plugin desktop tiles on a second WlrLayer.Bottom
 * surface (namespace `ryoku-plugins`). Two full-screen layer-shell surfaces on
 * the same monitor (this one and the widgets layer carrying clock/weather) fight
 * for pointer input — whichever is on top swallows clicks meant for the other.
 *
 * Desktop-tile hosting now lives in the widgets config (`quickshell/widgets`)
 * alongside the shipped clock/weather, so plugin tiles are true peers of those
 * widgets: one wallpaper layer, one input model, no second surface. Frame-fusing
 * hosts (frame popout, island) live in the pill process because the blob field
 * is per-process; this config is no longer responsible for any plugin surface.
 *
 * Kept as a minimal valid ShellRoot because the daemon's components list still
 * supervises `qs -c plugins`; emptying it lets the process come up cleanly with
 * no surfaces of its own and stay out of the input path.
 */
ShellRoot {
    id: root
}
