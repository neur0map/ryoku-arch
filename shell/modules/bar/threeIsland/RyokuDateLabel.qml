import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Day of week + date label for the left island. Day of week in accent color,
 * date in normal text. Stacked tightly with a thin separator dot.
 */
Item {
    id: root

    readonly property color colAccent: Appearance.angelEverywhere ? Appearance.angel.colAccent
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colAccent
        : Appearance.colors.colPrimary
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colText
        : Appearance.colors.colOnLayer1

    // DateTime.date is "dddd, dd/MM" by default; split on comma for two-tone display.
    readonly property string _full: DateTime.date
    readonly property int _commaIdx: _full.indexOf(",")
    readonly property string _day: _commaIdx >= 0 ? _full.substring(0, _commaIdx).trim() : _full
    readonly property string _date: _commaIdx >= 0 ? _full.substring(_commaIdx + 1).trim() : ""

    implicitWidth: row.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2
            color: root.colAccent
            text: root._day
        }

        StyledText {
            visible: root._date.length > 0
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            color: root.colAccent
            text: "·"
        }

        StyledText {
            visible: root._date.length > 0
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            color: root.colText
            text: root._date
        }
    }
}
