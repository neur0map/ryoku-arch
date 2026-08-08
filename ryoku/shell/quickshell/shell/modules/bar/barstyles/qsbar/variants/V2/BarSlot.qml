// ─────────────────────────────────────────────────────────────────────────────
// V2 BarSlot — V1's complete widget/panel behavior on one selectable bar shell.
// The surface spans the full output width at a compact 33px visible height;
// a single screen-facing border and shadow replace the rounded section islands.
// ─────────────────────────────────────────────────────────────────────────────
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "modules"

PanelWindow {
    id: barSlot
    required property var root
    readonly property string screenName: barSlot.screen ? barSlot.screen.name : ""
    readonly property bool compactShell: barSlot.root.barShellStyle !== "full"
    readonly property int shellOuterMargin: 5
    readonly property int shellRadius: barSlot.root.barShellStyle === "dock"
        ? 8
        : barSlot.root.barShellStyle === "notch" ? 0 : barSlot.root.panelRadius
    // The Notch is a content-width lobe flowing directly out of the screen edge.
    // One continuous cubic per side creates the soft diagonal run-out without
    // a neck, step or frame around the rest of the output.
    readonly property int notchFrameRadius: barSlot.root.v2NotchFrameRadius
    readonly property int notchShoulderWidth: notchFrameRadius
    readonly property int notchBodyRadius: 9
    readonly property real notchCurveKappa: 0.55228475
    readonly property int shellVisibleHeight: barSlot.root.v2BarHeight
    readonly property real shellTargetWidth: compactShell
        ? Math.max(80,
            Math.min(barSlot.width - 2 * shellOuterMargin,
                island.fitNaturalWidth))
        : barSlot.width

    color: "transparent"
    // ALWAYS screen-tall → window never resizes → NO compositor resize animation.
    // Reserve the visible bar strip; the mask limits the INPUT region to the bar
    // strip when locked (clicks below pass through), full screen when unlocked (drag).
    // anchored to left+right always; top OR bottom by barPosition (exclusiveZone
    // reserves space on whichever edge is anchored → no extra logic needed)
    anchors {
        left: true; right: true
        top:    barSlot.root.barPosition === "top"
        bottom: barSlot.root.barPosition === "bottom"
    }
    implicitHeight: barSlot.screen ? barSlot.screen.height : 1440
    exclusionMode: ExclusionMode.Normal
    // Keep the same compositor reservation for every shell style: clients must
    // never slide behind a content-width Fit/Dock/Notch bar.
    exclusiveZone: barSlot.root.v2BarHeight + 3
    mask: Region {
        x: barSlot.root.barUnlocked ? 0 : Math.round(continuousBarSurface.x)
        y: barSlot.root.barUnlocked ? 0
           : (barSlot.root.barPosition === "bottom"
                ? barSlot.height - barSlot.shellVisibleHeight : 0)
        width: barSlot.root.barUnlocked ? barSlot.width : Math.round(continuousBarSurface.width)
        height: barSlot.root.barUnlocked ? barSlot.height : barSlot.shellVisibleHeight
    }
    // grab keyboard while unlocked so ESC can exit
    WlrLayershell.keyboardFocus: barSlot.root.barUnlocked ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    HoverHandler {
        onHoveredChanged: if (hovered && !barSlot.root.anyPopupVisible) barSlot.root.activatePopupScreen(barSlot.screen)
    }

    // keep Hyprland awake while the idle-inhibitor toggle is on (carried over
    // from the legacy single-bar implementation)
    IdleInhibitor { window: barSlot; enabled: barSlot.root.idleInhibited }

    // if unlock ends mid-drag (ESC / ipc lock / click backdrop), kill the drag so the
    // ghost doesn't stay frozen + the source widget doesn't stay dimmed
    Connections {
        target: barSlot.root
        function onBarUnlockedChanged() {
            if (!barSlot.root.barUnlocked && barSlot.dragging) barSlot.cancelDrag()
        }
    }

    readonly property color accent: barSlot.root.seal

    // One uninterrupted surface across the output. On the default top edge the
    // border is literally the bottom border requested for V2; the optional V1
    // bottom placement mirrors it so the shadow still opens toward the desktop.
    Rectangle {
        id: continuousBarSurface
        x: barSlot.compactShell ? Math.round((barSlot.width - width) / 2) : 0
        y: barSlot.root.barPosition === "bottom"
            ? barSlot.height - height
            : 0
        width: barSlot.shellTargetWidth
        height: barSlot.shellVisibleHeight
        radius: barSlot.compactShell ? barSlot.shellRadius : 0
        color: "transparent"
        z: 0

        readonly property real topCornerRadius:
            !barSlot.compactShell ? 0
            : barSlot.root.barShellStyle === "fit" ? radius
            : barSlot.root.barPosition === "bottom" ? radius : 0
        readonly property real bottomCornerRadius:
            !barSlot.compactShell ? 0
            : barSlot.root.barShellStyle === "fit" ? radius
            : barSlot.root.barPosition === "top" ? radius : 0
        readonly property real insetProgress: edgeBorder.curvedInsetRendering
            ? edgeBorder.curvedInsetReveal
            : 0
        readonly property real insetCenter: edgeBorder.curvedInsetRendering
            ? edgeBorder.curvedInsetPixel
            : width / 2
        readonly property real insetHalfWidth: 7 * insetProgress
        readonly property real insetTangentControl: 4.25 * insetProgress
        readonly property real insetTipControl: 2 * insetProgress
        readonly property real insetDepth: 5 * insetProgress

        RectangularShadow {
            anchors.fill: parent
            visible: barSlot.root.barShellStyle !== "notch"
            radius: continuousBarSurface.radius
            blur: 9
            spread: 0
            offset: Qt.vector2d(0, barSlot.root.barPosition === "bottom" ? -2 : 2)
            color: barSlot.root.v2BarShadow
            z: -1
        }

        // The panel indentation is part of the filled silhouette, not merely a
        // border drawn over a rectangle. This keeps its interior genuinely cut
        // out and mirrors the same negative-space geometry at the bottom edge.
        Shape {
            id: topSurfaceFill
            visible: barSlot.root.barPosition === "top"
                && barSlot.root.barShellStyle !== "notch"
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: barSlot.root.barBg
                startX: continuousBarSurface.topCornerRadius
                startY: 0
                PathLine { x: topSurfaceFill.width - continuousBarSurface.topCornerRadius; y: 0 }
                PathQuad {
                    x: topSurfaceFill.width; y: continuousBarSurface.topCornerRadius
                    controlX: topSurfaceFill.width; controlY: 0
                }
                PathLine {
                    x: topSurfaceFill.width
                    y: topSurfaceFill.height - continuousBarSurface.bottomCornerRadius
                }
                PathQuad {
                    x: topSurfaceFill.width - continuousBarSurface.bottomCornerRadius
                    y: topSurfaceFill.height
                    controlX: topSurfaceFill.width; controlY: topSurfaceFill.height
                }
                PathLine {
                    x: continuousBarSurface.insetCenter + continuousBarSurface.insetHalfWidth
                    y: topSurfaceFill.height
                }
                PathCubic {
                    x: continuousBarSurface.insetCenter
                    y: topSurfaceFill.height - continuousBarSurface.insetDepth
                    control1X: continuousBarSurface.insetCenter + continuousBarSurface.insetTangentControl
                    control1Y: topSurfaceFill.height
                    control2X: continuousBarSurface.insetCenter + continuousBarSurface.insetTipControl
                    control2Y: topSurfaceFill.height - continuousBarSurface.insetDepth
                }
                PathCubic {
                    x: continuousBarSurface.insetCenter - continuousBarSurface.insetHalfWidth
                    y: topSurfaceFill.height
                    control1X: continuousBarSurface.insetCenter - continuousBarSurface.insetTipControl
                    control1Y: topSurfaceFill.height - continuousBarSurface.insetDepth
                    control2X: continuousBarSurface.insetCenter - continuousBarSurface.insetTangentControl
                    control2Y: topSurfaceFill.height
                }
                PathLine { x: continuousBarSurface.bottomCornerRadius; y: topSurfaceFill.height }
                PathQuad {
                    x: 0; y: topSurfaceFill.height - continuousBarSurface.bottomCornerRadius
                    controlX: 0; controlY: topSurfaceFill.height
                }
                PathLine { x: 0; y: continuousBarSurface.topCornerRadius }
                PathQuad {
                    x: continuousBarSurface.topCornerRadius; y: 0
                    controlX: 0; controlY: 0
                }
            }
        }

        Shape {
            id: bottomSurfaceFill
            visible: barSlot.root.barPosition === "bottom"
                && barSlot.root.barShellStyle !== "notch"
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: barSlot.root.barBg
                startX: continuousBarSurface.topCornerRadius
                startY: 0
                PathLine {
                    x: continuousBarSurface.insetCenter - continuousBarSurface.insetHalfWidth
                    y: 0
                }
                PathCubic {
                    x: continuousBarSurface.insetCenter
                    y: continuousBarSurface.insetDepth
                    control1X: continuousBarSurface.insetCenter - continuousBarSurface.insetTangentControl
                    control1Y: 0
                    control2X: continuousBarSurface.insetCenter - continuousBarSurface.insetTipControl
                    control2Y: continuousBarSurface.insetDepth
                }
                PathCubic {
                    x: continuousBarSurface.insetCenter + continuousBarSurface.insetHalfWidth
                    y: 0
                    control1X: continuousBarSurface.insetCenter + continuousBarSurface.insetTipControl
                    control1Y: continuousBarSurface.insetDepth
                    control2X: continuousBarSurface.insetCenter + continuousBarSurface.insetTangentControl
                    control2Y: 0
                }
                PathLine { x: bottomSurfaceFill.width - continuousBarSurface.topCornerRadius; y: 0 }
                PathQuad {
                    x: bottomSurfaceFill.width; y: continuousBarSurface.topCornerRadius
                    controlX: bottomSurfaceFill.width; controlY: 0
                }
                PathLine {
                    x: bottomSurfaceFill.width
                    y: bottomSurfaceFill.height - continuousBarSurface.bottomCornerRadius
                }
                PathQuad {
                    x: bottomSurfaceFill.width - continuousBarSurface.bottomCornerRadius
                    y: bottomSurfaceFill.height
                    controlX: bottomSurfaceFill.width; controlY: bottomSurfaceFill.height
                }
                PathLine { x: continuousBarSurface.bottomCornerRadius; y: bottomSurfaceFill.height }
                PathQuad {
                    x: 0; y: bottomSurfaceFill.height - continuousBarSurface.bottomCornerRadius
                    controlX: 0; controlY: bottomSurfaceFill.height
                }
                PathLine { x: 0; y: continuousBarSurface.topCornerRadius }
                PathQuad {
                    x: continuousBarSurface.topCornerRadius; y: 0
                    controlX: 0; controlY: 0
                }
            }
        }

        // NOTCH / TOP: the screen edge flows diagonally into the lobe in one run.
        Shape {
            id: notchSurfaceFillTop
            visible: barSlot.root.barShellStyle === "notch"
                && barSlot.root.barPosition === "top"
            x: -continuousBarSurface.x
            y: 0
            width: barSlot.width
            height: barSlot.root.v2BarHeight
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            readonly property real bodyLeft: continuousBarSurface.x
            readonly property real bodyRight:
                continuousBarSurface.x + continuousBarSurface.width
            readonly property real insetCenter:
                continuousBarSurface.x + continuousBarSurface.insetCenter

            ShapePath {
                strokeColor: "transparent"
                fillColor: barSlot.root.barBg
                startX: notchSurfaceFillTop.bodyLeft - barSlot.notchShoulderWidth
                startY: 0
                PathLine {
                    x: notchSurfaceFillTop.bodyRight + barSlot.notchShoulderWidth
                    y: 0
                }
                PathCubic {
                    x: notchSurfaceFillTop.bodyRight - barSlot.notchBodyRadius
                    y: notchSurfaceFillTop.height
                    control1X: notchSurfaceFillTop.bodyRight
                        + (1 - barSlot.notchCurveKappa) * barSlot.notchShoulderWidth
                    control1Y: 0
                    control2X: notchSurfaceFillTop.bodyRight
                        + (1 - barSlot.notchCurveKappa) * barSlot.notchBodyRadius
                    control2Y: notchSurfaceFillTop.height
                }
                PathLine {
                    x: notchSurfaceFillTop.insetCenter
                        + continuousBarSurface.insetHalfWidth
                    y: notchSurfaceFillTop.height
                }
                PathCubic {
                    x: notchSurfaceFillTop.insetCenter
                    y: notchSurfaceFillTop.height - continuousBarSurface.insetDepth
                    control1X: notchSurfaceFillTop.insetCenter
                        + continuousBarSurface.insetTangentControl
                    control1Y: notchSurfaceFillTop.height
                    control2X: notchSurfaceFillTop.insetCenter
                        + continuousBarSurface.insetTipControl
                    control2Y: notchSurfaceFillTop.height
                        - continuousBarSurface.insetDepth
                }
                PathCubic {
                    x: notchSurfaceFillTop.insetCenter
                        - continuousBarSurface.insetHalfWidth
                    y: notchSurfaceFillTop.height
                    control1X: notchSurfaceFillTop.insetCenter
                        - continuousBarSurface.insetTipControl
                    control1Y: notchSurfaceFillTop.height
                        - continuousBarSurface.insetDepth
                    control2X: notchSurfaceFillTop.insetCenter
                        - continuousBarSurface.insetTangentControl
                    control2Y: notchSurfaceFillTop.height
                }
                PathLine {
                    x: notchSurfaceFillTop.bodyLeft + barSlot.notchBodyRadius
                    y: notchSurfaceFillTop.height
                }
                PathCubic {
                    x: notchSurfaceFillTop.bodyLeft - barSlot.notchShoulderWidth
                    y: 0
                    control1X: notchSurfaceFillTop.bodyLeft
                        - (1 - barSlot.notchCurveKappa) * barSlot.notchBodyRadius
                    control1Y: notchSurfaceFillTop.height
                    control2X: notchSurfaceFillTop.bodyLeft
                        - (1 - barSlot.notchCurveKappa) * barSlot.notchShoulderWidth
                    control2Y: 0
                }
            }
        }

        // NOTCH / BOTTOM: exact vertical mirror of the same silhouette.
        Shape {
            id: notchSurfaceFillBottom
            visible: barSlot.root.barShellStyle === "notch"
                && barSlot.root.barPosition === "bottom"
            x: -continuousBarSurface.x
            y: 0
            width: barSlot.width
            height: barSlot.root.v2BarHeight
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            readonly property real bodyLeft: continuousBarSurface.x
            readonly property real bodyRight:
                continuousBarSurface.x + continuousBarSurface.width
            readonly property real insetCenter:
                continuousBarSurface.x + continuousBarSurface.insetCenter

            ShapePath {
                strokeColor: "transparent"
                fillColor: barSlot.root.barBg
                startX: notchSurfaceFillBottom.bodyLeft - barSlot.notchShoulderWidth
                startY: notchSurfaceFillBottom.height
                PathLine {
                    x: notchSurfaceFillBottom.bodyRight + barSlot.notchShoulderWidth
                    y: notchSurfaceFillBottom.height
                }
                PathCubic {
                    x: notchSurfaceFillBottom.bodyRight - barSlot.notchBodyRadius
                    y: 0
                    control1X: notchSurfaceFillBottom.bodyRight
                        + (1 - barSlot.notchCurveKappa) * barSlot.notchShoulderWidth
                    control1Y: notchSurfaceFillBottom.height
                    control2X: notchSurfaceFillBottom.bodyRight
                        + (1 - barSlot.notchCurveKappa) * barSlot.notchBodyRadius
                    control2Y: 0
                }
                PathLine {
                    x: notchSurfaceFillBottom.insetCenter
                        + continuousBarSurface.insetHalfWidth
                    y: 0
                }
                PathCubic {
                    x: notchSurfaceFillBottom.insetCenter
                    y: continuousBarSurface.insetDepth
                    control1X: notchSurfaceFillBottom.insetCenter
                        + continuousBarSurface.insetTangentControl
                    control1Y: 0
                    control2X: notchSurfaceFillBottom.insetCenter
                        + continuousBarSurface.insetTipControl
                    control2Y: continuousBarSurface.insetDepth
                }
                PathCubic {
                    x: notchSurfaceFillBottom.insetCenter
                        - continuousBarSurface.insetHalfWidth
                    y: 0
                    control1X: notchSurfaceFillBottom.insetCenter
                        - continuousBarSurface.insetTipControl
                    control1Y: continuousBarSurface.insetDepth
                    control2X: notchSurfaceFillBottom.insetCenter
                        - continuousBarSurface.insetTangentControl
                    control2Y: 0
                }
                PathLine {
                    x: notchSurfaceFillBottom.bodyLeft + barSlot.notchBodyRadius
                    y: 0
                }
                PathCubic {
                    x: notchSurfaceFillBottom.bodyLeft - barSlot.notchShoulderWidth
                    y: notchSurfaceFillBottom.height
                    control1X: notchSurfaceFillBottom.bodyLeft
                        - (1 - barSlot.notchCurveKappa) * barSlot.notchBodyRadius
                    control1Y: 0
                    control2X: notchSurfaceFillBottom.bodyLeft
                        - (1 - barSlot.notchCurveKappa) * barSlot.notchShoulderWidth
                    control2Y: notchSurfaceFillBottom.height
                }
            }
        }

        // Fit receives a complete rounded perimeter except for the active
        // desktop-facing edge, which edgeBorder owns so its animated panel
        // indentation remains one continuous antialiased path. Dock is attached
        // squarely; Notch traces its short neck and softly sloped shoulders.
        Shape {
            id: compactOuterFrame
            x: barSlot.root.barShellStyle === "notch" ? -continuousBarSurface.x : 0
            y: 0
            width: parent.width + (barSlot.root.barShellStyle === "notch"
                ? barSlot.width - parent.width : 0)
            height: parent.height
            visible: barSlot.compactShell && barSlot.root.barBorderEnabled
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            z: 2

            readonly property real r: continuousBarSurface.radius
            readonly property real w: width
            readonly property real h: height
            readonly property real notchBodyLeft: continuousBarSurface.x
            readonly property real notchBodyRight:
                continuousBarSurface.x + continuousBarSurface.width

            // FIT / TOP: bottom horizontal edge is rendered by edgeBorder.
            ShapePath {
                strokeColor: barSlot.root.barShellStyle === "fit"
                    && barSlot.root.barPosition === "top"
                    ? barSlot.root.v2BarBorder : "transparent"
                strokeWidth: 1
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin
                startX: compactOuterFrame.r
                startY: compactOuterFrame.h - 0.5
                PathQuad { x: 0.5; y: compactOuterFrame.h - compactOuterFrame.r; controlX: 0.5; controlY: compactOuterFrame.h - 0.5 }
                PathLine { x: 0.5; y: compactOuterFrame.r }
                PathQuad { x: compactOuterFrame.r; y: 0.5; controlX: 0.5; controlY: 0.5 }
                PathLine { x: compactOuterFrame.w - compactOuterFrame.r; y: 0.5 }
                PathQuad { x: compactOuterFrame.w - 0.5; y: compactOuterFrame.r; controlX: compactOuterFrame.w - 0.5; controlY: 0.5 }
                PathLine { x: compactOuterFrame.w - 0.5; y: compactOuterFrame.h - compactOuterFrame.r }
                PathQuad { x: compactOuterFrame.w - compactOuterFrame.r; y: compactOuterFrame.h - 0.5; controlX: compactOuterFrame.w - 0.5; controlY: compactOuterFrame.h - 0.5 }
            }

            // FIT / BOTTOM: top horizontal edge is rendered by edgeBorder.
            ShapePath {
                strokeColor: barSlot.root.barShellStyle === "fit"
                    && barSlot.root.barPosition === "bottom"
                    ? barSlot.root.v2BarBorder : "transparent"
                strokeWidth: 1
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin
                startX: compactOuterFrame.r
                startY: 0.5
                PathQuad { x: 0.5; y: compactOuterFrame.r; controlX: 0.5; controlY: 0.5 }
                PathLine { x: 0.5; y: compactOuterFrame.h - compactOuterFrame.r }
                PathQuad { x: compactOuterFrame.r; y: compactOuterFrame.h - 0.5; controlX: 0.5; controlY: compactOuterFrame.h - 0.5 }
                PathLine { x: compactOuterFrame.w - compactOuterFrame.r; y: compactOuterFrame.h - 0.5 }
                PathQuad { x: compactOuterFrame.w - 0.5; y: compactOuterFrame.h - compactOuterFrame.r; controlX: compactOuterFrame.w - 0.5; controlY: compactOuterFrame.h - 0.5 }
                PathLine { x: compactOuterFrame.w - 0.5; y: compactOuterFrame.r }
                PathQuad { x: compactOuterFrame.w - compactOuterFrame.r; y: 0.5; controlX: compactOuterFrame.w - 0.5; controlY: 0.5 }
            }

            // DOCK / TOP: square at the screen, rounded toward the desktop.
            ShapePath {
                strokeColor: barSlot.root.barShellStyle === "dock"
                    && barSlot.root.barPosition === "top"
                    ? barSlot.root.v2BarBorder : "transparent"
                strokeWidth: 1; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                startX: 0.5; startY: 0
                PathLine { x: 0.5; y: compactOuterFrame.h - compactOuterFrame.r }
                PathQuad { x: compactOuterFrame.r; y: compactOuterFrame.h - 0.5; controlX: 0.5; controlY: compactOuterFrame.h - 0.5 }
            }
            ShapePath {
                strokeColor: barSlot.root.barShellStyle === "dock"
                    && barSlot.root.barPosition === "top"
                    ? barSlot.root.v2BarBorder : "transparent"
                strokeWidth: 1; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                startX: compactOuterFrame.w - 0.5; startY: 0
                PathLine { x: compactOuterFrame.w - 0.5; y: compactOuterFrame.h - compactOuterFrame.r }
                PathQuad { x: compactOuterFrame.w - compactOuterFrame.r; y: compactOuterFrame.h - 0.5; controlX: compactOuterFrame.w - 0.5; controlY: compactOuterFrame.h - 0.5 }
            }

            // DOCK / BOTTOM: mirrored attached edge.
            ShapePath {
                strokeColor: barSlot.root.barShellStyle === "dock"
                    && barSlot.root.barPosition === "bottom"
                    ? barSlot.root.v2BarBorder : "transparent"
                strokeWidth: 1; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                startX: 0.5; startY: compactOuterFrame.h
                PathLine { x: 0.5; y: compactOuterFrame.r }
                PathQuad { x: compactOuterFrame.r; y: 0.5; controlX: 0.5; controlY: 0.5 }
            }
            ShapePath {
                strokeColor: barSlot.root.barShellStyle === "dock"
                    && barSlot.root.barPosition === "bottom"
                    ? barSlot.root.v2BarBorder : "transparent"
                strokeWidth: 1; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                startX: compactOuterFrame.w - 0.5; startY: compactOuterFrame.h
                PathLine { x: compactOuterFrame.w - 0.5; y: compactOuterFrame.r }
                PathQuad { x: compactOuterFrame.w - compactOuterFrame.r; y: 0.5; controlX: compactOuterFrame.w - 0.5; controlY: 0.5 }
            }

            // NOTCH / TOP: the border follows the same single fused silhouette.
            ShapePath {
                strokeColor: barSlot.root.barShellStyle === "notch"
                    && barSlot.root.barPosition === "top"
                    ? barSlot.root.v2BarBorder : "transparent"
                strokeWidth: 1; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                startX: compactOuterFrame.notchBodyLeft - barSlot.notchShoulderWidth
                startY: 0.5
                PathCubic {
                    x: compactOuterFrame.notchBodyLeft + barSlot.notchBodyRadius
                    y: compactOuterFrame.h - 0.5
                    control1X: compactOuterFrame.notchBodyLeft
                        - (1 - barSlot.notchCurveKappa) * barSlot.notchShoulderWidth
                    control1Y: 0.5
                    control2X: compactOuterFrame.notchBodyLeft
                        - (1 - barSlot.notchCurveKappa) * barSlot.notchBodyRadius
                    control2Y: compactOuterFrame.h - 0.5
                }
            }
            ShapePath {
                strokeColor: barSlot.root.barShellStyle === "notch"
                    && barSlot.root.barPosition === "top"
                    ? barSlot.root.v2BarBorder : "transparent"
                strokeWidth: 1; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                startX: compactOuterFrame.notchBodyRight + barSlot.notchShoulderWidth
                startY: 0.5
                PathCubic {
                    x: compactOuterFrame.notchBodyRight - barSlot.notchBodyRadius
                    y: compactOuterFrame.h - 0.5
                    control1X: compactOuterFrame.notchBodyRight
                        + (1 - barSlot.notchCurveKappa) * barSlot.notchShoulderWidth
                    control1Y: 0.5
                    control2X: compactOuterFrame.notchBodyRight
                        + (1 - barSlot.notchCurveKappa) * barSlot.notchBodyRadius
                    control2Y: compactOuterFrame.h - 0.5
                }
            }

            // NOTCH / BOTTOM: exact vertical mirror.
            ShapePath {
                strokeColor: barSlot.root.barShellStyle === "notch"
                    && barSlot.root.barPosition === "bottom"
                    ? barSlot.root.v2BarBorder : "transparent"
                strokeWidth: 1; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                startX: compactOuterFrame.notchBodyLeft - barSlot.notchShoulderWidth
                startY: compactOuterFrame.h - 0.5
                PathCubic {
                    x: compactOuterFrame.notchBodyLeft + barSlot.notchBodyRadius
                    y: 0.5
                    control1X: compactOuterFrame.notchBodyLeft
                        - (1 - barSlot.notchCurveKappa) * barSlot.notchShoulderWidth
                    control1Y: compactOuterFrame.h - 0.5
                    control2X: compactOuterFrame.notchBodyLeft
                        - (1 - barSlot.notchCurveKappa) * barSlot.notchBodyRadius
                    control2Y: 0.5
                }
            }
            ShapePath {
                strokeColor: barSlot.root.barShellStyle === "notch"
                    && barSlot.root.barPosition === "bottom"
                    ? barSlot.root.v2BarBorder : "transparent"
                strokeWidth: 1; fillColor: "transparent"; capStyle: ShapePath.FlatCap
                startX: compactOuterFrame.notchBodyRight + barSlot.notchShoulderWidth
                startY: compactOuterFrame.h - 0.5
                PathCubic {
                    x: compactOuterFrame.notchBodyRight - barSlot.notchBodyRadius
                    y: 0.5
                    control1X: compactOuterFrame.notchBodyRight
                        + (1 - barSlot.notchCurveKappa) * barSlot.notchShoulderWidth
                    control1Y: compactOuterFrame.h - 0.5
                    control2X: compactOuterFrame.notchBodyRight
                        + (1 - barSlot.notchCurveKappa) * barSlot.notchBodyRadius
                    control2Y: 0.5
                }
            }
        }

        Item {
            id: edgeBorder
            readonly property bool popupScreenActive:
                barSlot.root.isActivePopupScreenName(barSlot.screen ? barSlot.screen.name : "")
            readonly property real curvedInsetReveal: popupScreenActive
                ? barSlot.root.panelInsetReveal
                : 0
            readonly property real curvedInsetAnchor: barSlot.root.panelInsetX
            readonly property bool curvedInsetRendering: popupScreenActive
                && barSlot.root.panelInsetReady
                && curvedInsetAnchor > 0
                && (barSlot.root.anchoredPanelVisible || curvedInsetReveal > 0.001)
            readonly property real curvedInsetX: Math.max(0, Math.min(width,
                curvedInsetAnchor - continuousBarSurface.x))
            readonly property int curvedInsetPixel: Math.round(curvedInsetX)
            readonly property int endInset: barSlot.root.barShellStyle === "notch"
                ? barSlot.notchBodyRadius
                : barSlot.compactShell ? continuousBarSurface.radius : 0

            x: 0
            y: 0
            width: parent.width
            height: barSlot.root.v2BarHeight

            // Geometry/state owner only. The visible border and connected inset
            // are rendered after the widget island so fills can never cover them.
        }
    }

    // ── dim backdrop while unlocked (edit mode); click empty → lock ──
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: barSlot.root.barUnlocked ? 0.4 : 0.0
        visible: opacity > 0.001
        z: 1
        Behavior on opacity { NumberAnimation { duration: 180 } }
        MouseArea {
            anchors.fill: parent
            enabled: barSlot.root.barUnlocked
            onClicked: barSlot.root.barUnlocked = false
        }
    }

    // ── unlock drag&drop: ghost + state ──
    property bool dragging: false          // ghost visible (incl. snap-back phase)
    property bool dragActive: false        // mouse currently down (follow cursor)
    property Item dragItem: null           // slot content mirrored by the ghost
    property var  srcModel: null           // source region model + index
    property int  srcIndex: -1
    property var  dropModel: null          // current drop-target model + index
    property int  dropIndex: -1
    property real ghostW: 0
    property real ghostH: 0
    property real ghostHomeX: 0
    property real ghostHomeY: 0
    property real ghostX: 0
    property real ghostY: 0
    function beginDrag(item, hx, hy, w, h, sm, si) {
        dragItem = item; ghostW = w; ghostH = h; ghostHomeX = hx; ghostHomeY = hy
        ghostX = hx; ghostY = hy; srcModel = sm; srcIndex = si
        dropModel = null; dropIndex = -1; dragActive = true; dragging = true
    }
    // which slot (model+index) is under a window-point?
    function slotAt(wx, wy) {
        var rows = [leftRowItem, centerRowItem, rightRowItem]
        for (var r = 0; r < rows.length; r++) {
            var rep = rows[r].rep
            for (var k = 0; k < rep.count; k++) {
                var it = rep.itemAt(k)
                if (!it || !it.visible || !it.autoShown) continue
                var p = it.mapToItem(null, 0, 0)
                if (wx >= p.x && wx <= p.x + it.width && wy >= p.y && wy <= p.y + it.height)
                    return { model: rows[r].rmodel, index: k }
            }
        }
        return null
    }
    function moveDrag(wx, wy) {
        ghostX = wx - ghostW / 2; ghostY = wy - ghostH / 2
        var hit = slotAt(wx, wy)
        dropModel = hit ? hit.model : null
        dropIndex = hit ? hit.index : -1
    }
    function endDrag() {
        dragActive = false
        var swapped = false
        if (dropModel && dropIndex >= 0 && !(dropModel === srcModel && dropIndex === srcIndex)) {
            var sg = srcModel.get(srcIndex).gid, tg = dropModel.get(dropIndex).gid
            srcModel.setProperty(srcIndex, "gid", tg)
            dropModel.setProperty(dropIndex, "gid", sg)
            swapped = true
        }
        dropModel = null; dropIndex = -1
        if (swapped) { if (_orderLoaded) saveOrder(); dragging = false }   // content swapped in place + persist
        else { ghostX = ghostHomeX; ghostY = ghostHomeY; snapTimer.restart() }   // snap back
    }
    Timer { id: snapTimer; interval: 240; onTriggered: barSlot.dragging = false }
    // abort a drag with no swap (ESC / ipc lock / backdrop-click while dragging, or a
    // compositor grab-cancel) → clear the ghost immediately so it can't freeze on screen
    function cancelDrag() {
        snapTimer.stop()
        dragActive = false; dragging = false; dragItem = null
        dropModel = null; dropIndex = -1
    }

    // ── order persistence (survives restart) ──
    readonly property string orderCachePath: Quickshell.env("HOME") + "/.cache/quickshell_barorder_v2"
    readonly property int leftBaseSlotCount: 10
    readonly property int centerBaseSlotCount: 1
    readonly property int rightBaseSlotCount: 7
    // Both side regions can reach the same total capacity. The right side has
    // fewer built-in groups, so it receives three more optional slots.
    readonly property int sideSlotCapacity: 13
    readonly property int leftExtraSlotLimit: sideSlotCapacity - leftBaseSlotCount
    readonly property int rightExtraSlotLimit: sideSlotCapacity - rightBaseSlotCount
    readonly property int centerExtraSlotLimit: 3
    property bool _orderLoaded: false
    function modelContains(m, gid) {
        for (var i = 0; i < m.count; i++) if (m.get(i).gid === gid) return true
        return false
    }
    function extraSlotCount(m, baseCount) { return Math.max(0, m.count - baseCount) }
    function serializeModel(m) {
        var slots = []
        for (var i = 0; i < m.count; i++) {
            var row = m.get(i)
            slots.push((row.extra ? "E:" : "B:") + (row.gid === "" ? "_" : row.gid))
        }
        return slots.join(",")
    }
    function serializeOrder() {
        return serializeModel(leftModel) + "|" + serializeModel(centerModel) + "|" + serializeModel(rightModel)
    }
    function parseRegion(raw, baseCount, maxExtraCount, legacy) {
        var tokens = raw === "" ? [] : raw.split(",")
        if (legacy && tokens.length !== baseCount) return null
        if (!legacy && (tokens.length < baseCount
                || tokens.length > baseCount + maxExtraCount)) return null

        var entries = []
        for (var i = 0; i < tokens.length; i++) {
            if (legacy) {
                entries.push({ gid: tokens[i], extra: false })
                continue
            }

            var token = tokens[i]
            if (token.length < 3 || token.charAt(1) !== ":") return null
            var kind = token.charAt(0)
            if ((i < baseCount && kind !== "B") || (i >= baseCount && kind !== "E")) return null
            var gid = token.substring(2)
            entries.push({ gid: gid === "_" ? "" : gid, extra: kind === "E" })
        }
        return entries
    }
    function applyEntries(m, entries) {
        m.clear()
        for (var i = 0; i < entries.length; i++) m.append(entries[i])
    }
    function applyOrder(str) {
        var parts = str.split("|")
        if (parts.length !== 3) return false

        // Accept the initial fixed-width V2 cache once, then write the slot-aware
        // B:/E: format on the next edit. Every new cache must keep the immutable
        // base slots first and stay within its region-specific extra-slot limit.
        var legacy = parts[0].indexOf(":") < 0
        var l = parseRegion(parts[0], leftBaseSlotCount, leftExtraSlotLimit, legacy)
        var c = parseRegion(parts[1], centerBaseSlotCount, centerExtraSlotLimit, legacy)
        var r = parseRegion(parts[2], rightBaseSlotCount, rightExtraSlotLimit, legacy)

        // Migrate the first V2 slot schema (7/1/7 + optional extras) by adding
        // the three new compact telemetry base slots after CPU. Existing widget
        // positions and all user-added slots remain intact.
        if (!l || !c || !r) {
            var previousLeft = parseRegion(parts[0], 7, 3, legacy)
            var previousCenter = parseRegion(parts[1], centerBaseSlotCount,
                centerExtraSlotLimit, legacy)
            var previousRight = parseRegion(parts[2], rightBaseSlotCount, 3, legacy)
            if (!previousLeft || !previousCenter || !previousRight) return false

            var oldBase = previousLeft.slice(0, 7)
            var oldExtras = previousLeft.slice(7)
            l = oldBase.slice(0, 5).concat([
                { gid: "G16", extra: false },
                { gid: "G17", extra: false },
                { gid: "G18", extra: false }
            ], oldBase.slice(5), oldExtras)
            c = previousCenter
            r = previousRight
        }

        // Only accept a complete permutation of G1..G18. Empty slots are legal,
        // but each registered widget must still occur exactly once.
        var all = l.concat(c, r), seen = {}
        for (var i = 0; i < all.length; i++) {
            var gid = all[i].gid
            if (gid === "") continue
            if (!registry[gid] || seen[gid]) return false
            seen[gid] = true
        }
        if (Object.keys(seen).length !== Object.keys(registry).length) return false

        applyEntries(leftModel, l)
        applyEntries(centerModel, c)
        applyEntries(rightModel, r)
        return true
    }
    function saveOrder() {
        var serialized = serializeOrder()
        orderSaveProc.command = ["bash", "-c",
            "mkdir -p \"$(dirname '" + orderCachePath + "')\" && printf '%s' '" + serialized + "' > '" + orderCachePath + "'"]
        orderSaveProc.running = false; orderSaveProc.running = true
        if (!barSlot.root._barLayoutSyncing) barSlot.root.syncBarOrder(barSlot.screenName, serialized)
    }
    Process { id: orderSaveProc }
    Process {
        id: orderLoadProc
        command: ["cat", barSlot.orderCachePath]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim()
                if (t.length > 0) barSlot.applyOrder(t)
                barSlot._orderLoaded = true
            }
        }
    }
    function addExtraSlot(m, baseCount, maxExtraCount) {
        if (!m || extraSlotCount(m, baseCount) >= maxExtraCount) return
        m.append({ gid: "", extra: true })
        if (_orderLoaded) saveOrder()
    }
    function removeExtraSlot(m, index, baseCount) {
        if (!m || index < baseCount || index >= m.count) return
        var row = m.get(index)
        if (!row.extra || row.gid !== "") return
        m.remove(index, 1)
        if (_orderLoaded) saveOrder()
    }
    function resetModel(m, gids, baseCount) {
        m.clear()
        for (var i = 0; i < gids.length; i++)
            m.append({ gid: gids[i], extra: i >= baseCount })
    }
    // Restore the confirmed V2 default snapshot, including its intentional
    // empty base cells and the six optional cells on the right.
    function resetOrder() {
        var dL = ["G1","G2","G3","","G5","G6","G4","G7","",""]
        var dR = ["G9","G10","G11","G14","G12","G13","G16",
                  "G18","G17","G15","","",""]
        resetModel(leftModel, dL, leftBaseSlotCount)
        resetModel(centerModel, ["G8"], centerBaseSlotCount)
        resetModel(rightModel, dR, rightBaseSlotCount)
        if (_orderLoaded) saveOrder()
    }

    property var layoutController: ({
        ready: function () {
            return barSlot._orderLoaded && barSlot.backingWindowVisible
        },
        defaultLayout: function () { barSlot.resetOrder() },
        applyOrder: function (serialized) { barSlot.applyOrder(serialized) }
    })

    Component.onCompleted: {
        if (!barSlot.root.activePopupScreenName) barSlot.root.activatePopupScreen(barSlot.screen)
        barSlot.root.registerBarLayoutController(barSlot.screenName, barSlot.layoutController)
    }

    Component.onDestruction: {
        if (barSlot.root
                && barSlot.root.isActivePopupScreenName(barSlot.screenName)
                && barSlot.root.anyPopupVisible) {
            barSlot.root.closePopups()
        }
        barSlot.root.unregisterBarLayoutController(barSlot.screenName, barSlot.layoutController)
    }

    ShaderEffectSource {
        id: ghost
        sourceItem: barSlot.dragItem
        width: barSlot.ghostW; height: barSlot.ghostH
        x: barSlot.ghostX; y: barSlot.ghostY
        visible: barSlot.dragging
        z: 100
        // dim while dragging over empty space (no valid drop → snap-back)
        opacity: barSlot.dragActive ? (barSlot.dropModel ? 0.95 : 0.45) : 0.92
        scale: barSlot.dragActive ? 1.06 : 1.0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Behavior on x { enabled: !barSlot.dragActive; NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: !barSlot.dragActive; NumberAnimation { duration: 230; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 120 } }
    }

    // ─────────────────────────── group registry ───────────────────────────
    Component {
        id: compLauncher
        LauncherWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: logoPadding / 2
            readonly property real barContentRightInset: logoPadding / 2
        }
    }
    Component {
        id: compWorkspace
        WorkspaceWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 0
            readonly property real barContentRightInset: 0
        }
    }
    Component {
        id: compStatus                                   // G3: arch · tray · notif
        Item {
            id: statusGroup
            readonly property real barContentLeftInset: barSlot.root.v2IconGroupPadding
            readonly property real barContentRightInset: barSlot.root.v2IconGroupPadding
            readonly property real archCaretX: statusRow.x + archWidget.x + archWidget.width / 2
            readonly property real trayCaretX: statusRow.x + statusTrayRow.x + trayWidget.x + trayWidget.width / 2
            readonly property real notifCaretX: statusRow.x + statusTrayRow.x + notifWidget.x + notifWidget.width / 2
            visible: implicitWidth > 0.5
            implicitWidth: barSlot.root.modStatus
                ? Math.round(statusRow.implicitWidth) + 2 * barSlot.root.v2IconGroupPadding
                : 0
            implicitHeight: 28
            opacity: barSlot.root.modStatus ? 1 : 0
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Row {
                id: statusRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)
                spacing: barSlot.root.v2InlineSpacing
                ArchUpdaterWidget  { id: archWidget; root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    id: statusTrayRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: barSlot.root.v2IconClusterSpacing
                    TrayWidget         { id: trayWidget; root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                    NotificationWidget { id: notifWidget; root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
    Component {
        id: compMem
        MemoryWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 8
            readonly property real barContentRightInset: 10
        }
    }
    Component {
        id: compCpu
        CpuWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compCpuTemperature
        CpuTemperatureWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compGpu
        GpuWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compStorage
        StorageWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compVol
        AudioWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compClaude
        ClaudeWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compShellFallbackUpdater
        Item {
            width: 26
            height: 28
            ArchUpdaterWidget {
                root: barSlot.root
                colorGid: "G8"
                preferShell: true
                anchors.centerIn: parent
            }
        }
    }

    Component {
        id: compCenter                                   // G8: weather·clock·date·indicators
        Item {
            id: g8
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
            readonly property color contentColor:
                barSlot.root.widgetContentColor("G8", barSlot.root.ink)
            readonly property real weatherCaretX:
                centerRow.x + weatherSlot.x + weatherSlot.width / 2
            readonly property real calendarCaretX:
                centerRow.x + dateSlot.x + dateSlot.width / 2
            implicitWidth: Math.round(centerRow.implicitWidth) + 18
            implicitHeight: 28

            // ── responsive stage (narrow-monitor overlap fix) ──
            // Presentation-only inside G8 — never touches root.mod* user toggles.
            // Mutable state with hysteresis, NOT a computed property: downshift when
            // the CURRENT stage no longer fits (24px slack), upshift only when the
            // LARGER stage would fit with 48px slack — measured against that stage's
            // own needed width, else minimal⇄compact oscillates.
            property int stage: 0                        // 0 normal · 1 compact · 2 minimal
            readonly property bool showWeather: stage <= 1
            readonly property bool showDate:    stage === 0
            readonly property bool showIcons:   iconsRow.hasActive
            // needed widths per stage: reactive bindings over the UNCOLLAPSED content
            // (the stage-gated wrapper widths shrink and would mislead the upshift
            // decision). 18 = pill padding, 8 = row spacing per visible neighbour.
            readonly property real needMinimal: 18 + clock.implicitWidth
                + (showIcons && iconsRow.implicitWidth > 0.5 ? 8 + iconsRow.implicitWidth : 0)
            readonly property real needCompact: needMinimal
                + (weather.implicitWidth > 0.5 ? 8 + weather.implicitWidth : 0)
            readonly property real needNormal: needCompact
                + (dateLabel.implicitWidth > 0.5 ? 8 + dateLabel.implicitWidth : 0)
            function updateStage() {
                // compact only while G8 actually occupies the center slot: after a
                // drag swap G8 can sit in a SIDE row — its own width then feeds the
                // very side-row width that centerAvail is measured from, and the
                // stage delta (~weather+date) exceeds the 24/48px hysteresis window
                // → boundary-width flutter. As a side widget G8 stays at normal.
                if (!barSlot.modelContains(centerModel, "G8")) {
                    if (stage !== 0) stage = 0
                    return
                }
                var avail = island.g8AvailableWidth
                var s = stage
                if (s === 0 && needNormal  + 24 > avail) s = 1
                if (s === 1 && needCompact + 24 > avail) s = 2
                if (s === 2 && needCompact + 48 <= avail) s = 1
                if (s === 1 && needNormal  + 48 <= avail) s = 0
                if (s !== stage) stage = s
            }
            // publish the clock + status-icon floor width for the side-row budget
            Binding { target: island; property: "g8FloorWidth"; value: g8.needMinimal }
            // 80ms one-shot coalesces width flutter (track changes, tray churn)
            Timer { id: restageTimer; interval: 80; repeat: false; onTriggered: g8.updateStage() }
            onNeedNormalChanged:  restageTimer.restart()
            onNeedCompactChanged: restageTimer.restart()
            Connections { target: island; function onG8AvailableWidthChanged() { restageTimer.restart() } }
            Component.onCompleted: restageTimer.restart()

            Row {
                id: centerRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)   // integer center → sharp text
                spacing: barSlot.root.v2SectionSpacing
                Item {                                   // weather wrapper (stage-gated)
                    id: weatherSlot
                    visible: width > 0.5
                    width: g8.showWeather ? weather.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showWeather ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    WeatherWidget {
                        id: weather
                        anchors.fill: parent
                        root: barSlot.root
                    }
                }
                ClockWidget   { id: clock;   root: barSlot.root }
                Item {                                   // date (stage-gated)
                    id: dateSlot
                    visible: width > 0.5
                    width: g8.showDate ? dateLabel.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showDate ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    UiText {
                        id: dateLabel
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            clock.now;
                            var days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
                            var d = new Date();
                            return days[d.getDay()] + " " + d.getDate();
                        }
                        color: Qt.rgba(g8.contentColor.r, g8.contentColor.g, g8.contentColor.b, 0.5)
                        font.family: barSlot.root.mono
                        font.pixelSize: 10
                        font.letterSpacing: 0.5
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            barSlot.root.activatePopupScreen(barSlot.screen)
                            barSlot.root.calendarTick++;
                            barSlot.root.calendarVisible = !barSlot.root.calendarVisible
                        }
                    }
                }
                Item {                                   // indicator icons wrapper (stage-gated)
                    visible: g8.showIcons || width > 0.5
                    width: g8.showIcons ? iconsRow.implicitWidth : 0
                    height: 28
                    clip: true
                    opacity: g8.showIcons ? 1 : 0
                    Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    Row {
                        id: iconsRow
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: barSlot.root.v2InlineSpacing
                        readonly property bool shellFallbackActive: !barSlot.root.modStatus
                            && (barSlot.root.shellUpdateBehind > 0 || barSlot.root.shellUpdateProgressVisible)
                        readonly property bool hasActive: idleInd.awake
                            || dndInd.silenced
                            || screenRecInd.recording
                            || voxInd.state === "recording"
                            || voxInd.state === "transcribing"
                            || omarchyUpdateInd.updateAvailable
                            || shellFallbackActive
                        IdleWidget               { id: idleInd;          root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        NotificationSilenceWidget{ id: dndInd;           root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        ScreenRecordWidget       { id: screenRecInd;     root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        VoxtypeWidget            { id: voxInd;           root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        UpdateWidget             { id: omarchyUpdateInd; root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                        Loader {
                            visible: iconsRow.shellFallbackActive || width > 0.5
                            active: iconsRow.shellFallbackActive
                            width: iconsRow.shellFallbackActive ? 26 : 0
                            height: 28
                            sourceComponent: compShellFallbackUpdater
                            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: compMpris
        MprisWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: active ? 9 : 8
            readonly property real barContentRightInset: active ? 9 : 8
        }
    }
    Component {
        id: compQuick                                    // G10: idle-inhib · media · theme
        Item {
            readonly property real barContentLeftInset: barSlot.root.v2IconGroupPadding
            readonly property real barContentRightInset: barSlot.root.v2IconGroupPadding
            visible: implicitWidth > 0.5
            implicitWidth: barSlot.root.modQuick
                ? Math.round(qcRow.implicitWidth) + 2 * barSlot.root.v2IconGroupPadding
                : 0
            implicitHeight: 28
            opacity: barSlot.root.modQuick ? 1 : 0
            Behavior on implicitWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Row {
                id: qcRow
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round((parent.width - width) / 2)
                spacing: barSlot.root.v2IconClusterSpacing
                IdleInhibitorWidget { root: barSlot.root; anchors.verticalCenter: parent.verticalCenter }
                MediaBrowserWidget  { root: barSlot.root; screen: barSlot.screen; anchors.verticalCenter: parent.verticalCenter }
                ThemeDisplayWidget  { root: barSlot.root; screen: barSlot.screen; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }
    Component {
        id: compNetwork
        NetworkWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compPower
        PowerProfileWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compBattery
        BatteryWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compBrightness
        BrightnessWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }
    Component {
        id: compBluetooth
        BluetoothWidget {
            root: barSlot.root
            readonly property real barContentLeftInset: 9
            readonly property real barContentRightInset: 9
        }
    }

    readonly property var registry: ({
        "G1": compLauncher, "G2": compWorkspace, "G3": compStatus,
        "G4": compMem, "G5": compCpu, "G6": compVol, "G7": compClaude,
        "G8": compCenter,
        "G9": compMpris, "G10": compQuick, "G11": compNetwork,
        "G12": compBattery, "G13": compBrightness, "G14": compPower, "G15": compBluetooth,
        "G16": compCpuTemperature, "G17": compGpu, "G18": compStorage
    })

    // ───────────────────── reusable region row of slots ─────────────────────
    component SlotRow: Row {
        id: slotRow
        property var rmodel
        property int baseCount
        property int maxExtraCount: 3
        property alias rep: repeater
        readonly property int extraCount: rmodel ? barSlot.extraSlotCount(rmodel, baseCount) : 0
        spacing: barSlot.root.v2WidgetSpacing
        height: 32
        // index of the LAST currently shown slot (skips disabled and auto-hidden
        // narrow-stage widgets) — a separator only makes sense BEFORE this gap.
        readonly property int lastVisibleIndex: {
            void(width)
            var last = -1
            for (var k = 0; k < repeater.count; k++) {
                var it = repeater.itemAt(k)
                if (it && it.hasContent && it.autoShown) last = k
            }
            return last
        }
        function nextVisibleSlot(afterIndex) {
            void(width)
            for (var i = afterIndex + 1; i < repeater.count; i++) {
                var candidate = repeater.itemAt(i)
                if (candidate && candidate.hasContent && candidate.autoShown) return candidate
            }
            return null
        }

        Repeater {
            id: repeater
            model: rmodel
            delegate: Item {
                id: slot
                required property string gid
                required property bool extra
                required property int index
                readonly property bool occupied: gid !== "" && barSlot.registry[gid] !== undefined
                // workspace draws a pill 4px wider than its implicitWidth on each
                // side; pad its slot symmetrically so inter-group gaps stay uniform.
                readonly property int pad: slot.gid === "G2" ? barSlot.root.wsPillPad : 0
                readonly property var contentItem: ldr.item
                readonly property bool hasContent: occupied && Math.round(ldr.implicitWidth) > 0.5
                readonly property real contentLeftInset: contentItem
                    ? contentItem.barContentLeftInset : 0
                readonly property real contentRightInset: contentItem
                    ? contentItem.barContentRightInset : 0
                readonly property bool hasVisualSurface:
                    barSlot.root.widgetHasFill(gid) || barSlot.root.widgetHasBorder(gid)
                readonly property real visualLeftEdge: pad
                    + (hasVisualSurface ? 0 : contentLeftInset)
                readonly property real visualRightEdge: pad
                    + Math.round(ldr.implicitWidth)
                    - (hasVisualSurface ? 0 : contentRightInset)
                readonly property var nextVisualSlot: slotRow.nextVisibleSlot(index)
                readonly property real nextVisualLeftEdge: nextVisualSlot
                    ? nextVisualSlot.x - slot.x + nextVisualSlot.visualLeftEdge
                    : visualRightEdge + slotRow.spacing
                readonly property real unsetSeparatorCenterX:
                    (visualRightEdge + nextVisualLeftEdge) / 2
                readonly property bool placeholderShown: !occupied && barSlot.root.barUnlocked
                // user-set separator after this widget: extra width is part of BOTH
                // width recipes so the narrow-stage budget stays stage-independent.
                readonly property bool sepOn: occupied && barSlot.root.sepAfter(gid)
                readonly property int sepW: 15
                readonly property real naturalSlotWidth: placeholderShown
                    ? 28
                    : Math.round(ldr.implicitWidth) + 2 * pad + (sepOn && hasContent ? sepW : 0)
                // Empty edit slots do not influence the locked narrow-layout budget.
                readonly property real budgetSlotWidth: hasContent
                    ? Math.round(ldr.implicitWidth) + 2 * pad + (sepOn ? sepW : 0)
                    : 0
                readonly property bool autoShown: placeholderShown
                    || (occupied && island.groupVisibleAtStage(slot.gid, island.narrowStage))
                onBudgetSlotWidthChanged: island.scheduleNarrowUpdate()
                width: autoShown ? naturalSlotWidth : 0
                height: 32
                visible: placeholderShown || (hasContent && (autoShown || width > 0.5))
                opacity: autoShown ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                Rectangle {
                    id: widgetColorSurface
                    readonly property real insetLocalX: {
                        void(edgeBorder.curvedInsetPixel)
                        var point = mapFromItem(edgeBorder, edgeBorder.curvedInsetPixel, 0)
                        return point.x
                    }
                    readonly property real edgeBaselineLocalY: {
                        void(edgeBorder.curvedInsetReveal)
                        var edgeY = barSlot.root.barPosition === "bottom"
                            ? 0.5
                            : barSlot.root.v2BarHeight - 0.5
                        return mapFromItem(edgeBorder,
                            edgeBorder.curvedInsetPixel, edgeY).y
                    }
                    readonly property real edgeTipLocalY: {
                        void(edgeBorder.curvedInsetReveal)
                        var edgeY = barSlot.root.barPosition === "bottom"
                            ? 0.5 + 5 * edgeBorder.curvedInsetReveal
                            : barSlot.root.v2BarHeight - 0.5
                                - 5 * edgeBorder.curvedInsetReveal
                        return mapFromItem(edgeBorder,
                            edgeBorder.curvedInsetPixel, edgeY).y
                    }
                    readonly property bool insetCrossesSurface:
                        insetLocalX > radius + 6
                        && insetLocalX < width - radius - 6
                    readonly property bool connectedFillContour:
                        barSlot.root.widgetHasFill(slot.gid)
                        && edgeBorder.curvedInsetRendering
                        && insetCrossesSurface
                    readonly property bool connectedBorderCut:
                        barSlot.root.widgetHasBorder(slot.gid)
                        && edgeBorder.curvedInsetRendering
                        && insetCrossesSurface
                    readonly property real cutHalfWidth:
                        6 * edgeBorder.curvedInsetReveal
                    readonly property real fillCurveHalfWidth:
                        7 * edgeBorder.curvedInsetReveal
                    readonly property real fillCurveTangentControl:
                        4.25 * edgeBorder.curvedInsetReveal
                    readonly property real fillCurveTipControl:
                        2 * edgeBorder.curvedInsetReveal
                    x: slot.pad
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(ldr.implicitWidth)
                    // Keep every optional fill/border surface slightly inset from
                    // the bar edges so all widget treatments share one geometry.
                    height: 24
                    radius: barSlot.root.panelButtonRadius
                    clip: true
                    visible: slot.occupied && slot.hasContent && slot.autoShown
                        && (barSlot.root.widgetHasFill(slot.gid)
                            || barSlot.root.widgetHasBorder(slot.gid))
                    color: connectedFillContour
                        ? "transparent"
                        : barSlot.root.widgetFillColor(slot.gid)
                    border.color: barSlot.root.widgetBorderColor(slot.gid)
                    border.width: barSlot.root.widgetHasBorder(slot.gid)
                        && !connectedBorderCut
                        ? barSlot.root.panelBorderW
                        : 0
                    Behavior on color {
                        enabled: !edgeBorder.curvedInsetRendering
                        ColorAnimation { duration: 140 }
                    }

                    // Use the bar indentation's exact cubic geometry. Its baseline
                    // lies outside this inset 24px surface; clipping therefore keeps
                    // only the tiny real intersection instead of inventing another
                    // caret or a rectangular hole in the widget fill.
                    Shape {
                        anchors.fill: parent
                        visible: widgetColorSurface.connectedFillContour
                            && barSlot.root.barPosition !== "bottom"
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: barSlot.root.widgetFillColor(slot.gid)
                            startX: widgetColorSurface.radius
                            startY: 0
                            PathLine { x: widgetColorSurface.width - widgetColorSurface.radius; y: 0 }
                            PathQuad {
                                x: widgetColorSurface.width; y: widgetColorSurface.radius
                                controlX: widgetColorSurface.width; controlY: 0
                            }
                            PathLine { x: widgetColorSurface.width; y: widgetColorSurface.height - widgetColorSurface.radius }
                            PathQuad {
                                x: widgetColorSurface.width - widgetColorSurface.radius
                                y: widgetColorSurface.height
                                controlX: widgetColorSurface.width
                                controlY: widgetColorSurface.height
                            }
                            PathLine {
                                x: widgetColorSurface.insetLocalX
                                    + widgetColorSurface.fillCurveHalfWidth
                                y: widgetColorSurface.edgeBaselineLocalY
                            }
                            PathCubic {
                                x: widgetColorSurface.insetLocalX
                                y: widgetColorSurface.edgeTipLocalY
                                control1X: widgetColorSurface.insetLocalX
                                    + widgetColorSurface.fillCurveTangentControl
                                control1Y: widgetColorSurface.edgeBaselineLocalY
                                control2X: widgetColorSurface.insetLocalX
                                    + widgetColorSurface.fillCurveTipControl
                                control2Y: widgetColorSurface.edgeTipLocalY
                            }
                            PathCubic {
                                x: widgetColorSurface.insetLocalX
                                    - widgetColorSurface.fillCurveHalfWidth
                                y: widgetColorSurface.edgeBaselineLocalY
                                control1X: widgetColorSurface.insetLocalX
                                    - widgetColorSurface.fillCurveTipControl
                                control1Y: widgetColorSurface.edgeTipLocalY
                                control2X: widgetColorSurface.insetLocalX
                                    - widgetColorSurface.fillCurveTangentControl
                                control2Y: widgetColorSurface.edgeBaselineLocalY
                            }
                            PathLine { x: widgetColorSurface.radius; y: widgetColorSurface.height }
                            PathQuad {
                                x: 0; y: widgetColorSurface.height - widgetColorSurface.radius
                                controlX: 0; controlY: widgetColorSurface.height
                            }
                            PathLine { x: 0; y: widgetColorSurface.radius }
                            PathQuad {
                                x: widgetColorSurface.radius; y: 0
                                controlX: 0; controlY: 0
                            }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        visible: widgetColorSurface.connectedFillContour
                            && barSlot.root.barPosition === "bottom"
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: barSlot.root.widgetFillColor(slot.gid)
                            startX: widgetColorSurface.radius
                            startY: 0
                            PathLine {
                                x: widgetColorSurface.insetLocalX
                                    - widgetColorSurface.fillCurveHalfWidth
                                y: widgetColorSurface.edgeBaselineLocalY
                            }
                            PathCubic {
                                x: widgetColorSurface.insetLocalX
                                y: widgetColorSurface.edgeTipLocalY
                                control1X: widgetColorSurface.insetLocalX
                                    - widgetColorSurface.fillCurveTangentControl
                                control1Y: widgetColorSurface.edgeBaselineLocalY
                                control2X: widgetColorSurface.insetLocalX
                                    - widgetColorSurface.fillCurveTipControl
                                control2Y: widgetColorSurface.edgeTipLocalY
                            }
                            PathCubic {
                                x: widgetColorSurface.insetLocalX
                                    + widgetColorSurface.fillCurveHalfWidth
                                y: widgetColorSurface.edgeBaselineLocalY
                                control1X: widgetColorSurface.insetLocalX
                                    + widgetColorSurface.fillCurveTipControl
                                control1Y: widgetColorSurface.edgeTipLocalY
                                control2X: widgetColorSurface.insetLocalX
                                    + widgetColorSurface.fillCurveTangentControl
                                control2Y: widgetColorSurface.edgeBaselineLocalY
                            }
                            PathLine { x: widgetColorSurface.width - widgetColorSurface.radius; y: 0 }
                            PathQuad {
                                x: widgetColorSurface.width; y: widgetColorSurface.radius
                                controlX: widgetColorSurface.width; controlY: 0
                            }
                            PathLine { x: widgetColorSurface.width; y: widgetColorSurface.height - widgetColorSurface.radius }
                            PathQuad {
                                x: widgetColorSurface.width - widgetColorSurface.radius
                                y: widgetColorSurface.height
                                controlX: widgetColorSurface.width
                                controlY: widgetColorSurface.height
                            }
                            PathLine { x: widgetColorSurface.radius; y: widgetColorSurface.height }
                            PathQuad {
                                x: 0; y: widgetColorSurface.height - widgetColorSurface.radius
                                controlX: 0; controlY: widgetColorSurface.height
                            }
                            PathLine { x: 0; y: widgetColorSurface.radius }
                            PathQuad {
                                x: widgetColorSurface.radius; y: 0
                                controlX: 0; controlY: 0
                            }
                        }
                    }

                    // While this widget's connected panel is open, redraw the
                    // rounded border as one antialiased path with a small gap only
                    // on the panel-facing edge. The gap follows the bar-notch reveal.
                    Shape {
                        anchors.fill: parent
                        visible: widgetColorSurface.connectedBorderCut
                            && barSlot.root.barPosition !== "bottom"
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: barSlot.root.widgetBorderColor(slot.gid)
                            strokeWidth: barSlot.root.panelBorderW
                            fillColor: "transparent"
                            capStyle: ShapePath.FlatCap
                            joinStyle: ShapePath.RoundJoin
                            startX: widgetColorSurface.radius
                            startY: 0.5
                            PathLine { x: widgetColorSurface.width - widgetColorSurface.radius; y: 0.5 }
                            PathArc {
                                x: widgetColorSurface.width - 0.5
                                y: widgetColorSurface.radius
                                radiusX: widgetColorSurface.radius
                                radiusY: widgetColorSurface.radius
                            }
                            PathLine { x: widgetColorSurface.width - 0.5; y: widgetColorSurface.height - widgetColorSurface.radius }
                            PathArc {
                                x: widgetColorSurface.width - widgetColorSurface.radius
                                y: widgetColorSurface.height - 0.5
                                radiusX: widgetColorSurface.radius
                                radiusY: widgetColorSurface.radius
                            }
                            PathLine {
                                x: widgetColorSurface.insetLocalX + widgetColorSurface.cutHalfWidth
                                y: widgetColorSurface.height - 0.5
                            }
                            PathMove {
                                x: widgetColorSurface.insetLocalX - widgetColorSurface.cutHalfWidth
                                y: widgetColorSurface.height - 0.5
                            }
                            PathLine { x: widgetColorSurface.radius; y: widgetColorSurface.height - 0.5 }
                            PathArc {
                                x: 0.5
                                y: widgetColorSurface.height - widgetColorSurface.radius
                                radiusX: widgetColorSurface.radius
                                radiusY: widgetColorSurface.radius
                            }
                            PathLine { x: 0.5; y: widgetColorSurface.radius }
                            PathArc {
                                x: widgetColorSurface.radius
                                y: 0.5
                                radiusX: widgetColorSurface.radius
                                radiusY: widgetColorSurface.radius
                            }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        visible: widgetColorSurface.connectedBorderCut
                            && barSlot.root.barPosition === "bottom"
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer

                        ShapePath {
                            strokeColor: barSlot.root.widgetBorderColor(slot.gid)
                            strokeWidth: barSlot.root.panelBorderW
                            fillColor: "transparent"
                            capStyle: ShapePath.FlatCap
                            joinStyle: ShapePath.RoundJoin
                            startX: widgetColorSurface.radius
                            startY: 0.5
                            PathLine {
                                x: widgetColorSurface.insetLocalX - widgetColorSurface.cutHalfWidth
                                y: 0.5
                            }
                            PathMove {
                                x: widgetColorSurface.insetLocalX + widgetColorSurface.cutHalfWidth
                                y: 0.5
                            }
                            PathLine { x: widgetColorSurface.width - widgetColorSurface.radius; y: 0.5 }
                            PathArc {
                                x: widgetColorSurface.width - 0.5
                                y: widgetColorSurface.radius
                                radiusX: widgetColorSurface.radius
                                radiusY: widgetColorSurface.radius
                            }
                            PathLine { x: widgetColorSurface.width - 0.5; y: widgetColorSurface.height - widgetColorSurface.radius }
                            PathArc {
                                x: widgetColorSurface.width - widgetColorSurface.radius
                                y: widgetColorSurface.height - 0.5
                                radiusX: widgetColorSurface.radius
                                radiusY: widgetColorSurface.radius
                            }
                            PathLine { x: widgetColorSurface.radius; y: widgetColorSurface.height - 0.5 }
                            PathArc {
                                x: 0.5
                                y: widgetColorSurface.height - widgetColorSurface.radius
                                radiusX: widgetColorSurface.radius
                                radiusY: widgetColorSurface.radius
                            }
                            PathLine { x: 0.5; y: widgetColorSurface.radius }
                            PathArc {
                                x: widgetColorSurface.radius
                                y: 0.5
                                radiusX: widgetColorSurface.radius
                                radiusY: widgetColorSurface.radius
                            }
                        }
                    }
                }

                Loader {
                    id: ldr
                    x: slot.pad
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: slot.occupied ? barSlot.registry[slot.gid] : null
                    // dim the original while its ghost is being dragged
                    opacity: (barSlot.dragItem === ldr && barSlot.dragActive) ? 0.25 : 1.0
                }

                // thin vertical divider, centered in the widened right gap
                Rectangle {
                    visible: slot.sepOn && slot.hasContent && slot.autoShown
                    x: slot.width - slot.pad - 5
                    width: 1
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: sepMa.containsMouse ? barSlot.root.seal : barSlot.root.sep
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // Quiet drop slot in edit mode. Added empty slots can be removed;
                // an empty base slot remains as the return target for its widget.
                Rectangle {
                    id: emptySlot
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: barSlot.root.tileRadius
                    visible: slot.placeholderShown
                    color: removeMa.containsMouse ? barSlot.root.fillHover : barSlot.root.fillIdle
                    border.color: removeMa.containsMouse ? barSlot.root.seal : barSlot.root.sep
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: slot.extra ? "×" : "·"
                        color: removeMa.containsMouse ? barSlot.root.seal : barSlot.root.sumi
                        font.family: barSlot.root.mono
                        font.pixelSize: slot.extra ? 12 : 14
                    }

                    MouseArea {
                        id: removeMa
                        anchors.fill: parent
                        enabled: slot.extra && !barSlot.dragging
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: barSlot.removeExtraSlot(rmodel, slot.index, slotRow.baseCount)
                    }
                }

                // ── drag-catcher: only in unlock mode, overlays the widget ──
                MouseArea {
                    anchors.fill: parent
                    enabled: barSlot.root.barUnlocked && slot.occupied && slot.hasContent && slot.autoShown
                    visible: enabled
                    z: 25
                    preventStealing: true
                    cursorShape: Qt.OpenHandCursor
                    onPressed: {
                        var p = ldr.mapToItem(null, 0, 0)
                        barSlot.beginDrag(ldr, p.x, p.y, Math.round(ldr.implicitWidth), slot.height, rmodel, slot.index)
                    }
                    onPositionChanged: (e) => {
                        if (!barSlot.dragging) return
                        var w = mapToItem(null, e.x, e.y)
                        barSlot.moveDrag(w.x, w.y)
                    }
                    onReleased: barSlot.endDrag()
                    onCanceled: barSlot.cancelDrag()
                }
                // drop-target highlight (the group under the cursor, not the source)
                Rectangle {
                    anchors.fill: parent
                    radius: barSlot.root.pillRadius
                    color: Qt.rgba(barSlot.accent.r, barSlot.accent.g, barSlot.accent.b, 0.18)
                    border.color: barSlot.accent
                    border.width: 2
                    z: 26
                    visible: barSlot.dragging
                        && barSlot.dropModel === rmodel && barSlot.dropIndex === slot.index
                        && !(barSlot.srcModel === rmodel && barSlot.srcIndex === slot.index)
                }

                // ── separator toggle for the gap AFTER this slot (hover-revealed,
                //    V1 split-point pattern — click sets/clears the thin divider) ──
                Item {
                    visible: slot.autoShown && slot.hasContent && slot.index < slotRow.lastVisibleIndex
                    width: 14
                    height: slot.height
                    // The active handle sits exactly over the rendered divider.
                    // For a filled widget, the unset point follows the fill's real
                    // right edge instead of an independently reconstructed width.
                    x: slot.sepOn
                        ? Math.round(slot.width - slot.pad - 4.5 - width / 2)
                        : slot.unsetSeparatorCenterX - width / 2
                    z: 30
                    Text {
                        anchors.centerIn: parent
                        visible: !slot.sepOn
                        text: "•"
                        color: barSlot.root.sumi
                        font.pixelSize: 10; font.family: barSlot.root.mono
                        opacity: sepMa.containsMouse ? 0.9 : 0.0          // hover-revealed
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: sepMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: barSlot.root.toggleSep(slot.gid)
                    }
                }
            }
        }

        Rectangle {
            id: addSlot
            width: visible ? 28 : 0
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            radius: barSlot.root.tileRadius
            visible: barSlot.root.barUnlocked
                && slotRow.extraCount < slotRow.maxExtraCount
            color: addMa.containsMouse ? barSlot.root.fillActive : barSlot.root.fillIdle
            border.color: addMa.containsMouse ? barSlot.root.seal : barSlot.root.sep
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "+"
                color: addMa.containsMouse ? barSlot.root.seal : barSlot.root.ink
                font.family: barSlot.root.mono
                font.pixelSize: 14
            }

            MouseArea {
                id: addMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: barSlot.addExtraSlot(rmodel, slotRow.baseCount,
                    slotRow.maxExtraCount)
            }
        }
    }

    Item {
        id: island
        // The backing layer-window remains full-screen, but the visible/content
        // island follows the selected shell surface. This preserves stable
        // layer-shell resources while Fit/Notch resize with their visible rows.
        x: continuousBarSurface.x
        width: continuousBarSurface.width
        height: barSlot.root.v2BarHeight
        y: barSlot.root.barPosition === "bottom" ? parent.height - height : 0
        z: 2                                  // above the dim backdrop
        focus: barSlot.root.barUnlocked       // receive keys while unlocked
        Keys.onEscapePressed: barSlot.root.barUnlocked = false

        readonly property int fitPadding: 8
        readonly property int fitRegionGap: 12
        readonly property int fitRegionCount:
            (leftRowItem.implicitWidth > 0.5 ? 1 : 0)
            + (centerRowItem.implicitWidth > 0.5 ? 1 : 0)
            + (rightRowItem.implicitWidth > 0.5 ? 1 : 0)
        readonly property real fitNaturalWidth: Math.ceil(
            2 * fitPadding
            + leftRowItem.implicitWidth + centerRowItem.implicitWidth + rightRowItem.implicitWidth
            + Math.max(0, fitRegionCount - 1) * fitRegionGap)

        // edit-mode frame around the bar while unlocked (gentle pulse)
        Rectangle {
            anchors.fill: parent
            radius: barSlot.compactShell ? barSlot.shellRadius : 0
            color: "transparent"
            border.color: barSlot.accent
            border.width: barSlot.root.barUnlocked ? 1 : 0    // width 0 hides it when locked
            z: 40
            SequentialAnimation on opacity {
                running: barSlot.root.barUnlocked
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.45; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
            }
        }

        // DOUBLE-click EMPTY bar area → unlock (sits below widgets and edit slots).
        // double-click so a stray single click while aiming for Control/Volume can't
        // accidentally trigger unlock. (lock again via dim backdrop click / ESC.)
        MouseArea {
            anchors.fill: parent
            z: -1
            onDoubleClicked: barSlot.root.barUnlocked = true
        }

        // ── Center-region collision handling (narrow-monitor overlap fix) ──
        // free span between the side rows; the only stage-decision input — reads
        // ONLY left/right geometry (never the center row), so stage changes that
        // resize G8 cannot feed back into this value (no binding loop).
        readonly property int centerGap: 12
        // Pull the first and last groups 2px closer to the physical screen edge.
        readonly property int rowMargin: 5
        readonly property real centerAvail: barSlot.compactShell
            ? Math.max(0, barSlot.width - 2 * barSlot.shellOuterMargin
                - 2 * fitPadding - leftRowItem.implicitWidth - rightRowItem.implicitWidth
                - 2 * fitRegionGap)
            : rightRowItem.x - (leftRowItem.x + leftRowItem.width) - 2 * centerGap
        readonly property real centerOtherBudgetWidth: {
            var sum = 0, visibleCount = 0
            for (var i = 0; i < centerRowItem.rep.count; i++) {
                var item = centerRowItem.rep.itemAt(i)
                if (!item || !item.hasContent) continue
                if (!groupVisibleAtStage(item.gid, narrowStage)) continue
                visibleCount++
                if (item.gid !== "G8") sum += item.budgetSlotWidth
            }
            return sum + Math.max(0, visibleCount - 1) * centerRowItem.spacing
        }
        // G8 may occupy any center slot after drag & drop. Reserve the other
        // center widgets first so its internal responsive stage sees real space.
        readonly property real g8AvailableWidth: Math.max(0, centerAvail - centerOtherBudgetWidth)
        // centered while space allows; clamped between the rows when squeezed.
        // If even the current G8 width cannot fit (max < min), fall back to the
        // screen-clamped ideal — the documented extreme case may overlap.
        readonly property real idealCenterX: Math.round((width - centerRowItem.width) / 2)
        readonly property real minCenterX: Math.round(leftRowItem.x + leftRowItem.width + centerGap)
        readonly property real maxCenterX: Math.round(rightRowItem.x - centerGap - centerRowItem.width)
        readonly property real centerTargetX: maxCenterX < minCenterX
            ? Math.max(4, Math.min(idealCenterX, width - centerRowItem.width - 4))
            : Math.max(minCenterX, Math.min(idealCenterX, maxCenterX))

        // ── side-row auto-compact (portrait/narrow) ──
        // Presentation-only stages that hide low-priority side groups when the bar
        // would otherwise overflow. Never touches root.mod* toggles, models, order
        // or slot persistence. Budgets are summed from stage-independent budgetSlotWidth
        // values — never from the collapsed row widths — so hiding a group cannot
        // feed back into its own decision (same anti-flutter rule as the G8 stage).
        property int narrowStage: 0            // 0 normal · 1 compact · 2 portrait · 3 emergency
        property real g8FloorWidth: 80         // published by G8: its clock-only minimal width
        function groupVisibleAtStage(gid, stage) {
            if (gid === "G8") return true                                        // clock has its own stages
            if (stage <= 0) return true
            if (stage === 1) return ["G7", "G9", "G10"].indexOf(gid) < 0         // drop AI · MPRIS · Quick
            if (stage === 2) return ["G4", "G7", "G9", "G10", "G17", "G18"].indexOf(gid) < 0   // also MEM · GPU · HDD
            return ["G1", "G2", "G6", "G8", "G11", "G14"].indexOf(gid) >= 0      // emergency whitelist
        }
        function sideNaturalWidth(row, stage) {
            var sum = 0, n = 0
            for (var k = 0; k < row.rep.count; k++) {
                var it = row.rep.itemAt(k)
                if (!it || !it.hasContent) continue
                if (!groupVisibleAtStage(it.gid, stage)) continue
                sum += it.budgetSlotWidth; n++
            }
            return sum + Math.max(0, n - 1) * row.spacing
        }
        function centerFloorWidth(stage) {
            var sum = 0, n = 0
            for (var k = 0; k < centerRowItem.rep.count; k++) {
                var it = centerRowItem.rep.itemAt(k)
                if (!it || !it.hasContent) continue
                if (!groupVisibleAtStage(it.gid, stage)) continue
                sum += it.gid === "G8" ? g8FloorWidth : it.budgetSlotWidth
                n++
            }
            return sum + Math.max(0, n - 1) * centerRowItem.spacing
        }
        function narrowCandidateWidth(stage) {
            // side rows + minimal viable center row + margins + center gaps
            return sideNaturalWidth(leftRowItem, stage) + sideNaturalWidth(rightRowItem, stage)
                 + centerFloorWidth(stage)
                 + (barSlot.compactShell
                    ? 2 * fitRegionGap + 2 * fitPadding
                    : 2 * centerGap + 2 * rowMargin)
        }
        function updateNarrowStage() {
            // Fit/Notch compare against the available SCREEN width, never their
            // own content-driven width. Otherwise hiding a group would shrink
            // the measurement that decided to hide it and create a feedback loop.
            var s = narrowStage
            var W = barSlot.compactShell
                ? barSlot.width - 2 * barSlot.shellOuterMargin
                : island.width
            if (W < 1) return                              // no layout yet
            // downshift while the CURRENT stage no longer fits (24px slack)…
            if (s === 0 && narrowCandidateWidth(0) + 24 > W) s = 1
            if (s === 1 && narrowCandidateWidth(1) + 24 > W) s = 2
            if (s === 2 && narrowCandidateWidth(2) + 24 > W) s = 3
            // …upshift only when the NEXT-LARGER stage fits with 48px slack,
            // measured against that stage's own candidate width.
            if (s === 3 && narrowCandidateWidth(2) + 48 <= W) s = 2
            if (s === 2 && narrowCandidateWidth(1) + 48 <= W) s = 1
            if (s === 1 && narrowCandidateWidth(0) + 48 <= W) s = 0
            if (s !== narrowStage) narrowStage = s
        }
        function scheduleNarrowUpdate() { narrowTimer.restart() }
        Timer { id: narrowTimer; interval: 80; repeat: false; onTriggered: island.updateNarrowStage() }
        onWidthChanged: scheduleNarrowUpdate()
        onG8FloorWidthChanged: scheduleNarrowUpdate()
        Connections {
            target: barSlot.root
            function onBarShellStyleChanged() { island.scheduleNarrowUpdate() }
        }

        // ── region models (physical L→R order) ──
        ListModel {
            id: leftModel
            ListElement { gid: "G1"; extra: false } ListElement { gid: "G2"; extra: false } ListElement { gid: "G3"; extra: false }
            ListElement { gid: ""; extra: false }   ListElement { gid: "G5"; extra: false } ListElement { gid: "G6"; extra: false }
            ListElement { gid: "G4"; extra: false } ListElement { gid: "G7"; extra: false } ListElement { gid: ""; extra: false }
            ListElement { gid: ""; extra: false }
        }
        ListModel { id: centerModel; ListElement { gid: "G8"; extra: false } }
        ListModel {
            id: rightModel
            ListElement { gid: "G9"; extra: false }  ListElement { gid: "G10"; extra: false } ListElement { gid: "G11"; extra: false }
            ListElement { gid: "G14"; extra: false } ListElement { gid: "G12"; extra: false } ListElement { gid: "G13"; extra: false }
            ListElement { gid: "G16"; extra: false } ListElement { gid: "G18"; extra: true }  ListElement { gid: "G17"; extra: true }
            ListElement { gid: "G15"; extra: true }  ListElement { gid: ""; extra: true }     ListElement { gid: ""; extra: true }
            ListElement { gid: ""; extra: true }
        }

        SlotRow {
            id: leftRowItem
            anchors.verticalCenter: parent.verticalCenter
            x: barSlot.compactShell ? island.fitPadding : island.rowMargin
            rmodel: leftModel
            baseCount: barSlot.leftBaseSlotCount
            maxExtraCount: barSlot.leftExtraSlotLimit
        }
        SlotRow {
            id: centerRowItem
            // no centerIn: x is clamped between the side rows on narrow monitors
            anchors.verticalCenter: parent.verticalCenter
            x: barSlot.compactShell
                ? leftRowItem.x + leftRowItem.implicitWidth
                    + (leftRowItem.implicitWidth > 0.5 ? island.fitRegionGap : 0)
                : island.centerTargetX
            Behavior on x {
                enabled: !barSlot.compactShell
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }
            rmodel: centerModel
            baseCount: barSlot.centerBaseSlotCount
            maxExtraCount: barSlot.centerExtraSlotLimit
        }
        SlotRow {
            id: rightRowItem
            anchors.verticalCenter: parent.verticalCenter
            x: barSlot.compactShell
                ? island.fitPadding
                    + leftRowItem.implicitWidth
                    + (leftRowItem.implicitWidth > 0.5 ? island.fitRegionGap : 0)
                    + centerRowItem.implicitWidth
                    + (centerRowItem.implicitWidth > 0.5 ? island.fitRegionGap : 0)
                : island.width - island.rowMargin - implicitWidth
            rmodel: rightModel
            baseCount: barSlot.rightBaseSlotCount
            maxExtraCount: barSlot.rightExtraSlotLimit
        }

        // ── slot-aware panel X positions: publish per-screen anchors ──
        // find a group's slot and map its (frac·width) to window/screen X.
        function groupX(gid, frac) {
            var rows = [leftRowItem, centerRowItem, rightRowItem]
            for (var r = 0; r < rows.length; r++) {
                var row = rows[r]
                var rep = row.rep
                if (!rep) continue
                for (var k = 0; k < rep.count; k++) {
                    var it = rep.itemAt(k)
                    if (it && it.gid === gid) {
                        return island.x + row.x + it.x + it.width * frac
                    }
                }
            }
            return 0
        }

        // Some composite groups contain several independent panel triggers.
        // Read their exact local center instead of pointing every panel at the
        // center of the entire group.
        function groupContentX(gid, propertyName, fallbackFrac) {
            var rows = [leftRowItem, centerRowItem, rightRowItem]
            for (var r = 0; r < rows.length; r++) {
                var row = rows[r]
                var rep = row.rep
                if (!rep) continue
                for (var k = 0; k < rep.count; k++) {
                    var it = rep.itemAt(k)
                    if (it && it.gid === gid && it.contentItem
                            && it.contentItem[propertyName] !== undefined) {
                        return island.x + row.x + it.x + it.pad
                            + Number(it.contentItem[propertyName])
                    }
                }
            }
            return groupX(gid, fallbackFrac)
        }

        readonly property string panelScreenName: barSlot.screen ? barSlot.screen.name : ""
        readonly property var panelAnchors: {
            void(island.width)
            void(island.x)
            void(leftRowItem.x); void(centerRowItem.x); void(rightRowItem.x)
            void(leftRowItem.width); void(centerRowItem.width); void(rightRowItem.width)
            return {
                tray:         island.groupX("G3",  0.0),
                trayCaret:    island.groupContentX("G3", "trayCaretX", 0.5),
                notif:        island.groupX("G3",  0.0),
                notifCaret:   island.groupContentX("G3", "notifCaretX", 0.5),
                quickActions: island.groupX("G10", 0.5),
                volume:       island.groupX("G6",  0.5),
                network:      island.groupX("G11", 0.5),
                battery:      island.groupX("G12", 0.5),
                memory:       island.groupX("G4",  0.5),
                cpu:          island.groupX("G5",  0.5),
                gpu:          island.groupX("G17", 0.5),
                thermal:      island.groupX("G16", 0.5),
                storage:      island.groupX("G18", 0.5),
                ai:           island.groupX("G7",  0.5),
                workspace:    island.groupX("G2",  0.5),
                arch:         island.groupX("G3",  0.5),
                archCaret:    island.groupContentX("G3", "archCaretX", 0.5),
                bluetooth:    island.groupX("G15", 0.5),
                brightness:   island.groupX("G13", 0.5),
                power:        island.groupX("G14", 0.5),
                mpris:        island.groupX("G9",  0.5),
                weather:      island.groupContentX("G8", "weatherCaretX", 0.5),
                calendar:     island.groupContentX("G8", "calendarCaretX", 0.5),
                launcher:     island.groupX("G1",  0.5)
            }
        }
        onPanelAnchorsChanged: barSlot.root.publishBarAnchors(panelScreenName, panelAnchors)
        Component.onCompleted: barSlot.root.publishBarAnchors(panelScreenName, panelAnchors)

        // ── reactor / gap-stream layer (barAnim modes 1-8) ──
        // Runs = the widget clusters; the stream flows in the dead space between
        // them. z:1 places it above the widget rows and below the edit-mode frame
        // and screen chrome — the same z ordering V1's particleLayer uses inside
        // its island. Idle unless an animation is picked and the bar is on screen.
        ReactorLayer {
            anchors.fill: parent
            z: 1
            theme: barSlot.root
            leftRow: leftRowItem
            centerRow: centerRowItem
            rightRow: rightRowItem
            monitor: barSlot.screenName
            shellVisible: barSlot.visible
        }

    }

    // The screen-facing edge is the final visual layer of the bar. Keeping this
    // separate from the filled surface lets ordinary widget fills remain simple
    // rounded rectangles while the connected indentation always stays visible.
    Item {
        id: foregroundEdgeBorder
        x: continuousBarSurface.x
        y: continuousBarSurface.y
        width: continuousBarSurface.width
        height: barSlot.root.v2BarHeight
        visible: barSlot.root.barBorderEnabled
        z: 3

        Rectangle {
            x: edgeBorder.endInset
            y: barSlot.root.barPosition === "bottom" ? 0 : foregroundEdgeBorder.height - 1
            width: edgeBorder.curvedInsetRendering
                ? Math.max(0, edgeBorder.curvedInsetPixel - 12 - x)
                : Math.max(0, parent.width - edgeBorder.endInset - x)
            height: 1
            color: barSlot.root.v2BarBorder
        }

        Rectangle {
            visible: edgeBorder.curvedInsetRendering
            x: Math.max(edgeBorder.endInset, Math.min(parent.width - edgeBorder.endInset,
                edgeBorder.curvedInsetPixel + 12))
            y: barSlot.root.barPosition === "bottom" ? 0 : foregroundEdgeBorder.height - 1
            width: Math.max(0, parent.width - edgeBorder.endInset - x)
            height: 1
            color: barSlot.root.v2BarBorder
        }

        ConnectedBarInset {
            root: barSlot.root
            reveal: edgeBorder.curvedInsetReveal
            visible: edgeBorder.curvedInsetRendering
            x: edgeBorder.curvedInsetPixel - width / 2
            y: barSlot.root.barPosition === "bottom"
                ? 0
                : foregroundEdgeBorder.height - height
        }
    }
}
