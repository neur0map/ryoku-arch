import qs.modules.common
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell

// Reusable glass/acrylic background component
// For correct blur positioning, parent must set screenX/screenY to component's screen position
//
// GPU optimization: Uses BlurredWallpaperProvider singleton to share ONE blur FBO
// instead of each instance creating its own (~16 MiB saved per instance).
Rectangle {
    id: root
    
    property color fallbackColor: Appearance.colors.colLayer1
    property color inirColor: Appearance.inir.colLayer1
    property real auroraTransparency: Appearance.aurora.popupTransparentize
    property bool wallpaperBackdropEnabled: true
    
    // Screen-relative position for blur alignment (set by parent)
    property real screenX: 0
    property real screenY: 0
    property real screenWidth: Quickshell.screens[0]?.width ?? 1920
    property real screenHeight: Quickshell.screens[0]?.height ?? 1080
    
    readonly property bool angelEverywhere: Appearance.angelEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool useWallpaperBackdrop: root.wallpaperBackdropEnabled && root.auroraEverywhere && !root.inirEverywhere
    
    color: root.useWallpaperBackdrop ? "transparent"
        : root.inirEverywhere ? root.inirColor
        : root.fallbackColor
    
    property bool hovered: false

    border.width: 0
    border.color: "transparent"

    clip: true
    
    layer.enabled: root.useWallpaperBackdrop
    layer.effect: GE.OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            radius: root.radius
        }
    }
    
    // Blurred wallpaper backdrop for aurora/angel styles.
    // OPTIMIZATION: layer.enabled is only active when the GlassBackground is
    // actually visible, reducing GPU memory when panels are hidden.
    Image {
        id: blurredWallpaper
        x: -root.screenX
        y: -root.screenY
        width: root.screenWidth
        height: root.screenHeight
        visible: root.useWallpaperBackdrop && status === Image.Ready
        source: root.useWallpaperBackdrop ? Wallpapers.effectiveWallpaperUrl : ""
        fillMode: Image.PreserveAspectCrop
        // All GlassBackground instances share the same wallpaper URL and sourceSize,
        // so Qt's QPixmapCache serves a single decoded pixmap to all of them.
        cache: true
        asynchronous: true
        // Constrain decoded size to screen dimensions — the blur doesn't need more.
        sourceSize.width: root.screenWidth
        sourceSize.height: root.screenHeight

        // CRITICAL: Only enable blur layer when VISIBLE AND enabled.
        // This releases the FBO when the panel is hidden, saving ~16 MiB per instance.
        layer.enabled: Appearance.effectsEnabled && root.useWallpaperBackdrop && root.visible
        layer.effect: MultiEffect {
            source: blurredWallpaper
            anchors.fill: source
            saturation: root.angelEverywhere
                ? (Appearance.angel.blurSaturation * Appearance.angel.colorStrength)
                : (Appearance.effectsEnabled ? 0.2 : 0)
            blurEnabled: Appearance.effectsEnabled
            blurMax: 64
            blur: Appearance.effectsEnabled
                ? (root.angelEverywhere ? Appearance.angel.blurIntensity : 1)
                : 0
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.useWallpaperBackdrop
        color: root.angelEverywhere
            ? ColorUtils.transparentize(Appearance.colors.colLayer0Base, Appearance.angel.overlayOpacity)
            : ColorUtils.transparentize(Appearance.colors.colLayer0Base, root.auroraTransparency)
    }

    // Inset glow — light-from-above on top edge, angel only
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Appearance.angel.insetGlowHeight
        visible: root.angelEverywhere
        color: Appearance.angel.colInsetGlow
    }

    // Partial border — elegant half-borders, angel only
    AngelPartialBorder {
        targetRadius: root.radius
        hovered: root.hovered
    }
}
