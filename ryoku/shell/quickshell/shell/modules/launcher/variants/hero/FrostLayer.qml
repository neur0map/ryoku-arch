import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

ClippingRectangle {
    id: root

    property Item sourceItem: null
    property rect sourceRect: Qt.rect(0, 0, 0, 0)
    property bool active: false
    property real bleedLeft: 0
    property real bleedTop: 0
    property real bleedRight: 0
    property real bleedBottom: 0
    property real textureHeight: 0
    property int blurRadius: 0

    visible: active && sourceItem !== null && width > 0 && height > 0
    color: "transparent"
    contentUnderBorder: true

    ShaderEffectSource {
        id: visibleCrop
        width: Math.min(
            root.sourceRect.width,
            root.width + root.bleedLeft + root.bleedRight)
        height: Math.min(
            root.sourceRect.height,
            root.textureHeight)
        sourceItem: root.sourceItem
        sourceRect: Qt.rect(
            root.sourceRect.x, root.sourceRect.y, width, height)
        live: root.visible
        hideSource: true
        recursive: false
        smooth: true
        visible: false
    }

    MultiEffect {
        x: -root.bleedLeft
        y: -root.bleedTop
        width: visibleCrop.width
        height: visibleCrop.height
        source: visibleCrop
        autoPaddingEnabled: false
        blurEnabled: root.blurRadius > 0
        blur: 1
        blurMax: Math.max(1, Math.min(64, root.blurRadius))
    }
}
