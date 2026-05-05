import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool showDate: Config.options?.bar?.kanjiClock?.showDate ?? true
    readonly property bool useKanjiDigits: Config.options?.bar?.kanjiClock?.useKanjiDigits ?? true

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

    implicitWidth: rowLayout.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 6

        StyledText {
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.angelEverywhere ? Appearance.angel.colText
                : Appearance.ryokuEverywhere ? Appearance.ryoku.colText
                : Appearance.colors.colOnLayer1
            text: root._toDigits(DateTime.time)
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
                : Appearance.ryokuEverywhere ? Appearance.ryoku.colText
                : Appearance.colors.colOnLayer1
            text: root._toDigits(DateTime.shortDate)
        }
    }
}
