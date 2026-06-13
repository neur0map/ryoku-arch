pragma Singleton

import QtQuick
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.Power
import qs.services

/*
RYOKU ADAPTER.

Upstream this singleton loaded the upstream shell's own color scheme (a navy "upstream
default" palette / colors.json). In ryoku we instead bind every Material-3 role
to ryoku's shell-wide palette (`Colours.palette.m3*`) — the SAME colors the bar
and frame use — so the settings panel matches ryoku's theme and the upstream navy
never mixes in.

The public API (m* color roles + helper functions + colorKeyModel) is preserved
so ryoku's settings widgets keep working unchanged.
TODO: if a separate "settings accent" is ever wanted, remap the roles here.
*/
Singleton {
  id: root

  // Kept for API compatibility with the settings widgets (no live scheme reload here).
  property bool reloadColors: false
  property bool skipTransition: false
  property bool isTransitioning: false
  function startTransition() {}
  function scheduleExternalColorReload() {}

  // --- Material 3 roles, bound to ryoku's shell palette (bar/frame colors) ---
  readonly property color mPrimary: Colours.palette.m3primary
  readonly property color mOnPrimary: Colours.palette.m3onPrimary
  readonly property color mSecondary: Colours.palette.m3secondary
  readonly property color mOnSecondary: Colours.palette.m3onSecondary
  readonly property color mTertiary: Colours.palette.m3tertiary
  readonly property color mOnTertiary: Colours.palette.m3onTertiary

  readonly property color mError: Colours.palette.m3error
  readonly property color mOnError: Colours.palette.m3onError

  // RYOKU: surfaces use tPalette (transparency-applied) so the panel goes
  // see-through + blurred like ryoku's other windows and reacts live to the
  // transparency settings (GlobalConfig.appearance.transparency.*). On-colors
  // and accents stay on the opaque palette for crisp, readable text.
  // Use the CONTAINER tones: tPalette m3surface/m3surfaceVariant key off
  // transparency.base (=1 → opaque), but the container tones key off
  // transparency.layers (the see-through "glass" ryoku panels use). So these
  // go translucent + blurred and react to the Surface-opacity slider.
  readonly property color mSurface: Colours.tPalette.m3surfaceContainer
  readonly property color mOnSurface: Colours.palette.m3onSurface

  readonly property color mSurfaceVariant: Colours.tPalette.m3surfaceContainerHigh
  readonly property color mOnSurfaceVariant: Colours.palette.m3onSurfaceVariant

  // Opaque variants of the surface tones, for floating popups/modals. The
  // settings window is translucent + blurred, but a Qt Popup floats with no
  // blur backdrop, so the glass surface tones above render see-through over
  // whatever sits behind. Popups use these full-alpha tones to stay readable.
  readonly property color mSurfaceOpaque: Qt.alpha(root.mSurface, 1.0)
  readonly property color mSurfaceVariantOpaque: Qt.alpha(root.mSurfaceVariant, 1.0)

  readonly property color mOutline: Colours.palette.m3outline
  readonly property color mShadow: Colours.palette.m3shadow

  readonly property color mHover: Colours.palette.m3secondaryContainer
  readonly property color mOnHover: Colours.palette.m3onSecondaryContainer

  // --- Helpers used by the settings widgets ---
  function resolveColorKey(key) {
    switch (key) {
    case "primary":
      return root.mPrimary;
    case "secondary":
      return root.mSecondary;
    case "tertiary":
      return root.mTertiary;
    case "error":
      return root.mError;
    default:
      return root.mOnSurface;
    }
  }

  function resolveOnColorKey(key) {
    switch (key) {
    case "primary":
      return root.mOnPrimary;
    case "secondary":
      return root.mOnSecondary;
    case "tertiary":
      return root.mOnTertiary;
    case "error":
      return root.mOnError;
    default:
      return root.mSurface;
    }
  }

  function resolveColorKeyOptional(key) {
    switch (key) {
    case "primary":
      return root.mPrimary;
    case "secondary":
      return root.mSecondary;
    case "tertiary":
      return root.mTertiary;
    case "error":
      return root.mError;
    default:
      return "transparent";
    }
  }

  // Adaptive opacity: light mode rendered slightly more transparent (follows ryoku light state).
  function adaptiveOpacity(baseOpacity) {
    if (PowerProfileService.performanceMode)
      return 1.0;
    return Colours.light ? Math.pow(baseOpacity, 1.5) : baseOpacity;
  }

  function smartAlpha(baseColor, minAlpha = 0.4) {
    if (PowerProfileService.performanceMode)
      return baseColor;
    if (!Settings.data.ui.translucentWidgets)
      return baseColor;
    let alpha = Math.max(adaptiveOpacity(Settings.data.ui.panelBackgroundOpacity), minAlpha);
    let resultAlpha = Math.max(0, baseColor.a - (1.0 - alpha));
    return Qt.alpha(baseColor, resultAlpha);
  }

  readonly property var colorKeyModel: [
    {
      "key": "none",
      "name": I18n.tr("common.none")
    },
    {
      "key": "primary",
      "name": I18n.tr("common.primary")
    },
    {
      "key": "secondary",
      "name": I18n.tr("common.secondary")
    },
    {
      "key": "tertiary",
      "name": I18n.tr("common.tertiary")
    },
    {
      "key": "error",
      "name": I18n.tr("common.error")
    }
  ]
}
