import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services

Rectangle {
    id: root

    property real screenX: 0
    property real screenY: 0
    property real screenWidth: 1920
    property real screenHeight: 1080

    property real surfaceOpacity: 0.06
    property real surfaceBorderWidth: 1
    property real surfaceBorderOpacity: 0.08
    property color surfaceColor: Appearance.colors.colOnLayer0
    property real surfaceRadius: Appearance.rounding.small
    property bool surfaceUseBlur: false

    readonly property bool _angel: Appearance.angelEverywhere
    readonly property bool _aurora: Appearance.auroraEverywhere && !Appearance.ryokuEverywhere
    readonly property bool _ryoku: Appearance.ryokuEverywhere
    readonly property bool _glass: (_aurora || _angel) && Appearance.effectsEnabled && root.surfaceUseBlur
    readonly property string _wallpaperUrl: Wallpapers.effectiveWallpaperUrl

    radius: surfaceRadius
    color: _glass ? "transparent"
        : _ryoku ? "transparent"
        : surfaceOpacity > 0 ? ColorUtils.applyAlpha(surfaceColor, surfaceOpacity) : "transparent"
    border.width: 0
    border.color: "transparent"
    clip: true

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        visible: !root._glass && root.surfaceBorderWidth > 0 && root.surfaceBorderOpacity > 0
        border.width: root.surfaceBorderWidth
        border.color: root._ryoku
            ? ColorUtils.applyAlpha(Appearance.ryoku.colBorder, root.surfaceBorderOpacity * 3)
            : ColorUtils.applyAlpha(root.surfaceColor, root.surfaceBorderOpacity)
    }

    layer.enabled: _glass
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }

    Image {
        id: blurredWallpaper
        x: -root.screenX
        y: -root.screenY
        width: root.screenWidth
        height: root.screenHeight
        visible: root._glass && status === Image.Ready
        source: root._glass ? root._wallpaperUrl : ""
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        sourceSize.width: root.screenWidth
        sourceSize.height: root.screenHeight

        layer.enabled: root._glass
        layer.effect: MultiEffect {
            source: blurredWallpaper
            anchors.fill: source
            saturation: root._angel
                ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                : 0.15
            blurEnabled: true
            blurMax: 64
            blur: root._angel ? Appearance.angel.blurIntensity : 0.8
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root._glass
        color: root._angel
            ? ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
            : ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.aurora.popupTransparentize * 1.2)
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Appearance.angel.insetGlowHeight
        visible: root._angel
        color: Appearance.angel.colInsetGlow
    }

    AngelPartialBorder {
        visible: root._angel
        targetRadius: root.radius
    }

    Rectangle {
        anchors.fill: parent
        visible: root._ryoku && root.surfaceOpacity > 0
        radius: root.radius
        color: ColorUtils.applyAlpha(Appearance.ryoku.colLayer1, root.surfaceOpacity * 2)
    }
}
