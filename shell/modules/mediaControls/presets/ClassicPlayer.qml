pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
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
 * ClassicPlayer - Classic media player design
 * Traditional centered layout with artwork on left
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
        
        // Visualizer overlay
        WaveVisualizer {
            visible: root.vizType === "wave" && root.vizPosition !== "none"
            anchors { left: parent.left; right: parent.right }
            y: root.vizPosition === "top" ? 0 : (parent.height - height)
            height: root.vizPosition === "fill" ? parent.height : 35
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
            height: root.vizPosition === "fill" ? parent.height : 35
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
            anchors.margins: 12
            spacing: 12
            
            // Cover art
            PlayerArtwork {
                Layout.preferredWidth: card.height - 24
                Layout.preferredHeight: card.height - 24
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
            
            // Info & controls centered
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
                
                // Title
                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    text: StringUtils.cleanMusicTitle(playerBase.effectiveTitle) || "—"
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Medium
                    color: Appearance.ryokuEverywhere 
                        ? playerBase.ryokuText 
                        : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    animateChange: true
                    animationDistanceX: 6
                }
                
                // Artist
                StyledText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    text: playerBase.effectiveArtist || ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.ryokuEverywhere 
                        ? playerBase.ryokuTextSecondary 
                        : (blendedColors?.colSubtext ?? Appearance.colors.colSubtext)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    visible: text !== ""
                }
                
                Item { Layout.fillHeight: true }
                
                // Controls centered
                PlayerControls {
                    canGoPrevious: playerBase.effectiveCanGoPrevious
                    canGoNext: playerBase.effectiveCanGoNext
                    Layout.alignment: Qt.AlignHCenter
                    isPlaying: playerBase.effectiveIsPlaying
                    buttonRadius: Appearance.ryokuEverywhere 
                        ? Appearance.ryoku.roundingSmall 
                        : Appearance.rounding.full
                    buttonHoverColor: Appearance.ryokuEverywhere 
                        ? Appearance.ryoku.colLayer2Hover
                        : Appearance.auroraEverywhere 
                            ? Appearance.aurora.colSubSurface
                            : ColorUtils.transparentize(
                                blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5
                              )
                    buttonRippleColor: Appearance.ryokuEverywhere 
                        ? Appearance.ryoku.colLayer2Active
                        : Appearance.auroraEverywhere 
                            ? Appearance.aurora.colSubSurfaceActive
                            : (blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active)
                    iconColor: Appearance.ryokuEverywhere 
                        ? playerBase.ryokuText
                        : Appearance.auroraEverywhere 
                            ? Appearance.colors.colOnLayer0
                            : (blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0)
                    playIconColor: Appearance.ryokuEverywhere 
                        ? playerBase.ryokuPrimary
                        : Appearance.auroraEverywhere 
                            ? Appearance.colors.colOnLayer0
                            : Appearance.colors.colOnLayer1
                    onPreviousClicked: playerBase.previous()
                    onPlayPauseClicked: playerBase.togglePlaying()
                    onNextClicked: playerBase.next()
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
                        : Appearance.auroraEverywhere 
                            ? Appearance.colors.colPrimary
                            : (blendedColors?.colPrimary ?? Appearance.colors.colPrimary)
                    trackColor: Appearance.ryokuEverywhere 
                        ? playerBase.ryokuLayer2
                        : Appearance.auroraEverywhere 
                            ? Appearance.aurora.colElevatedSurface
                            : (blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer)
                    onSeekRequested: seconds => playerBase.seek(seconds)
                }
                
                // Time labels
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
