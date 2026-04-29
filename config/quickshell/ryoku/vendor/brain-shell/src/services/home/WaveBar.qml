import QtQuick
import QtQuick.Shapes
import "../../"

// Animated wavy line used by TelemetryRail. The visible length encodes
// the value (0..1), the wavelength is fixed in pixels, so longer fills
// naturally show more cycles. A continuously-rotating phase gives the
// "passive" motion: even at static values the line breathes.
//
// GPU-rendered via QtQuick.Shapes (CurveRenderer). Sampling is cheap —
// O(width / step) JS Math.sin calls per phase tick — and re-tessellates
// on the render thread, not the main thread.
Item {
    id: root

    property real  value:        0          // 0..1
    property color color:        Theme.active
    property real  wavelength:   14         // px per cycle
    property real  amplitude:    2          // px peak deviation
    property int   strokeWidth:  2
    property int   sampleStep:   2          // px between samples (smaller = smoother)
    property real  speed:        4000       // ms per full phase rotation
    property int   valueDuration: 700       // ms to tween between value changes

    // Smooth out per-tick jumps (network ratios are especially noisy
    // because both the bytes-per-sec and the peak-decay denominator
    // change every sample). Drives an internal _smoothValue that the
    // path actually reads, so the wave grows/shrinks instead of snapping.
    property real _smoothValue: 0
    onValueChanged: _smoothValue = value
    Component.onCompleted: _smoothValue = value
    Behavior on _smoothValue {
        enabled: !Theme.staticMode
        NumberAnimation {
            duration:    root.valueDuration
            easing.type: Easing.OutCubic
        }
    }

    height: amplitude * 2 + strokeWidth + 2

    property real _phase: 0
    NumberAnimation on _phase {
        running: root.visible && !Theme.staticMode
        loops:   Animation.Infinite
        from:    0
        to:      2 * Math.PI
        duration: root.speed
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.strokeWidth
            fillColor:   "transparent"
            joinStyle:   ShapePath.RoundJoin
            capStyle:    ShapePath.RoundCap

            PathPolyline {
                path: root._buildPoints(root.width, root.height, root._smoothValue,
                                        root.wavelength, root.amplitude,
                                        root.sampleStep, root._phase)
            }
        }
    }

    function _buildPoints(w, h, v, lambda, amp, step, phi) {
        var clamped = Math.max(0, Math.min(1, v))
        var endX    = Math.max(2, w * clamped)
        var midY    = h / 2
        var pts     = []
        var twoPi   = Math.PI * 2

        for (var x = 0; x <= endX; x += step) {
            var theta = twoPi * x / lambda + phi
            pts.push(Qt.point(x, midY + amp * Math.sin(theta)))
        }
        // ensure the last sample lands exactly at endX
        if (pts.length === 0 || pts[pts.length - 1].x !== endX) {
            var t = twoPi * endX / lambda + phi
            pts.push(Qt.point(endX, midY + amp * Math.sin(t)))
        }
        return pts
    }
}
