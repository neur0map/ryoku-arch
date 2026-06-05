import QtQuick
import QtQuick.Effects
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Services.Compositor
import qs.noctalia.Services.Power
import qs.noctalia.Services.UI

Item {
  id: root
  anchors.fill: parent

  // Cached wallpaper path - exposed for parent components
  property string resolvedWallpaperPath: ""
  property color tintColor: Settings.data.colorSchemes.darkMode ? Color.mSurface : Color.mOnSurface

  required property var screen

  // Request preprocessed wallpaper when lock screen becomes active or dimensions change
  Component.onCompleted: {
    if (screen) {
      Qt.callLater(requestCachedWallpaper);
    }
  }

  onWidthChanged: {
    if (screen && width > 0 && height > 0) {
      Qt.callLater(requestCachedWallpaper);
    }
  }

  onHeightChanged: {
    if (screen && width > 0 && height > 0) {
      Qt.callLater(requestCachedWallpaper);
    }
  }

  Connections {
    target: WallpaperService
    function onWallpaperChanged(screenName, path) {
      if (screen && screenName === screen.name) {
        Qt.callLater(requestCachedWallpaper);
      }
    }
  }

  Connections {
    target: CompositorService
    function onDisplayScalesChanged() {
      if (screen && width > 0 && height > 0) {
        Qt.callLater(requestCachedWallpaper);
      }
    }
  }

  function requestCachedWallpaper() {
    if (!screen || width <= 0 || height <= 0) {
      return;
    }

    if (Settings.data.wallpaper.useSolidColor) {
      resolvedWallpaperPath = "";
      return;
    }

    const originalPath = WallpaperService.getWallpaper(screen.name) || "";
    if (originalPath === "") {
      resolvedWallpaperPath = "";
      return;
    }

    if (WallpaperService.isSolidColorPath(originalPath)) {
      resolvedWallpaperPath = "";
      return;
    }

    if (!ImageCacheService || !ImageCacheService.initialized) {
      // Fallback to original if services not ready
      resolvedWallpaperPath = originalPath;
      return;
    }

    const compositorScale = CompositorService.getDisplayScale(screen.name);
    const targetWidth = Math.round(width * compositorScale);
    const targetHeight = Math.round(height * compositorScale);
    if (targetWidth <= 0 || targetHeight <= 0) {
      return;
    }

    // Don't set resolvedWallpaperPath until cache is ready
    // This prevents loading the original huge image
    ImageCacheService.getLarge(originalPath, targetWidth, targetHeight, function (cachedPath, success) {
      if (success) {
        resolvedWallpaperPath = cachedPath;
      } else {
        // Only fall back to original if caching failed
        resolvedWallpaperPath = originalPath;
      }
    });
  }

  // Background - solid color or black fallback
  Rectangle {
    anchors.fill: parent
    color: Settings.data.wallpaper.useSolidColor ? Settings.data.wallpaper.solidColor : "#000000"
  }

  Image {
    id: lockBgImage
    visible: source !== "" && Settings.data.wallpaper.enabled && !Settings.data.wallpaper.useSolidColor && (!PowerProfileService.noctaliaPerformanceMode || !Settings.data.noctaliaPerformance.disableWallpaper)
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
    source: resolvedWallpaperPath
    cache: false
    smooth: true
    mipmap: false
    antialiasing: true

    layer.enabled: Settings.data.general.lockScreenBlur > 0 && !PowerProfileService.noctaliaPerformanceMode
    layer.smooth: false
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: Settings.data.general.lockScreenBlur
      blurMax: 48
    }

    Rectangle {
      anchors.fill: parent
      color: root.tintColor
      opacity: Settings.data.general.lockScreenTint
    }
  }

  Rectangle {
    visible: !Settings.data.wallpaper.useSolidColor
    anchors.fill: parent
    gradient: Gradient {
      GradientStop {
        position: 0.0
        color: Qt.alpha(Color.mShadow, 0.4)
      }
      GradientStop {
        position: 0.3
        color: Qt.alpha(Color.mShadow, 0.2)
      }
      GradientStop {
        position: 0.7
        color: Qt.alpha(Color.mShadow, 0.25)
      }
      GradientStop {
        position: 1.0
        color: Qt.alpha(Color.mShadow, 0.5)
      }
    }
  }

  // Screen corners for lock screen
  Item {
    anchors.fill: parent
    visible: Settings.data.general.showScreenCorners

    property color cornerColor: Settings.data.general.forceBlackScreenCorners ? "black" : Color.mSurface
    property real cornerRadius: Style.screenRadius
    property real cornerSize: Style.screenRadius

    Canvas {
      anchors.top: parent.top
      anchors.left: parent.left
      width: parent.cornerSize
      height: parent.cornerSize
      antialiasing: true
      renderTarget: Canvas.FramebufferObject
      smooth: false

      onPaint: {
        const ctx = getContext("2d");
        if (!ctx)
          return;
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        ctx.fillStyle = parent.cornerColor;
        ctx.fillRect(0, 0, width, height);

        ctx.globalCompositeOperation = "destination-out";
        ctx.fillStyle = "#ffffff";
        ctx.beginPath();
        ctx.arc(width, height, parent.cornerRadius, 0, 2 * Math.PI);
        ctx.fill();
      }

      onWidthChanged: if (available)
                        requestPaint()
      onHeightChanged: if (available)
                         requestPaint()
    }

    Canvas {
      anchors.top: parent.top
      anchors.right: parent.right
      width: parent.cornerSize
      height: parent.cornerSize
      antialiasing: true
      renderTarget: Canvas.FramebufferObject
      smooth: true

      onPaint: {
        const ctx = getContext("2d");
        if (!ctx)
          return;
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        ctx.fillStyle = parent.cornerColor;
        ctx.fillRect(0, 0, width, height);

        ctx.globalCompositeOperation = "destination-out";
        ctx.fillStyle = "#ffffff";
        ctx.beginPath();
        ctx.arc(0, height, parent.cornerRadius, 0, 2 * Math.PI);
        ctx.fill();
      }

      onWidthChanged: if (available)
                        requestPaint()
      onHeightChanged: if (available)
                         requestPaint()
    }

    Canvas {
      anchors.bottom: parent.bottom
      anchors.left: parent.left
      width: parent.cornerSize
      height: parent.cornerSize
      antialiasing: true
      renderTarget: Canvas.FramebufferObject
      smooth: true

      onPaint: {
        const ctx = getContext("2d");
        if (!ctx)
          return;
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        ctx.fillStyle = parent.cornerColor;
        ctx.fillRect(0, 0, width, height);

        ctx.globalCompositeOperation = "destination-out";
        ctx.fillStyle = "#ffffff";
        ctx.beginPath();
        ctx.arc(width, 0, parent.cornerRadius, 0, 2 * Math.PI);
        ctx.fill();
      }

      onWidthChanged: if (available)
                        requestPaint()
      onHeightChanged: if (available)
                         requestPaint()
    }

    Canvas {
      anchors.bottom: parent.bottom
      anchors.right: parent.right
      width: parent.cornerSize
      height: parent.cornerSize
      antialiasing: true
      renderTarget: Canvas.FramebufferObject
      smooth: true

      onPaint: {
        const ctx = getContext("2d");
        if (!ctx)
          return;
        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        ctx.fillStyle = parent.cornerColor;
        ctx.fillRect(0, 0, width, height);

        ctx.globalCompositeOperation = "destination-out";
        ctx.fillStyle = "#ffffff";
        ctx.beginPath();
        ctx.arc(0, 0, parent.cornerRadius, 0, 2 * Math.PI);
        ctx.fill();
      }

      onWidthChanged: if (available)
                        requestPaint()
      onHeightChanged: if (available)
                         requestPaint()
    }
  }
}
