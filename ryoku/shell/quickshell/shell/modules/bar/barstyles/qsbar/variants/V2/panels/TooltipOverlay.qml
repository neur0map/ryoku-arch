import QtQuick
import Quickshell
import Quickshell.Wayland
import "../modules"

PanelWindow {
    id: overlay
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // "quickshell" (not "ryoku-tooltip") so the theme's match:namespace quickshell
    // blur rule frosts the tooltip too — same ride-the-theme mechanism as the bar.
    WlrLayershell.namespace: "quickshell"
    mask: Region {}

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property real reveal: root.tooltipShown ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.tooltipShown ? 160 : 120
            easing.type: root.tooltipShown ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001

    Rectangle {
        id: tip
        readonly property int padH: 10
        readonly property int padV: 4

        width: tipLabel.implicitWidth + padH * 2
        height: tipLabel.implicitHeight + padV * 2

        x: {
            var cx = root.tooltipX;
            return Math.max(4, Math.min(parent.width - width - 4, cx - width / 2));
        }
        // Follow the actual owner, including freely rearranged widgets and panel
        // row actions. Prefer the inward side of the bar, then flip when the
        // preferred side would leave the screen.
        y: {
            var above = root.tooltipTopY - gap - height
            var below = root.tooltipBottomY + gap
            var maxY = parent.height - height - 4
            var candidate = root.barPosition === "bottom" ? above : below

            if (candidate < 4 && below <= maxY)
                candidate = below
            else if (candidate > maxY && above >= 4)
                candidate = above

            return Math.max(4, Math.min(maxY, candidate))
        }

        color: root.barBg
        border.color: root.panelOuterBorderColor
        border.width: root.panelOuterBorderW
        radius: root.panelRadius
        opacity: overlay.reveal

        PillShadow { theme: root }

        UiText {
            id: tipLabel
            anchors.centerIn: parent
            text: root.tooltipText
            color: root.ink
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 1
        }
    }
}
