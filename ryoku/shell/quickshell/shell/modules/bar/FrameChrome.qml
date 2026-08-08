import QtQuick
import QtQuick.Shapes
import "framebars/FrameChromeGeometry.js" as FrameGeometry

// The frame's painted chrome: two static odd-even scene-graph paths form the
// surface band and its inside outline around one rounded desktop hole. Animated
// menu panels are ordinary scene-graph rectangles; keeping them out of this path
// avoids rebuilding curved geometry on every reveal frame.
//
// The outline path reaches the hole edge. The surface path uses a hole expanded
// into the band by strokeWidth, leaving exactly that much outline visible on the
// band side without drawing into the transparent desktop hole.
Shape {
    id: chrome

    property real reserveLeft: 0
    property real reserveTop: 0
    property real reserveRight: 0
    property real reserveBottom: 0
    property real holeRadius: 8
    property color surface: "#101315"
    property color outline: "#565d60"
    property real strokeWidth: 2

    readonly property var holePoints: [
        { x: chrome.reserveLeft, y: chrome.reserveTop },
        { x: chrome.width - chrome.reserveRight, y: chrome.reserveTop },
        { x: chrome.width - chrome.reserveRight, y: chrome.height - chrome.reserveBottom },
        { x: chrome.reserveLeft, y: chrome.height - chrome.reserveBottom }
    ]
    readonly property var surfaceHolePoints: FrameGeometry.offsetPoints(
        chrome.holePoints, chrome.strokeWidth)
    readonly property var surfaceHoleRadii: FrameGeometry.offsetRadii(
        chrome.holePoints, chrome.holeRadius, chrome.strokeWidth)
    readonly property string outlinePath: FrameGeometry.framePath(
        chrome.width, chrome.height, chrome.holePoints, chrome.holeRadius)
    readonly property string surfacePath: FrameGeometry.framePath(
        chrome.width, chrome.height, chrome.surfaceHolePoints,
        chrome.surfaceHoleRadii)

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: chrome.outline
        strokeColor: "transparent"
        fillRule: ShapePath.OddEvenFill
        PathSvg { path: chrome.outlinePath }
    }

    ShapePath {
        fillColor: chrome.surface
        strokeColor: "transparent"
        fillRule: ShapePath.OddEvenFill
        PathSvg { path: chrome.surfacePath }
    }
}
