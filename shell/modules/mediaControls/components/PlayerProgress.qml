pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * PlayerProgress - Reusable progress bar/slider
 */
Item {
    id: root
    
    // Required properties
    required property real position
    required property real length
    required property bool canSeek
    required property bool isPlaying
    
    // Optional properties
    property color highlightColor: Appearance.inirEverywhere 
        ? Appearance.inir.colPrimary 
        : Appearance.colors.colPrimary
    property color trackColor: Appearance.inirEverywhere 
        ? Appearance.inir.colLayer2 
        : Appearance.colors.colSecondaryContainer
    property bool enableWavy: true
    property bool scrollable: true
    
    // Signals
    signal seekRequested(real seconds)
    
    readonly property real progressValue: length > 0 ? position / length : 0
    
    // Seekable slider
    Loader {
        anchors.fill: parent
        active: root.canSeek
        sourceComponent: StyledSlider {
            configuration: root.enableWavy ? StyledSlider.Configuration.Wavy : StyledSlider.Configuration.S
            wavy: root.enableWavy && root.isPlaying
            animateWave: root.enableWavy && root.isPlaying
            highlightColor: root.highlightColor
            trackColor: root.trackColor
            handleColor: root.highlightColor
            value: root.progressValue
            onMoved: root.seekRequested(value * root.length)
            scrollable: root.scrollable
        }
    }
    
    // Non-seekable progress bar
    Loader {
        anchors.fill: parent
        active: !root.canSeek
        sourceComponent: StyledProgressBar {
            wavy: root.enableWavy && root.isPlaying
            animateWave: root.enableWavy && root.isPlaying
            highlightColor: root.highlightColor
            trackColor: root.trackColor
            value: root.progressValue
        }
    }
}
