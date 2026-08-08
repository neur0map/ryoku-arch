import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "Singletons"

// Frosted plate for a desktop widget that draws its own card: the exact patch of
// wallpaper behind the widget, blurred and dimmed inside the rounded shape, with
// a palette wash over it. The wallpaper lives in its own Wayland surface, which
// Qt cannot sample, so the host mirrors it into the scene and hands that Item in
// as `sourceItem` with the widget's rect (see Desktop.qml).
ClippingRectangle {
    id: root

    property bool hovered: false
    property real s: 1
    property Item sourceItem: null
    property rect sourceRect: Qt.rect(0, 0, 0, 0)

    readonly property real bleed: 36 * root.s
    readonly property real cropX: Math.max(0, root.sourceRect.x - root.bleed)
    readonly property real cropY: Math.max(0, root.sourceRect.y - root.bleed)
    readonly property real cropRight: root.sourceItem
        ? Math.min(root.sourceItem.width, root.sourceRect.x + root.width + root.bleed) : 0
    readonly property real cropBottom: root.sourceItem
        ? Math.min(root.sourceItem.height, root.sourceRect.y + root.height + root.bleed) : 0

    radius: Theme.radiusWidget * root.s
    color: "transparent"
    contentUnderBorder: true
    border.width: 1
    border.color: root.hovered ? Theme.lineStrong : Theme.line

    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

    ShaderEffectSource {
        id: backdropCrop
        x: root.cropX - root.sourceRect.x
        y: root.cropY - root.sourceRect.y
        width: Math.max(1, root.cropRight - root.cropX)
        height: Math.max(1, root.cropBottom - root.cropY)
        sourceItem: root.sourceItem
        sourceRect: Qt.rect(root.cropX, root.cropY, width, height)
        live: root.visible
        hideSource: true
        recursive: false
        smooth: true
        visible: false
    }

    MultiEffect {
        x: backdropCrop.x
        y: backdropCrop.y
        width: backdropCrop.width
        height: backdropCrop.height
        source: backdropCrop
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1
        blurMax: 64
        blurMultiplier: 1.7
        saturation: -0.24
        contrast: 0.08
        brightness: -0.10
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b,
            root.hovered ? 0.46 : 0.38)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b,
                    root.hovered ? 0.08 : 0.05)
            }
            GradientStop {
                position: 0.42
                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.18)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(Theme.cardBot.r, Theme.cardBot.g, Theme.cardBot.b, 0.32)
            }
        }
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }
}
