import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Day of week + date label. Day of week in uppercase accent color, date
 * in normal text, separated by a center dot. Use compact: true for the
 * cramped center-island stack (smaller font).
 */
Item {
    id: root

    property bool compact: false
    readonly property int fontPx: compact
        ? Appearance.font.pixelSize.smaller
        : Appearance.font.pixelSize.normal

    readonly property color colAccent: Appearance.angelEverywhere ? Appearance.angel.colAccent
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colAccent
        : Appearance.colors.colPrimary
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colText
        : Appearance.colors.colOnLayer1

    readonly property string _full: DateTime.date
    readonly property int _commaIdx: _full.indexOf(",")
    readonly property string _day: _commaIdx >= 0 ? _full.substring(0, _commaIdx).trim() : _full
    readonly property string _date: _commaIdx >= 0 ? _full.substring(_commaIdx + 1).trim() : ""

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        StyledText {
            font.pixelSize: root.fontPx
            font.weight: Font.Medium
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.2
            color: root.colAccent
            text: root._day
        }

        StyledText {
            visible: root._date.length > 0
            font.pixelSize: root.fontPx
            font.weight: Font.Medium
            color: root.colAccent
            text: "·"
        }

        StyledText {
            visible: root._date.length > 0
            font.pixelSize: root.fontPx
            font.weight: Font.Medium
            color: root.colText
            text: root._date
        }
    }
}
