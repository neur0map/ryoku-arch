pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland

Item {
    id: root

    required property var captureScreen
    required property int generation
    required property real screenWidth
    required property real screenHeight
    required property real cropX
    required property real cropY
    required property real cropWidth
    required property real cropHeight
    required property int blurRadius
    property bool captureEnabled: false

    readonly property bool frozenReady: frameArrived
    readonly property alias textureItem: capture
    readonly property real kernelBleed: Math.max(
        2, Math.min(32, blurRadius * 2))
    readonly property real bleedLeft: Math.min(kernelBleed, cropX)
    readonly property real bleedTop: Math.min(kernelBleed, cropY)
    readonly property real bleedRight: Math.min(
        kernelBleed, Math.max(0, screenWidth - cropX - cropWidth))
    readonly property real bleedBottom: Math.min(
        kernelBleed, Math.max(0, screenHeight - cropY - cropHeight))
    readonly property real sampledWidth: cropWidth + bleedLeft + bleedRight
    readonly property real sampledHeight: cropHeight + bleedTop + bleedBottom
    readonly property rect sampleRect: Qt.rect(
        cropX - bleedLeft,
        cropY - bleedTop,
        sampledWidth,
        sampledHeight)
    property bool captureStarted: false
    property bool frameArrived: false
    property bool failureReported: false

    signal ready(int generation)
    signal failed(int generation)

    width: cropWidth
    height: cropHeight
    visible: false

    function reportFailure(expectedGeneration) {
        if (Number(expectedGeneration) !== generation
                || failureReported || frameArrived || !captureStarted)
            return;
        failureReported = true;
        failed(generation);
    }

    function freezeArrivedFrame() {
        if (!captureStarted || !capture.hasContent || frameArrived)
            return;
        frameArrived = true;
        ready(generation);
    }

    function startCapture() {
        if (captureEnabled)
            captureStarted = true;
    }

    ScreencopyView {
        id: capture
        width: root.screenWidth
        height: root.screenHeight
        visible: false
        captureSource: root.captureStarted ? root.captureScreen : null
        paintCursor: false
        live: false

        onHasContentChanged: if (hasContent) root.freezeArrivedFrame()
        onStopped: {
            if (!hasContent) {
                var stoppedGeneration = root.generation;
                Qt.callLater(function () {
                    root.reportFailure(stoppedGeneration);
                });
            }
        }
    }

    onCaptureEnabledChanged: startCapture()
    Component.onCompleted: {
        startCapture();
        if (capture.hasContent)
            freezeArrivedFrame();
    }
}
