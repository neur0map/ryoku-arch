pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * PlayerInfo - Reusable title/artist display
 */
ColumnLayout {
    id: root
    
    // Required properties
    required property string title
    required property string artist
    
    // Optional properties
    property color titleColor: Appearance.inirEverywhere 
        ? Appearance.inir.colText 
        : Appearance.colors.colOnLayer0
    property color artistColor: Appearance.inirEverywhere 
        ? Appearance.inir.colTextSecondary 
        : Appearance.colors.colSubtext
    property int titleSize: Appearance.font.pixelSize.large
    property int artistSize: Appearance.font.pixelSize.small
    property int titleWeight: Font.Medium
    property bool cleanTitle: true
    property bool animateTitle: true
    
    spacing: 0
    
    // Title
    StyledText {
        Layout.fillWidth: true
        text: root.cleanTitle ? StringUtils.cleanMusicTitle(root.title) || "—" : (root.title || "—")
        font.pixelSize: root.titleSize
        font.weight: root.titleWeight
        color: root.titleColor
        elide: Text.ElideRight
        animateChange: root.animateTitle
        animationDistanceX: 6
    }
    
    // Artist
    StyledText {
        Layout.fillWidth: true
        text: root.artist || ""
        font.pixelSize: root.artistSize
        color: root.artistColor
        elide: Text.ElideRight
        visible: text !== ""
    }
}
