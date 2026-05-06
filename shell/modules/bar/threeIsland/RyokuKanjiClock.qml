import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Center-island clock for the Three-Island topbar. Time only, displayed in
 * Roman numerals (readable, stylish) by default. Optional kanji-digit mode.
 * (Filename retained for compatibility with the existing config schema
 * `bar.kanjiClock.*`.)
 */
Item {
    id: root

    readonly property bool useKanjiDigits: Config.options?.bar?.kanjiClock?.useKanjiDigits ?? false

    readonly property var _kanji: ["〇","一","二","三","四","五","六","七","八","九"]

    function _toRoman(n: int): string {
        if (n === 0) return "·"
        const map = [
            [1000, "M"], [900, "CM"], [500, "D"], [400, "CD"],
            [100, "C"], [90, "XC"], [50, "L"], [40, "XL"],
            [10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]
        ]
        let r = ""
        for (let i = 0; i < map.length; i++) {
            while (n >= map[i][0]) {
                r += map[i][1]
                n -= map[i][0]
            }
        }
        return r
    }

    function _toKanji(s: string): string {
        let out = ""
        for (let i = 0; i < s.length; i++) {
            const c = s[i]
            if (c >= "0" && c <= "9") out += root._kanji[parseInt(c, 10)]
            else out += c
        }
        return out
    }

    readonly property string _time: DateTime.time
    readonly property int _colonIdx: _time.indexOf(":")
    readonly property int _hourNum: _colonIdx >= 0 ? parseInt(_time.substring(0, _colonIdx), 10) : 0
    readonly property int _minuteNum: _colonIdx >= 0 ? parseInt(_time.substring(_colonIdx + 1), 10) : 0

    readonly property string _hh: useKanjiDigits
        ? _toKanji(_colonIdx >= 0 ? _time.substring(0, _colonIdx) : _time)
        : _toRoman(_hourNum)
    readonly property string _mm: useKanjiDigits
        ? _toKanji(_colonIdx >= 0 ? _time.substring(_colonIdx + 1) : "")
        : _toRoman(_minuteNum)

    readonly property color colTime: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colText
        : Appearance.colors.colOnLayer1
    readonly property color colAccent: Appearance.angelEverywhere ? Appearance.angel.colAccent
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colAccent
        : Appearance.colors.colPrimary

    implicitWidth: row.implicitWidth + 12
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2

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
            text: ":"
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
}
