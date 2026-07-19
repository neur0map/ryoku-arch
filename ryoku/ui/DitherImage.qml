import QtQuick
import QtQuick.Effects

// Live 1-bit ordered dither, the runtime twin of bin/art/ryodither: a source
// image reduced to Ryoku bone on a transparent ground through a Bayer 4x4
// stipple, so a user's own photo reads like the baked decor set the moment it is
// dropped in (the Profile hero). Backed by shaders/dither.frag.qsb (compiled with
// qsb; recompile when dither.frag changes, the same way the blob shader is built).
// Where the shader cannot run (no RHI/shader path), it falls back to a plain
// desaturated image so the hero still degrades to monochrome instead of vanishing.
Item {
    id: root

    property url source
    property color bone: "#e8d8c9"     // the decor bone, matching ryodither + the set
    property real dotScale: 1.0        // dither cell scale; 1 = fine, larger = coarser
    property bool invert: false        // ink dark tones instead of light
    property int fillMode: Image.PreserveAspectCrop
    readonly property int status: srcImg.status
    readonly property bool shaderFailed: fx.status === ShaderEffect.Error

    Image {
        id: srcImg
        anchors.fill: parent
        source: root.source
        fillMode: root.fillMode
        asynchronous: true
        visible: false            // a plain hidden Image is still a texture provider
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: srcImg.status === Image.Ready && !root.shaderFailed
        property variant src: srcImg
        property color bone: root.bone
        property vector2d srcSize: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        property real dotScale: root.dotScale
        property real invert: root.invert ? 1.0 : 0.0
        fragmentShader: Qt.resolvedUrl("shaders/dither.frag.qsb")
    }

    // Fallback for a software-render / no-shader path: desaturated, high-contrast.
    MultiEffect {
        anchors.fill: parent
        source: srcImg
        visible: srcImg.status === Image.Ready && root.shaderFailed
        saturation: -1.0
        contrast: 0.4
        brightness: 0.1
    }
}
