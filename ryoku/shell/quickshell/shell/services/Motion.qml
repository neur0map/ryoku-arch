pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // reduceMotion (or the lowPowerMode master) collapses every animation to an
    // instant cut: durations go to 0, so Behaviors and transitions stop forcing
    // per-frame repaints -- the single biggest shell-animation win on a weak GPU.
    // Read straight from performance.json (the same file Performance and Ryoku
    // Settings use) so Motion stays a self-contained duration source. Dwell and
    // scheduling timers below (osdHide, notifHide, startupReveal) are functional,
    // not motion, so they are deliberately not gated -- reduce removes animation,
    // never the time a surface stays up or waits before appearing.
    readonly property bool reduce: perf.lowPowerMode || perf.reduceMotion

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: perf
            property bool lowPowerMode: false
            property bool reduceMotion: false
            property real motionSpeed: 1.0
        }
    }

    // Global animation tempo. A user multiplier (performance.json, default 1.0)
    // scales every motion duration below, so the whole shell speeds up or eases
    // off in one place; reduce still wins by collapsing to an instant cut. An
    // absent or out-of-range value falls back to 1.0.
    readonly property real speed: {
        const v = perf.motionSpeed;
        return (typeof v === "number" && v > 0 && v <= 8) ? v : 1.0;
    }
    function dur(ms) { return root.reduce ? 0 : Math.round(ms * root.speed); }

    // Bar, spacer, hover and startup reveal/hide. Measured ease-out-cubic over
    // 250 ms (measure/MOTION-MEASURED.md; contract 02 sec 5). Interrupt: reverse
    // from the current position, which a RevealBehavior retarget reproduces.
    readonly property int barReveal: root.dur(250)
    readonly property int barRevealCurve: Easing.OutCubic

    // Left/right side menu slide. A reveal that reverses rather than restarting, 250 ms, ease-out-cubic,
    // same envelope as the bar (contract 05 sec 5; contract 01 sec 5). Interrupt:
    // reverse from current.
    readonly property int menuSlide: root.dur(250)
    readonly property int menuSlideCurve: Easing.OutCubic
    // Full-height sidebar entrance/exit. This follows iNiR's default slide:
    // translate the already-sized panel, with a slower emphasized settle in
    // and a short emphasized acceleration out. The panel never relayouts while
    // moving.
    readonly property int sidebarEnter: root.dur(400)
    readonly property int sidebarExit: root.dur(200)
    readonly property var sidebarEnterCurve: [0.05, 0.7, 0.1, 1, 1, 1]
    readonly property var sidebarExitCurve: [0.3, 0, 0.8, 0.15, 1, 1]
    readonly property var sidebarFadeInCurve: [0, 0, 0, 1, 1, 1]
    readonly property var sidebarFadeOutCurve: [0.3, 0, 1, 1, 1, 1]

    // Sidebar page push: the one continuous navigation move, 420 ms on a long
    // OutQuint settle so the incoming page glides in and eases to rest, never
    // snaps. The single language for every sidebar page transition.
    readonly property int push: root.dur(420)
    readonly property int pushCurve: Easing.OutQuint

    // Corner/top/bottom scale grow that restarts from its current position. 200 ms easeInOutQuad, set
    // explicitly in source (contract 01 sec 5; contract 05 sec 5). Interrupt:
    // restart from the current position toward the new target.
    readonly property int diagonal: root.dur(200)
    readonly property int diagonalCurve: Easing.InOutQuad

    // Menu swap within one stack region: a stacked crossfade, linear opacity,
    // 200 ms (contract 01 sec 5; contract 05 sec 5).
    readonly property int crossfade: root.dur(200)
    readonly property int crossfadeCurve: Easing.Linear

    // Revealer row/button expand: child height SlideDown, 200 ms ease-out-cubic
    // (contract 16 sec 5; contract 06 sec 5). Notification cards (contract 12
    // sec 5), dynamic-list entries and the weather inner slide share this.
    readonly property int rowReveal: root.dur(200)
    readonly property int rowRevealCurve: Easing.OutCubic

    // Revealed-content fade and the chevron 0->90 turn: CSS `ease` =
    // cubic-bezier(0.25, 0.1, 0.25, 1) over 200 ms (contract 16 sec 5;
    // contract 06 sec 5). Thumbnail hover is the same curve over 150 ms
    // (contract 08 sec 5).
    readonly property int rowFade: root.dur(200)
    readonly property int chevronRotate: root.dur(200)
    readonly property int thumbHover: root.dur(150)
    readonly property int easeType: Easing.Bezier
    readonly property var easeCurve: [0.25, 0.1, 0.25, 1, 1, 1]

    // Desktop wallpaper swap crossfade, 200 ms (contract 08 sec 5,
    // TRANSITION_DURATION_MS). Linear opacity like the menu crossfade.
    readonly property int wallpaperFade: root.dur(200)

    // Weather outer-stack crossfade, 250 ms, set in source (contract 08 sec 5).
    readonly property int weatherFade: root.dur(250)

    // OSD auto-hide hold: the OSD has NO show/hide animation (contract 12 sec 5);
    // only this 1000 ms dwell from the last value update is timed, and a new
    // value resets it. A dwell timer, not motion, so reduce does not gate it.
    readonly property int osdHide: 1000

    // Notification popup entrance/exit (contract 12 sec 5, eye-candy pass): a
    // toast grows out of the anchored top corner (scale 0.9->1 + fade) and
    // recedes back into it (scale ->0.9 + fade). The card sets transformOrigin to
    // that corner, so the grow reads as "from the corner"; the scale never
    // exceeds 1, so an overshoot can never clip against the surface edge.
    readonly property int notifIn: root.dur(220)
    readonly property int notifOut: root.dur(180)
    readonly property var notifInCurve: root.effectsCurve
    readonly property int notifOutCurve: Easing.InCubic

    // Notification container unmap delay: 260 ms after the popup list empties, so
    // the last card exit (notifOut) finishes before the surface drops (contract
    // 12 sec 5). A scheduling timer, not motion.
    readonly property int notifHide: 260

    // Bars auto-reveal once, 1000 ms after startup (contract 02 sec 5). A one-shot
    // startup delay, not motion, so reduce keeps the timing and only drops the
    // slide.
    readonly property int startupReveal: 1000

    // Retained transitional timings for remaining Popout, Deck, Stash,
    // KeyringSurface, and WaveMeter consumers.
    readonly property int fast:     root.dur(140)
    readonly property int standard: root.dur(300)
    readonly property int morph:    root.dur(420)
    readonly property int hover:    root.dur(100)
    readonly property int spatial:  root.dur(500)
    readonly property int effects:  root.dur(200)
    readonly property int easeStandard: Easing.OutCubic
    readonly property var spatialCurve: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var effectsCurve: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property real rSmall: 7
    readonly property real rTile:  13
}
