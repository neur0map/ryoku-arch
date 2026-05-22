import Quickshell.Io

JsonObject {
    property Rounding rounding: Rounding {}
    property Spacing spacing: Spacing {}
    property Padding padding: Padding {}
    property FontStuff font: FontStuff {}
    property Anim anim: Anim {}
    property Transparency transparency: Transparency {}

    component Rounding: JsonObject {
        property real scale: 1
        property int extraSmall: 8 * scale
        property int small: 12 * scale
        property int normal: 17 * scale
        property int large: 25 * scale
        property int full: 1000 * scale
    }

    component Spacing: JsonObject {
        property real scale: 1
        // Canonical names (ascending order)
        property int xs: 5 * scale
        property int sm: 7 * scale
        property int md: 10 * scale
        property int lg: 12 * scale
        property int xl: 15 * scale
        property int xxl: 20 * scale
        // Backward-compat aliases
        readonly property int extraSmall: xs
        readonly property int small: sm
        readonly property int smaller: md
        readonly property int normal: lg
        readonly property int larger: xl
        readonly property int large: xxl
    }

    component Padding: JsonObject {
        property real scale: 1
        // Canonical names (ascending order)
        property int xs: 5 * scale
        property int sm: 7 * scale
        property int md: 10 * scale
        property int lg: 12 * scale
        property int xl: 15 * scale
        // Backward-compat aliases
        readonly property int small: xs
        readonly property int smaller: sm
        readonly property int normal: md
        readonly property int larger: lg
        readonly property int large: xl
    }

    component FontFamily: JsonObject {
        property string sans: "Rubik"
        property string mono: "CaskaydiaCove NF"
        property string material: "Material Symbols Rounded"
        property string clock: "Rubik"
    }

    component FontSize: JsonObject {
        property real scale: 1
        // M3-inspired canonical names (ascending order)
        property int labelSmall: Math.max(1, Math.round(8 * scale))
        property int labelMedium: Math.max(1, Math.round(10 * scale))
        property int labelLarge: Math.max(1, Math.round(11 * scale))
        property int bodySmall: Math.max(1, Math.round(12 * scale))
        property int bodyMedium: Math.max(1, Math.round(13 * scale))
        property int bodyLarge: Math.max(1, Math.round(15 * scale))
        property int titleMedium: Math.max(1, Math.round(18 * scale))
        property int headlineLarge: Math.max(1, Math.round(28 * scale))
        // Backward-compat aliases
        readonly property int ultraSmall: labelSmall
        readonly property int extraSmall: labelMedium
        readonly property int small: labelLarge
        readonly property int smaller: bodySmall
        readonly property int normal: bodyMedium
        readonly property int larger: bodyLarge
        readonly property int large: titleMedium
        readonly property int extraLarge: headlineLarge
    }

    component FontStuff: JsonObject {
        property FontFamily family: FontFamily {}
        property FontSize size: FontSize {}
    }

    component AnimCurves: JsonObject {
        property list<real> emphasized: [0.05, 0, 2 / 15, 0.06, 1 / 6, 0.4, 5 / 24, 0.82, 0.25, 1, 1, 1]
        property list<real> emphasizedAccel: [0.3, 0, 0.8, 0.15, 1, 1]
        property list<real> emphasizedDecel: [0.05, 0.7, 0.1, 1, 1, 1]
        property list<real> standard: [0.2, 0, 0, 1, 1, 1]
        property list<real> standardAccel: [0.3, 0, 1, 1, 1, 1]
        property list<real> standardDecel: [0, 0, 0, 1, 1, 1]
        property list<real> expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
        property list<real> expressiveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
        property list<real> expressiveEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    }

    component AnimDurations: JsonObject {
        property real scale: 1
        property int small: 200 * scale
        property int normal: 400 * scale
        property int large: 600 * scale
        property int extraLarge: 1000 * scale
        property int expressiveFastSpatial: 350 * scale
        property int expressiveDefaultSpatial: 500 * scale
        property int expressiveEffects: 200 * scale
    }

    component Anim: JsonObject {
        property AnimCurves curves: AnimCurves {}
        property AnimDurations durations: AnimDurations {}
    }

    component Transparency: JsonObject {
        property bool enabled: false
        property bool reduceTransparency: false
        property real base: 0.85
        property real layers: 0.4
    }
}