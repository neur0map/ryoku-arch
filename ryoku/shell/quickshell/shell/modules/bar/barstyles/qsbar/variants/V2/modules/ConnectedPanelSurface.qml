import QtQuick

// Semantic shared name for the confirmed connected panel silhouette.
// AiPanelSurface remains the single rendering implementation so every panel
// uses exactly the same antialiased geometry. Publish the actually rendered
// tip position as well: at screen edges the surface clamps it away from the
// rounded card corner, and the bar notch must follow that resolved position.
AiPanelSurface {
    required property bool ownerActive
    readonly property real resolvedTargetX: parent ? parent.x + centerX : targetX
    readonly property real hostWidth:
        parent && parent.parent ? parent.parent.width : 0
    readonly property bool hostGeometryCoversTarget:
        hostWidth > 0 && targetX > 0 && targetX <= hostWidth + 0.5

    function publishResolvedTarget() {
        if (!ownerActive || !root) return

        // A previously unmapped PanelWindow can still report a panel-sized host
        // during its first reveal. Use the already-current widget anchor until
        // the host is wide enough to resolve the panel's real clamped caret.
        if (reveal <= 0.001 || !hostGeometryCoversTarget) {
            if (isFinite(targetX) && targetX > 0)
                root.setPanelInsetX(targetX)
            return
        }

        if (resolvedTargetX > 0) root.setPanelInsetX(resolvedTargetX)
    }

    onResolvedTargetXChanged: publishResolvedTarget()
    // A bar-style change may move the parent before this inherited binding is
    // reevaluated. Retry once the raw owner anchor itself catches up so the
    // connected inset cannot remain at the previous style.
    onTargetXChanged: publishResolvedTarget()
    onHostGeometryCoversTargetChanged: publishResolvedTarget()
    onOwnerActiveChanged: publishResolvedTarget()
    onRevealChanged: publishResolvedTarget()
}
