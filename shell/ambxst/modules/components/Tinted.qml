pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs.ambxst.modules.theme
import qs.ambxst.config

Item {
    id: root
    property var sourceItem: null
    property bool fullTint: false

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
                delegate: Rectangle {
                    id: paletteRect
                    required property string modelData
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

    property bool active: Config.tintIcons

    Loader {
        active: root.active
        anchors.fill: parent
        sourceComponent: Item {
            anchors.fill: parent

            ShaderEffectSource {
                id: internalSource
                sourceItem: root.sourceItem
                hideSource: true
                live: false
            }
            
            Connections {
                target: root.sourceItem
                function onSourceChanged() { internalSource.scheduleUpdate(); }
                function onStatusChanged() { internalSource.scheduleUpdate(); }
            }
            
            Connections {
                target: root
                function onSourceItemChanged() { internalSource.scheduleUpdate(); }
                function onVisibleChanged() { if (root.visible) internalSource.scheduleUpdate(); }
            }

            MultiEffect {
                visible: root.fullTint
                anchors.fill: parent
                source: internalSource
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Styling.srItem("overprimary")
            }

            ShaderEffect {
                visible: !root.fullTint
                anchors.fill: parent
                
                property var source: internalSource
                property var paletteTexture: paletteTextureSource
                property real paletteSize: root.optimizedPalette.length
                property real texWidth: root.width
                property real texHeight: root.height

                vertexShader: "../widgets/dashboard/wallpapers/palette.vert.qsb"
                fragmentShader: "../widgets/dashboard/wallpapers/palette.frag.qsb"
            }
        }
    }
}
