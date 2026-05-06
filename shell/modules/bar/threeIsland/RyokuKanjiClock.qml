import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Center-island clock for the Three-Island topbar. Stacked time + date,
 * accent-colored colon, optional kanji digits.
 * (Filename retained for compatibility with the existing config schema
 * `bar.kanjiClock.*`; the kanji-digit mode is now opt-in.)
 */
Item {
    id: root

    readonly property bool showDate: Config.options?.bar?.kanjiClock?.showDate ?? true
    readonly property bool useKanjiDigits: Config.options?.bar?.kanjiClock?.useKanjiDigits ?? false

    readonly property var _digits: useKanjiDigits
        ? ["〇","一","二","三","四","五","六","七","八","九"]
        : ["0","1","2","3","4","5","6","7","8","9"]

    function _toDigits(s: string): string {
        let out = "";
        for (let i = 0; i < s.length; i++) {
            const c = s[i];
            if (c >= "0" && c <= "9") out += root._digits[parseInt(c, 10)];
            else out += c;
        }
        return out;
    }

    readonly property color colTime: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colText
        : Appearance.colors.colOnLayer1
    readonly property color colDate: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color colAccent: Appearance.angelEverywhere ? Appearance.angel.colAccent
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colAccent
        : Appearance.colors.colPrimary

    readonly property string _time: root._toDigits(DateTime.time)
    readonly property int _colonIdx: _time.indexOf(":")
    readonly property string _hh: _colonIdx >= 0 ? _time.substring(0, _colonIdx) : _time
    readonly property string _mm: _colonIdx >= 0 ? _time.substring(_colonIdx + 1) : ""

    implicitWidth: column.implicitWidth + 12
    implicitHeight: Appearance.sizes.barHeight

    ColumnLayout {
        id: column
        anchors.centerIn: parent
        spacing: 0

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 0

            StyledText {
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Medium
                color: root.colTime
                text: root._hh
            }
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Medium
                color: root.colAccent
                text: root._colonIdx >= 0 ? ":" : ""
                visible: root._colonIdx >= 0
            }
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Medium
                color: root.colTime
                text: root._mm
                visible: root._mm.length > 0
            }
        }

        StyledText {
            visible: root.showDate
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: root.colDate
            text: root._toDigits(DateTime.date)
        }
    }
}
