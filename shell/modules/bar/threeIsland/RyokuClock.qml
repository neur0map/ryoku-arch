import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Center-island clock for the Three-Island topbar. Time only, plain digits
 * (1234567890) by default; kanji digits (〇一二三...) opt-in.
 * Filename retained for compatibility with the config schema `bar.kanjiClock.*`.
 */
Item {
    id: root

    readonly property bool useKanjiDigits: Config.options?.bar?.kanjiClock?.useKanjiDigits ?? false

    readonly property var _kanji: ["〇","一","二","三","四","五","六","七","八","九"]

    function _kanjify(s: string): string {
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
    readonly property string _rendered: useKanjiDigits ? _kanjify(_time) : _time
    readonly property string _hh: _colonIdx >= 0 ? _rendered.substring(0, _colonIdx) : _rendered
    readonly property string _mm: _colonIdx >= 0 ? _rendered.substring(_colonIdx + 1) : ""

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
