pragma Singleton

import QtQuick
import Quickshell
import Ryoku.Config
import qs.settingsgui.Services.Power

Singleton {
  id: root

  // Font size — RYOKU: scaled by GlobalConfig.appearance.font.size.scale so the
  // settings panel responds to the Font size slider (it is part of the shell too).
  readonly property real _fontScale: GlobalConfig.appearance.font.size.scale
  readonly property real fontSizeXXS: 8 * _fontScale
  readonly property real fontSizeXS: 9 * _fontScale
  readonly property real fontSizeS: 10 * _fontScale
  readonly property real fontSizeM: 11 * _fontScale
  readonly property real fontSizeL: 13 * _fontScale
  readonly property real fontSizeXL: 16 * _fontScale
  readonly property real fontSizeXXL: 18 * _fontScale
  readonly property real fontSizeXXXL: 24 * _fontScale

  readonly property int fontWeightRegular: 400
  readonly property int fontWeightMedium: 500
  readonly property int fontWeightSemiBold: 600
  readonly property int fontWeightBold: 700

  // Container Radii: major layout sections (sidebars, cards, content panels)
  readonly property int radiusXXXS: Math.round(3 * GlobalConfig.appearance.rounding.scale)
  readonly property int radiusXXS: Math.round(4 * GlobalConfig.appearance.rounding.scale)
  readonly property int radiusXS: Math.round(8 * GlobalConfig.appearance.rounding.scale)
  readonly property int radiusS: Math.round(12 * GlobalConfig.appearance.rounding.scale)
  readonly property int radiusM: Math.round(16 * GlobalConfig.appearance.rounding.scale)
  readonly property int radiusL: Math.round(20 * GlobalConfig.appearance.rounding.scale)

  // Input radii: interactive elements (buttons, toggles, text fields)
  readonly property int iRadiusXXXS: Math.round(3 * GlobalConfig.appearance.rounding.scale)
  readonly property int iRadiusXXS: Math.round(4 * GlobalConfig.appearance.rounding.scale)
  readonly property int iRadiusXS: Math.round(8 * GlobalConfig.appearance.rounding.scale)
  readonly property int iRadiusS: Math.round(12 * GlobalConfig.appearance.rounding.scale)
  readonly property int iRadiusM: Math.round(16 * GlobalConfig.appearance.rounding.scale)
  readonly property int iRadiusL: Math.round(20 * GlobalConfig.appearance.rounding.scale)

  readonly property int screenRadius: Math.round(20 * GlobalConfig.general.screenRadiusRatio)

  readonly property int borderS: Math.max(1, Math.round(1 * uiScaleRatio))
  readonly property int borderM: Math.max(1, Math.round(2 * uiScaleRatio))
  readonly property int borderL: Math.max(1, Math.round(3 * uiScaleRatio))

  readonly property int marginXXXS: Math.round(1 * uiScaleRatio)
  readonly property int marginXXS: Math.round(2 * uiScaleRatio)
  readonly property int marginXS: Math.round(4 * uiScaleRatio)
  readonly property int marginS: Math.round(6 * uiScaleRatio)
  readonly property int marginM: Math.round(9 * uiScaleRatio)
  readonly property int marginL: Math.round(13 * uiScaleRatio)
  readonly property int marginXL: Math.round(18 * uiScaleRatio)

  // Double margins, for proper container sizing only (e.g. height: id.implicitHeight + Style.margin2M)
  readonly property int margin2XXXS: marginXXXS * 2
  readonly property int margin2XXS: marginXXS * 2
  readonly property int margin2XS: marginXS * 2
  readonly property int margin2S: marginS * 2
  readonly property int margin2M: marginM * 2
  readonly property int margin2L: marginL * 2
  readonly property int margin2XL: marginXL * 2

  readonly property real opacityNone: 0.0
  readonly property real opacityLight: 0.25
  readonly property real opacityMedium: 0.5
  readonly property real opacityHeavy: 0.75
  readonly property real opacityAlmost: 0.95
  readonly property real opacityFull: 1.0

  readonly property real effectivePanelOpacity: PowerProfileService.performanceMode ? 1.0 : Color.adaptiveOpacity(GlobalConfig.ui.panelBackgroundOpacity)
  readonly property real effectiveBarOpacity: PowerProfileService.performanceMode ? 1.0 : Settings.data.bar.backgroundOpacity

  readonly property real shadowOpacity: 0.85
  readonly property real shadowBlur: 1.0
  readonly property int shadowBlurMax: 22
  readonly property real shadowHorizontalOffset: GlobalConfig.general.shadowOffsetX
  readonly property real shadowVerticalOffset: GlobalConfig.general.shadowOffsetY

  // RYOKU: durations scaled by GlobalConfig.appearance.anim.durations.scale (0 = instant)
  readonly property int animationFaster: PowerProfileService.performanceMode ? 0 : Math.round(75 * GlobalConfig.appearance.anim.durations.scale)
  readonly property int animationFast: PowerProfileService.performanceMode ? 0 : Math.round(150 * GlobalConfig.appearance.anim.durations.scale)
  readonly property int animationNormal: PowerProfileService.performanceMode ? 0 : Math.round(300 * GlobalConfig.appearance.anim.durations.scale)
  readonly property int animationSlow: PowerProfileService.performanceMode ? 0 : Math.round(450 * GlobalConfig.appearance.anim.durations.scale)
  readonly property int animationSlowest: PowerProfileService.performanceMode ? 0 : Math.round(750 * GlobalConfig.appearance.anim.durations.scale)

  readonly property int tooltipDelay: 300
  readonly property int tooltipDelayLong: 1200
  readonly property int pillDelay: 500

  readonly property real baseWidgetSize: 33
  readonly property real sliderWidth: 200

  // RYOKU: master UI scale from GlobalConfig.appearance.deformScale (drives the
  // settings panel's margins/borders/sizing — so the UI scale slider works here).
  readonly property real uiScaleRatio: GlobalConfig.appearance.deformScale

  readonly property real barHeight: {
    let h;
    switch (Settings.data.bar.density) {
      case "mini":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 23 : 21;
      break;
      case "compact":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 27 : 25;
      break;
      case "comfortable":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 39 : 37;
      break;
      case "spacious":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 49 : 47;
      break;
      default:
      case "default":
      h = (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? 33 : 31;
    }
    return toOdd(h);
  }

  // Note: capsule must always be smaller than barHeight to account for border rendering
  // Qt Quick Rectangle borders are drawn centered on edges (half inside, half outside)
  readonly property real capsuleHeight: {
    let h;
    switch (Settings.data.bar.density) {
      case "mini":
      h = Math.round(barHeight * 0.90);
      break;
      case "compact":
      h = Math.round(barHeight * 0.85);
      break;
      case "comfortable":
      h = Math.round(barHeight * 0.75);
      break;
      case "spacious":
      h = Math.round(barHeight * 0.65);
      break;
      default:
      h = Math.round(barHeight * 0.82);
      break;
    }
    return toOdd(h);
  }

  readonly property real _barBaseFontSize: Math.max(1, (Style.barHeight / Style.capsuleHeight) * Style.fontSizeXXS)
  readonly property real barFontSize: (Settings.data.bar.position === "left" || Settings.data.bar.position === "right") ? _barBaseFontSize * 0.9 * Settings.data.bar.fontScale : _barBaseFontSize * Settings.data.bar.fontScale

  readonly property color capsuleColor: Settings.data.bar.showCapsule ? Qt.alpha(Settings.data.bar.capsuleColorKey !== "none" ? Color.resolveColorKey(Settings.data.bar.capsuleColorKey) : Color.mSurfaceVariant, Settings.data.bar.capsuleOpacity) : "transparent"

  readonly property color capsuleBorderColor: Settings.data.bar.showOutline ? Color.mPrimary : "transparent"
  readonly property int capsuleBorderWidth: Settings.data.bar.showOutline ? Style.borderS : 0

  readonly property color boxBorderColor: GlobalConfig.ui.boxBorderEnabled ? Color.mOutline : "transparent"

  // Pixel-perfect utility for centering content without subpixel positioning
  function pixelAlignCenter(containerSize, contentSize) {
    return Math.round((containerSize - contentSize) / 2);
  }

  // Ensures a number is always odd (rounds down to nearest odd)
  function toOdd(n) {
    return Math.floor(n / 2) * 2 + 1;
  }

  // Ensures a number is always even (rounds down to nearest even)
  function toEven(n) {
    return Math.floor(n / 2) * 2;
  }

  function getBarHeightForDensity(density, isVertical) {
    let h;
    switch (density) {
    case "mini":
      h = isVertical ? 23 : 21;
      break;
    case "compact":
      h = isVertical ? 27 : 25;
      break;
    case "comfortable":
      h = isVertical ? 39 : 37;
      break;
    case "spacious":
      h = isVertical ? 49 : 47;
      break;
    default:
    case "default":
      h = isVertical ? 33 : 31;
    }
    return toOdd(h);
  }

  function getCapsuleHeightForDensity(density, barHeight) {
    let h;
    switch (density) {
    case "mini":
      h = Math.round(barHeight * 0.90);
      break;
    case "compact":
      h = Math.round(barHeight * 0.85);
      break;
    case "comfortable":
      h = Math.round(barHeight * 0.75);
      break;
    case "spacious":
      h = Math.round(barHeight * 0.65);
      break;
    default:
      h = Math.round(barHeight * 0.82);
      break;
    }
    return toOdd(h);
  }

  function getBarFontSizeForDensity(barHeight, capsuleHeight, isVertical) {
    const baseFontSize = Math.max(1, (barHeight / capsuleHeight) * Style.fontSizeXXS);
    return isVertical ? baseFontSize * 0.9 * Settings.data.bar.fontScale : baseFontSize * Settings.data.bar.fontScale;
  }

  function getBarHeightForScreen(screenName) {
    var density = Settings.getBarDensityForScreen(screenName);
    var position = Settings.getBarPositionForScreen(screenName);
    var isVertical = position === "left" || position === "right";
    return getBarHeightForDensity(density, isVertical);
  }

  function getCapsuleHeightForScreen(screenName) {
    var barHeight = getBarHeightForScreen(screenName);
    var density = Settings.getBarDensityForScreen(screenName);
    return getCapsuleHeightForDensity(density, barHeight);
  }

  function getBarFontSizeForScreen(screenName) {
    var barHeight = getBarHeightForScreen(screenName);
    var capsuleHeight = getCapsuleHeightForScreen(screenName);
    var position = Settings.getBarPositionForScreen(screenName);
    var isVertical = position === "left" || position === "right";
    return getBarFontSizeForDensity(barHeight, capsuleHeight, isVertical);
  }
}
