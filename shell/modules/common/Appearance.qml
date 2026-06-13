pragma Singleton

import QtQuick
import Quickshell
import qs.services
import Ryoku.Config

// Ryoku Appearance: the shell-wide theme API (colors/rounding/font/animation/sizes
// + angel/inir/aurora variants) backed by Ryoku's Colours palette and Tokens. The
// angel/inir/aurora variant branches were collapsed to the default Material path; the
// variant style objects remain stubbed (pending removal) so any lingering reference resolves.
Singleton {
    id: root

    // Game mode freezes every Behavior/animation gated on these. Note the key's
    // polarity: gameMode.shellAnimations names the bundled ACTION ("freeze shell
    // animations"), like its dnd/pauseWallpaper siblings — true ⇒ quiet, NOT
    // "animations stay on".
    readonly property bool _gameModeQuiet: GameMode.enabled && GlobalConfig.gameMode.shellAnimations
    readonly property bool animationsEnabled: !_gameModeQuiet && !GlobalConfig.appearance.reduceMotion
    readonly property bool effectsEnabled: !_gameModeQuiet
    // RYOKU: derive card transparency from the live transparency setting (was hardcoded 0
    // = always opaque, ignoring appearance.transparency). Consumers apply alpha = 1 - this,
    // so 1 - base matches the shell's glass; 0 (opaque) when transparency is off.
    readonly property real backgroundTransparency: Colours.transparency.enabled ? (1 - Colours.transparency.base) : 0

    function calcEffectiveDuration(d) {
        return root.animationsEnabled ? d : 0;
    }

    readonly property QtObject colors: QtObject {
        readonly property color colLayer0: Colours.palette.m3surface
        readonly property color colLayer0Base: Colours.palette.m3surface
        readonly property color colLayer0Border: Colours.palette.m3outlineVariant
        readonly property color colLayer1: Colours.palette.m3surfaceContainer
        readonly property color colLayer1Base: Colours.palette.m3surfaceContainer
        readonly property color colLayer1Hover: Colours.palette.m3surfaceContainerHigh
        readonly property color colLayer1Active: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer2: Colours.palette.m3surfaceContainerHigh
        readonly property color colLayer2Base: Colours.palette.m3surfaceContainerHigh
        readonly property color colLayer2Hover: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer2Active: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer3: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer3Hover: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer3Active: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer4: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer4Hover: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer4Active: Colours.palette.m3surfaceContainerHighest
        readonly property color colOnLayer0: Colours.palette.m3onSurface
        readonly property color colOnLayer1: Colours.palette.m3onSurface
        readonly property color colOnLayer2: Colours.palette.m3onSurface
        readonly property color colOnLayer3: Colours.palette.m3onSurface
        readonly property color colOnPrimary: Colours.palette.m3onPrimary
        readonly property color colOnPrimaryContainer: Colours.palette.m3onPrimaryContainer
        readonly property color colOnSecondaryContainer: Colours.palette.m3onSecondaryContainer
        readonly property color colOnSurface: Colours.palette.m3onSurface
        readonly property color colOnSurfaceVariant: Colours.palette.m3onSurfaceVariant
        readonly property color colOutline: Colours.palette.m3outline
        readonly property color colOutlineVariant: Colours.palette.m3outlineVariant
        readonly property color colPrimary: Colours.palette.m3primary
        readonly property color colPrimaryContainer: Colours.palette.m3primaryContainer
        readonly property color colError: Colours.palette.m3error
        readonly property color colErrorActive: Colours.palette.m3error
        readonly property color colErrorContainer: Colours.palette.m3errorContainer
        readonly property color colOnErrorContainer: Colours.palette.m3onErrorContainer
        readonly property color colScrim: Colours.palette.m3scrim
        readonly property color colShadow: Colours.palette.m3shadow
        readonly property color colSecondaryContainer: Colours.palette.m3secondaryContainer
        readonly property color colSecondaryContainerHover: Colours.palette.m3secondaryContainer
        readonly property color colSecondaryContainerActive: Colours.palette.m3secondaryContainer
        readonly property color colSubtext: Colours.palette.m3onSurfaceVariant
        readonly property color colSurfaceContainer: Colours.palette.m3surfaceContainer
        readonly property color colSurfaceContainerHighest: Colours.palette.m3surfaceContainerHighest
    }

    readonly property QtObject m3colors: QtObject {
        readonly property bool darkmode: !Colours.light
        readonly property color m3onPrimary: Colours.palette.m3onPrimary
        readonly property color m3onSecondaryContainer: Colours.palette.m3onSecondaryContainer
        readonly property color m3onSurface: Colours.palette.m3onSurface
        readonly property color m3onSurfaceVariant: Colours.palette.m3onSurfaceVariant
        readonly property color m3outline: Colours.palette.m3outline
        readonly property color m3primary: Colours.palette.m3primary
        readonly property color m3surfaceContainer: Colours.palette.m3surfaceContainer
    }

    readonly property QtObject rounding: QtObject {
        readonly property int verysmall: Tokens.rounding.extraSmall
        readonly property int unsharpen: Tokens.rounding.extraSmall
        readonly property int small: Tokens.rounding.small
        readonly property int normal: Tokens.rounding.normal
        readonly property int large: Tokens.rounding.large
        readonly property int full: Tokens.rounding.full
        readonly property int windowRounding: Tokens.rounding.large
    }

    readonly property QtObject font: QtObject {
        // These are consumed as PIXEL sizes, but Ryoku's Tokens.font.size are POINT
        // sizes. Convert pt->px (~1.33 at 96dpi) so text/icons visually match
        // Ryoku's own widgets instead of rendering too small.
        readonly property QtObject pixelSize: QtObject {
            readonly property real _pxScale: 96 / 72
            function _px(pt) {
                return Math.round(pt * _pxScale);
            }
            readonly property int smallest: _px(Tokens.font.size.smaller)
            readonly property int smaller: _px(Tokens.font.size.smaller)
            readonly property int smallie: _px(Tokens.font.size.smaller)
            readonly property int small: _px(Tokens.font.size.small)
            readonly property int normal: _px(Tokens.font.size.normal)
            readonly property int large: _px(Tokens.font.size.large)
            readonly property int larger: _px(Tokens.font.size.larger)
            readonly property int huge: _px(Tokens.font.size.extraLarge)
        }
        readonly property QtObject family: QtObject {
            readonly property string main: Tokens.font.family.sans
            readonly property string numbers: Tokens.font.family.mono
            readonly property string monospace: Tokens.font.family.mono
            readonly property string iconMaterial: Tokens.font.family.material
        }
        readonly property QtObject variableAxes: QtObject {
            readonly property var main: ({})
            readonly property var numbers: ({})
        }
    }

    readonly property QtObject sizes: QtObject {
        readonly property int elevationMargin: 8
        readonly property int spacingSmall: Tokens.spacing.small
        readonly property int spacingMedium: Tokens.spacing.normal
    }

    readonly property var _curve: [0.34, 0.80, 0.34, 1.00, 1, 1]
    readonly property var _decel: [0.05, 0.7, 0.1, 1.0, 1, 1]

    readonly property QtObject animation: QtObject {
        readonly property QtObject elementMove: QtObject {
            readonly property int duration: 200
            readonly property int type: Easing.BezierSpline
            readonly property var bezierCurve: root._curve
        }
        readonly property QtObject elementMoveEnter: QtObject {
            readonly property int duration: 300
            readonly property int type: Easing.BezierSpline
            readonly property var bezierCurve: root._decel
        }
        readonly property QtObject elementMoveExit: QtObject {
            readonly property int duration: 200
            readonly property int type: Easing.BezierSpline
            readonly property var bezierCurve: root._curve
        }
        readonly property QtObject elementMoveFast: QtObject {
            readonly property int duration: 150
            readonly property int type: Easing.BezierSpline
            readonly property var bezierCurve: root._curve
        }
        readonly property QtObject elementResize: QtObject {
            readonly property int duration: 200
            readonly property int type: Easing.BezierSpline
            readonly property var bezierCurve: root._curve
        }
        readonly property QtObject clickBounce: QtObject {
            readonly property int duration: 200
            readonly property int type: Easing.BezierSpline
            readonly property var bezierCurve: root._curve
        }
        readonly property QtObject scroll: QtObject {
            readonly property int duration: 200
            readonly property int type: Easing.BezierSpline
            readonly property var bezierCurve: root._decel
        }
    }

    readonly property QtObject animationCurves: QtObject {
        readonly property var standardDecel: root._decel
        readonly property var expressiveFastSpatial: root._curve
    }

    readonly property QtObject angel: QtObject {
        readonly property color colGlassPanel: Colours.palette.m3surfaceContainer
        readonly property color colGlassPopup: Colours.palette.m3surfaceContainer
        readonly property color colGlassPopupHover: Colours.palette.m3surfaceContainerHigh
        readonly property color colGlassPopupActive: Colours.palette.m3surfaceContainerHighest
        readonly property color colGlassTooltip: Colours.palette.m3surfaceContainer
        readonly property color colGlassCard: Colours.palette.m3surfaceContainer
        readonly property color colGlassCardHover: Colours.palette.m3surfaceContainerHigh
        readonly property color colGlassCardActive: Colours.palette.m3surfaceContainerHighest
        readonly property color colEscalonado: Colours.palette.m3surfaceContainer
        readonly property color colEscalonadoHover: Colours.palette.m3surfaceContainerHigh
        readonly property color colEscalonadoBorder: Colours.palette.m3outlineVariant
        readonly property color colInsetGlow: Colours.palette.m3surfaceContainerHighest
        readonly property color colBorder: Colours.palette.m3outlineVariant
        readonly property color colBorderHover: Colours.palette.m3outline
        readonly property color colBorderSubtle: Colours.palette.m3outlineVariant
        readonly property color colPrimary: Colours.palette.m3primary
        readonly property color colOnPrimary: Colours.palette.m3onPrimary
        readonly property color colText: Colours.palette.m3onSurface
        readonly property color colTextSecondary: Colours.palette.m3onSurfaceVariant
        readonly property real overlayOpacity: 0.4
        readonly property real colorStrength: 1
        readonly property real blurIntensity: 1
        readonly property real blurSaturation: 1.2
        readonly property int roundingNormal: Tokens.rounding.normal
        readonly property int roundingSmall: Tokens.rounding.small
        readonly property int cardBorderWidth: 1
        readonly property int borderWidth: 1
        readonly property real borderCoverage: 0.5
        readonly property int insetGlowHeight: 8
        readonly property int escalonadoOffsetX: 0
        readonly property int escalonadoOffsetY: 0
        readonly property int escalonadoHoverOffsetX: 0
        readonly property int escalonadoHoverOffsetY: 0
    }

    readonly property QtObject inir: QtObject {
        readonly property color colLayer1: Colours.palette.m3surfaceContainer
        readonly property color colLayer2: Colours.palette.m3surfaceContainerHigh
        readonly property color colLayer2Hover: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer2Active: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer3: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer3Hover: Colours.palette.m3surfaceContainerHighest
        readonly property color colLayer3Active: Colours.palette.m3surfaceContainerHighest
        readonly property color colBorder: Colours.palette.m3outlineVariant
        readonly property color colBorderSubtle: Colours.palette.m3outlineVariant
        readonly property color colPrimary: Colours.palette.m3primary
        readonly property color colPrimaryActive: Colours.palette.m3primary
        readonly property color colOnPrimary: Colours.palette.m3onPrimary
        readonly property color colOnPrimaryContainer: Colours.palette.m3onPrimaryContainer
        readonly property color colSelection: Colours.palette.m3secondaryContainer
        readonly property color colSelectionHover: Colours.palette.m3secondaryContainer
        readonly property color colOnSelection: Colours.palette.m3onSecondaryContainer
        readonly property color colText: Colours.palette.m3onSurface
        readonly property color colTextSecondary: Colours.palette.m3onSurfaceVariant
        readonly property int roundingNormal: Tokens.rounding.normal
        readonly property int roundingSmall: Tokens.rounding.small
    }

    readonly property QtObject aurora: QtObject {
        readonly property color colElevatedSurface: Colours.palette.m3surfaceContainerHigh
        readonly property color colElevatedSurfaceHover: Colours.palette.m3surfaceContainerHighest
        readonly property color colPopupSurface: Colours.palette.m3surfaceContainer
        readonly property color colSubSurface: Colours.palette.m3surfaceContainerHigh
        readonly property color colSubSurfaceHover: Colours.palette.m3surfaceContainerHighest
        readonly property color colSubSurfaceActive: Colours.palette.m3surfaceContainerHighest
        readonly property color colTooltipSurface: Colours.palette.m3surfaceContainer
        readonly property color colTooltipBorder: Colours.palette.m3outlineVariant
        readonly property real popupTransparentize: 0
    }
}
