pragma ComponentBehavior: Bound

import QtQuick
import "lib/hero.js" as HeroMath

Item {
    id: root

    property url source
    property url fallbackSource
    property real focalX: 0.5
    property real focalY: 0.5
    property real strength: 1.0

    readonly property var activeImage: root.activeSlot === 0
        ? candidateA : (root.activeSlot === 1 ? candidateB : (root.activeSlot === -1 ? fallback : null))
    readonly property real paintedWidth: root.ready ? root.activeImage.width : 0
    readonly property real paintedHeight: root.ready ? root.activeImage.height : 0
    readonly property real overflowX: Math.max(0, root.paintedWidth - root.width)
    readonly property real overflowY: Math.max(0, root.paintedHeight - root.height)
    readonly property bool usingFallback: root.activeSlot === -1
    readonly property bool ready: root.activeImage !== null && root.activeImage.status === Image.Ready

    readonly property bool wantsFallback: String(root.source).length === 0
    readonly property string targetKey: String(HeroMath.selectSource(root.source, root.fallbackSource))
    property int activeSlot: -1
    property string failedKey: ""
    property bool complete: false

    clip: true

    function dragFocal(start, translation, overflow) {
        return HeroMath.dragFocal(start, translation, overflow);
    }

    function imageFor(slot) {
        return slot === 0 ? candidateA : candidateB;
    }

    function activateFallbackWhenReady() {
        if (fallback.status !== Image.Ready)
            return;
        if (root.wantsFallback || root.failedKey === root.targetKey)
            root.activeSlot = -1;
    }

    function candidateStatusChanged(slot) {
        var image = root.imageFor(slot);
        if (String(image.source) !== root.targetKey)
            return;
        if (image.status === Image.Ready) {
            root.failedKey = "";
            root.activeSlot = slot;
        } else if (image.status === Image.Error) {
            root.failedKey = root.targetKey;
            root.activateFallbackWhenReady();
        }
    }

    function requestTarget() {
        root.failedKey = "";
        if (root.wantsFallback) {
            if (fallback.status === Image.Ready)
                root.activeSlot = -1;
            else if (root.targetKey.length === 0)
                root.activeSlot = -2;
            return;
        }

        if (root.activeSlot >= 0) {
            var active = root.imageFor(root.activeSlot);
            if (String(active.source) === root.targetKey && active.status === Image.Ready)
                return;
        }

        var slot = root.activeSlot === 0 ? 1 : 0;
        var candidate = root.imageFor(slot);
        if (String(candidate.source) === root.targetKey) {
            root.candidateStatusChanged(slot);
            return;
        }
        candidate.source = root.targetKey;
    }

    onTargetKeyChanged: if (root.complete) root.requestTarget()
    Component.onCompleted: {
        root.complete = true;
        root.requestTarget();
    }

    Image {
        id: fallback
        readonly property var crop: HeroMath.cover(
            root.width, root.height, implicitWidth, implicitHeight,
            root.focalX, root.focalY)

        visible: root.activeSlot === -1 && status === Image.Ready
        source: root.fallbackSource
        asynchronous: false
        cache: true
        smooth: true
        opacity: Math.max(0, Math.min(1, root.strength))
        width: crop.width
        height: crop.height
        x: crop.x
        y: crop.y
        onStatusChanged: root.activateFallbackWhenReady()
    }

    Image {
        id: candidateA
        readonly property var crop: HeroMath.cover(
            root.width, root.height, implicitWidth, implicitHeight,
            root.focalX, root.focalY)

        visible: root.activeSlot === 0 && status === Image.Ready
        asynchronous: true
        cache: true
        smooth: true
        opacity: Math.max(0, Math.min(1, root.strength))
        width: crop.width
        height: crop.height
        x: crop.x
        y: crop.y
        onStatusChanged: root.candidateStatusChanged(0)
    }

    Image {
        id: candidateB
        readonly property var crop: HeroMath.cover(
            root.width, root.height, implicitWidth, implicitHeight,
            root.focalX, root.focalY)

        visible: root.activeSlot === 1 && status === Image.Ready
        asynchronous: true
        cache: true
        smooth: true
        opacity: Math.max(0, Math.min(1, root.strength))
        width: crop.width
        height: crop.height
        x: crop.x
        y: crop.y
        onStatusChanged: root.candidateStatusChanged(1)
    }
}
