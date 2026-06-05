import QtQuick
import QtQuick.Effects
import qs.ambxst.modules.theme
import qs.ambxst.config

Item {
    id: root
    property string source: ""
    property real radius: 0
    property bool tintEnabled: false
    
    readonly property var optimizedPalette: [
        "background", "overBackground", "shadow",
        "surface", "surfaceBright", "surfaceDim",
        "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceContainerLow", "surfaceContainerLowest",
        "primary", "secondary", "tertiary",
        "red", "lightRed",
        "green", "lightGreen",
        "blue", "lightBlue",
        "yellow", "lightYellow",
        "cyan", "lightCyan",
        "magenta", "lightMagenta"
    ]

    Item {
        id: paletteSourceItem
        visible: true 
        width: root.optimizedPalette.length
        height: 1
        opacity: 0
        
        Row {
            anchors.fill: parent
            Repeater {
                model: root.optimizedPalette
                Rectangle {
                    width: 1
                    height: 1
                    color: Colors[modelData]
                }
            }
        }
    }

    ShaderEffectSource {
        id: paletteTextureSource
        sourceItem: paletteSourceItem
        hideSource: true
        visible: false
        smooth: false
        recursive: false
    }

    Item {
        anchors.fill: parent
        layer.enabled: root.radius > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            maskSource: ShaderEffectSource {
                sourceItem: Rectangle {
                    width: root.width
                    height: root.height
                    radius: root.radius
                }
            }
        }

        Image {
            mipmap: true
            id: rawImage
            anchors.fill: parent
            source: root.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            
            layer.enabled: root.tintEnabled
            layer.effect: ShaderEffect {
                property var paletteTexture: paletteTextureSource
                property real paletteSize: root.optimizedPalette.length
                property real texWidth: rawImage.width
                property real texHeight: rawImage.height

                vertexShader: "../widgets/dashboard/wallpapers/palette.vert.qsb"
                fragmentShader: "../widgets/dashboard/wallpapers/palette.frag.qsb"
            }
        }
    }
}
