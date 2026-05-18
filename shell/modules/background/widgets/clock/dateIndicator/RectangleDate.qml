
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Rectangle {
    id: rect
    readonly property string dialStyle: Config.getNestedValue("background.widgets.clock.cookie.dialNumberStyle", "full")
    readonly property string clockFontFamily: Config.getNestedValue("background.widgets.clock.fontFamily", "Space Grotesk")

    StyledText {
        anchors.centerIn: parent
        color: Appearance.colors.colSecondaryHover
        text: Qt.locale().toString(DateTime.clock.date, "dd")
        font {
            family: rect.clockFontFamily
            pixelSize: 20
            weight: 1000
        }
    }
}
