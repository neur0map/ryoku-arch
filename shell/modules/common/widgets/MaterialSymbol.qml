import qs.modules.common
import QtQuick

Item {
    id: root
    property real iconSize: Appearance?.font.pixelSize.small ?? 16
    property real fill: 0
    property string text: ""
    property color color: Appearance.m3colors.m3onSurface
    property int horizontalAlignment: Text.AlignHCenter
    property int verticalAlignment: Text.AlignVCenter
    property alias font: iconText.font
    property alias style: iconText.style
    property alias styleColor: iconText.styleColor
    property bool animateChange: false  // Compatibility with StyledText
    property bool forceNerd: false  // Force Nerd Font rendering (text is already a glyph)
    
    // Auto-switch to Nerd Font when inir is active
    readonly property bool useNerd: forceNerd || Appearance.inirEverywhere
    readonly property string nerdGlyph: forceNerd ? text : NerdIconMap.get(text)
    readonly property bool hasNerdGlyph: nerdGlyph !== ""
    
    // Nerd fonts need slightly larger size to match Material Symbols visually
    readonly property real effectiveFontSize: (useNerd && hasNerdGlyph) ? iconSize * 1.1 : iconSize
    readonly property real effectiveSize: (useNerd && hasNerdGlyph) ? iconSize * 1.1 : iconSize
    
    // Use iconSize for consistent sizing regardless of font metrics
    implicitWidth: effectiveSize
    implicitHeight: effectiveSize
    
    readonly property real clampedFill: Math.max(0, Math.min(1, fill))
    readonly property real effectiveFill: clampedFill < 0.01 ? 0 : (clampedFill > 0.99 ? 1 : clampedFill)
    // Material Symbols variable font axis range is 20..48; keeping it in-range avoids distorted fill at small icon sizes.
    readonly property real effectiveOpsz: Math.max(20, Math.min(48, iconSize))
    
    Text {
        id: iconText
        anchors.centerIn: parent
        width: root.effectiveSize
        height: root.effectiveSize
        text: (root.useNerd && root.hasNerdGlyph) ? root.nerdGlyph : root.text
        color: root.color
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        
        renderType: Text.NativeRendering
        font {
            hintingPreference: (root.useNerd && root.hasNerdGlyph) ? Font.PreferFullHinting : Font.PreferNoHinting
            family: (root.useNerd && root.hasNerdGlyph) 
                ? (Appearance?.font.family.monospace ?? "JetBrainsMono Nerd Font") 
                : (Appearance?.font.family.iconMaterial ?? "Material Symbols Rounded")
            pixelSize: root.effectiveFontSize
            weight: Font.Normal
            variableAxes: (root.useNerd && root.hasNerdGlyph) ? ({}) : ({ 
                "FILL": root.effectiveFill,
                "opsz": root.effectiveOpsz,
            })
        }
    }

    Behavior on fill {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance?.animation.elementMoveFast.duration ?? 200
            easing.type: Appearance?.animation.elementMoveFast.type ?? Easing.BezierSpline
            easing.bezierCurve: Appearance?.animation.elementMoveFast.bezierCurve ?? [0.34, 0.80, 0.34, 1.00, 1, 1]
        }
    }

    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation {
            duration: Appearance?.animation.elementMoveFast.duration ?? 200
            easing.type: Appearance?.animation.elementMoveFast.type ?? Easing.BezierSpline
            easing.bezierCurve: Appearance?.animation.elementMoveFast.bezierCurve ?? [0.34, 0.80, 0.34, 1.00, 1, 1]
        }
    }
}
