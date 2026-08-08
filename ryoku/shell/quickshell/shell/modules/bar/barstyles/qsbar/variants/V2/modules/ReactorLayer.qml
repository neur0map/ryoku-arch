// ─────────────────────────────────────────────────────────────────────────────
// V2 reactor / gap-stream layer.
//
// The continuous V2 shell has no split "pill" sections the way V1 does, so the
// animated runs are the three physical widget CLUSTERS (left · center · right
// rows) and the stream flows in the dead space BETWEEN them. Geometry tracks the
// shell BODY (the caller sizes us to the island / continuousBarSurface), which
// deliberately excludes the tapered notch shoulders: the surface fill falls away
// under the shoulder run-outs, so a gap opened there would strand particles off
// the lit surface. Keeping the field inside the body is how we "account for" the
// notch shoulders — they stay chrome, never a stream channel.
//
// This mirrors V1's `island` run-geometry shim (pillRuns / runLeftEdge /
// runRightEdge) so the shared ParticleStream drives every mode 1-8 (incl.
// 7=reactor, 8=quotes, fed by ~/.cache/qs-reactor-event) unchanged. The stream is
// loaded only while an animation is selected AND the bar is on screen, so it
// stays idle-cheap (LazyLoader unload releases the CAVA claim + paint timers).
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import Quickshell
import "../../../modules"

Item {
    id: reactor

    // qsbar Theme (the `root` object). barAnim is added to the V2 Theme by a
    // sibling task, so every read of it is guarded against a transient absence.
    required property var theme

    // The three physical widget clusters (island-local x / width). ReactorLayer
    // fills the island, so a row's x is already in our own coordinate space.
    property var leftRow: null
    property var centerRow: null
    property var rightRow: null

    property string monitor: ""
    // Gate: idle whenever the bar surface is not actually on screen.
    property bool shellVisible: true

    visible: reactor.theme && reactor.theme.barAnim > 0

    // ── run rectangles (local coords): one per visible cluster, physical L→R ──
    function clusterRun(row) {
        if (!row || row.width < 1)
            return null
        return { x: row.x, w: row.width }
    }
    function computeRuns() {
        var out = []
        var groups = [clusterRun(leftRow), clusterRun(centerRow), clusterRun(rightRow)]
        for (var i = 0; i < groups.length; i++)
            if (groups[i])
                out.push(groups[i])
        return out
    }
    readonly property var runs: {
        void (leftRow ? leftRow.x : 0);     void (leftRow ? leftRow.width : 0)
        void (centerRow ? centerRow.x : 0); void (centerRow ? centerRow.width : 0)
        void (rightRow ? rightRow.x : 0);   void (rightRow ? rightRow.width : 0)
        return computeRuns()
    }

    // ── ParticleStream shim: the exact API it reads over our `runs` ──
    readonly property var pillRuns: {
        var a = []
        for (var i = 0; i < runs.length; i++)
            a.push({ s: i, e: i })
        return a
    }
    function runRightEdge(i) { return runs[i].x + runs[i].w }
    function runLeftEdge(i)  { return runs[i].x }

    // Load the stream only while it can actually flow: an animation is selected,
    // the bar is on screen, and there is at least one gap between clusters.
    LazyLoader {
        active: reactor.visible && reactor.shellVisible && reactor.runs.length > 1

        ParticleStream {
            parent: reactor
            x: 0
            y: 0
            width: reactor.width
            height: reactor.height
            theme:  reactor.theme
            layout: reactor
            mode:   (reactor.theme && reactor.theme.barAnim !== undefined) ? reactor.theme.barAnim : 0
            active: true
            monitor: reactor.monitor
        }
    }
}
