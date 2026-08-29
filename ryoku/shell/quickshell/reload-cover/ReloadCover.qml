pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: cover

    required property var targetScreen
    required property string phase
    required property bool startClose
    signal mapped()

    screen: targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.namespace: "ryoku-reload-cover"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {}

    property real diagonal: Math.sqrt(width * width + height * height)
    property real iris: diagonal
    property bool mappedReported: false

    function reportMapped(): void {
        if (!mappedReported && backingWindowVisible && width > 0 && height > 0) {
            mappedReported = true;
            mapped();
        }
    }

    function closeIris(): void {
        iris = diagonal;
        closeAnim.restart();
    }
    function openIris(): void {
        iris = 0;
        openAnim.restart();
    }

    Component.onCompleted: reportMapped()
    onBackingWindowVisibleChanged: reportMapped()
    onWidthChanged: reportMapped()
    onHeightChanged: reportMapped()
    onStartCloseChanged: if (startClose) closeIris()
    onPhaseChanged: if (phase === "opening") openIris()

    NumberAnimation {
        id: closeAnim
        target: cover
        property: "iris"
        from: cover.diagonal
        to: 0
        duration: 320
        easing.type: Easing.InOutCubic
    }
    NumberAnimation {
        id: openAnim
        target: cover
        property: "iris"
        from: 0
        to: cover.diagonal
        duration: 380
        easing.type: Easing.InOutCubic
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        visible: cover.phase === "hold" || cover.phase === "failed"
    }
    Item {
        anchors.fill: parent
        visible: cover.phase === "closing" || cover.phase === "opening"
        layer.enabled: visible
        layer.effect: OpacityMask { invert: true; maskSource: irisMask }
        Rectangle { anchors.fill: parent; color: "black" }
    }
    Item {
        id: irisMask
        anchors.fill: parent
        visible: false
        layer.enabled: cover.phase === "closing" || cover.phase === "opening"
        Rectangle {
            anchors.centerIn: parent
            width: cover.iris * 2
            height: cover.iris * 2
            radius: cover.iris
            color: "white"
        }
    }

    Image {
        id: logo
        anchors.centerIn: parent
        source: "assets/logo.png"
        sourceSize.width: Math.round(Math.min(parent.width * 0.58, 928))
        fillMode: Image.PreserveAspectFit
        width: sourceSize.width
        height: width * 160 / 928
        opacity: {
            if (cover.phase === "closing") return Math.max(0, 1 - cover.iris / (cover.diagonal * 0.38));
            if (cover.phase === "hold" || cover.phase === "failed") return 1;
            if (cover.phase === "opening") return Math.max(0, 1 - cover.iris / (cover.diagonal * 0.38));
            return 0;
        }
        scale: opacity < 1 ? 0.94 + opacity * 0.06 : 1
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: 28
        visible: cover.phase === "failed"
        text: "RELOAD FAILED"
        color: "#ff735d"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 14
        font.letterSpacing: 3
    }
}
