pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import qs.modules.mediaControls.components

/**
 * CompactPlayer - Compact design with smaller artwork
 * Ideal for limited space, similar to sidebar player
 */
Item {
    id: root
    property MprisPlayer player: null
    property list<real> visualizerPoints: []
    property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.normal
    property real screenX: 0
    property real screenY: 0
    readonly property string vizType: Config.getNestedValue("background.widgets.mediaControls.visualizerType", "wave")
    readonly property string vizPosition: Config.getNestedValue("background.widgets.mediaControls.visualizerPosition", "bottom")
    
    PlayerBase {
        id: playerBase
        player: root.player
    }
    
    property QtObject blendedColors: AdaptedMaterialScheme { color: playerBase.artDominantColor }
    
    StyledRectangularShadow { 
        target: card
        visible: Appearance.angelEverywhere || (!Appearance.ryokuEverywhere && !Appearance.auroraEverywhere)
    }
    
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        height: parent.height - Appearance.sizes.elevationMargin
        radius: Appearance.ryokuEverywhere ? Appearance.ryoku.roundingNormal : root.radius
        color: Appearance.ryokuEverywhere ? playerBase.ryokuLayer1
             : Appearance.auroraEverywhere ? ColorUtils.transparentize(
                 blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.7
               )
             : (blendedColors?.colLayer0 ?? Appearance.colors.colLayer0)
        border.width: Appearance.ryokuEverywhere ? 1 : 0
        border.color: Appearance.ryokuEverywhere ? Appearance.ryoku.colBorder : "transparent"
        clip: true
        
        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle { width: card.width; height: card.height; radius: card.radius }
        }
        
        // Background art
        Image {
            anchors.fill: parent
            source: playerBase.displayedArtFilePath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: Appearance.ryokuEverywhere ? 0.15 : (Appearance.auroraEverywhere ? 0.25 : 0.5)
            visible: playerBase.displayedArtFilePath !== ""
            
            layer.enabled: Appearance.effectsEnabled
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: Appearance.ryokuEverywhere ? 0.3 : 0.15
                blurMax: 16
                saturation: Appearance.ryokuEverywhere ? 0.1 : 0.3
            }
        }
        
        // Gradient overlay for Material
        Rectangle {
            anchors.fill: parent
            visible: !Appearance.ryokuEverywhere && !Appearance.auroraEverywhere
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { 
                    position: 0.35
                    color: ColorUtils.transparentize(
                        blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.3
                    )
                }
                GradientStop { 
                    position: 1.0
                    color: ColorUtils.transparentize(
                        blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.15
                    )
                }
            }
        }
        
        // Visualizer overlay
        WaveVisualizer {
            visible: root.vizType === "wave" && root.vizPosition !== "none"
            anchors { left: parent.left; right: parent.right }
            y: root.vizPosition === "top" ? 0 : (parent.height - height)
            height: root.vizPosition === "fill" ? parent.height : 30
            live: playerBase.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            color: ColorUtils.transparentize(playerBase.artDominantColor, 0.4)
        }
        CavaVisualizer {
            visible: root.vizType === "bars" && root.vizPosition !== "none"
            anchors { left: parent.left; right: parent.right }
            y: root.vizPosition === "top" ? 0 : (parent.height - height)
            height: root.vizPosition === "fill" ? parent.height : 30
            live: playerBase.effectiveIsPlaying
            points: root.visualizerPoints
            maxVisualizerValue: 1000
            smoothing: 2
            barCount: 32
            barSpacing: 2
            barRadius: 2
            barMinHeight: 1
            colorLow: ColorUtils.transparentize(playerBase.artDominantColor, 0.3)
            colorMed: ColorUtils.transparentize(playerBase.artDominantColor, 0.1)
            colorHigh: playerBase.artDominantColor
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            
            // Compact cover art
            PlayerArtwork {
                Layout.preferredWidth: 110
                Layout.preferredHeight: 110
                artSource: playerBase.displayedArtFilePath
                downloaded: playerBase.downloaded
                artRadius: Appearance.ryokuEverywhere 
                    ? Appearance.ryoku.roundingSmall 
                    : Appearance.rounding.small
                placeholderColor: Appearance.ryokuEverywhere 
                    ? playerBase.ryokuLayer2 
                    : (blendedColors?.colLayer1 ?? Appearance.colors.colLayer1)
                iconColor: Appearance.ryokuEverywhere 
                    ? playerBase.ryokuTextSecondary 
                    : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
            }
            
            // Info & controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2
                
                // Title & Artist
                PlayerInfo {
                    Layout.fillWidth: true
                    title: playerBase.effectiveTitle
                    artist: playerBase.effectiveArtist
                    titleColor: Appearance.ryokuEverywhere 
                        ? playerBase.ryokuText 
                        : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    artistColor: Appearance.ryokuEverywhere 
                        ? playerBase.ryokuTextSecondary 
                        : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                    titleSize: Appearance.font.pixelSize.normal
                    artistSize: Appearance.font.pixelSize.smaller
                }
                
                Item { Layout.fillHeight: true }
                
                // Progress bar
                PlayerProgress {
                    Layout.fillWidth: true
                    implicitHeight: 16
                    position: playerBase.effectivePosition
                    length: playerBase.effectiveLength
                    canSeek: playerBase.effectiveCanSeek
                    isPlaying: playerBase.effectiveIsPlaying
                    highlightColor: Appearance.ryokuEverywhere 
                        ? playerBase.ryokuPrimary
                        : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                    trackColor: Appearance.ryokuEverywhere 
                        ? playerBase.ryokuLayer2
                        : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                    onSeekRequested: seconds => playerBase.seek(seconds)
                }
                
                // Time + controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(playerBase.effectivePosition)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.ryokuEverywhere 
                            ? playerBase.ryokuText 
                            : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    PlayerControls {
                        canGoPrevious: playerBase.effectiveCanGoPrevious
                        canGoNext: playerBase.effectiveCanGoNext
                        isPlaying: playerBase.effectiveIsPlaying
                        buttonRadius: Appearance.ryokuEverywhere 
                            ? Appearance.ryoku.roundingSmall 
                            : Appearance.rounding.full
                        buttonHoverColor: Appearance.ryokuEverywhere 
                            ? Appearance.ryoku.colLayer2Hover
                            : ColorUtils.transparentize(
                                blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5
                              )
                        buttonRippleColor: Appearance.ryokuEverywhere 
                            ? Appearance.ryoku.colLayer2Active
                            : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                        iconColor: Appearance.ryokuEverywhere 
                            ? playerBase.ryokuText
                            : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                        playIconColor: Appearance.ryokuEverywhere 
                            ? playerBase.ryokuPrimary
                            : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                        onPreviousClicked: playerBase.previous()
                        onPlayPauseClicked: playerBase.togglePlaying()
                        onNextClicked: playerBase.next()
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(playerBase.effectiveLength)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.ryokuEverywhere 
                            ? playerBase.ryokuText 
                            : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    }
                }
            }
        }
    }
}
