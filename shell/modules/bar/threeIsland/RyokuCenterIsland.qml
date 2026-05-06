import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.bar
import qs.services
import qs
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    readonly property bool showClock: Config.options?.bar?.modules?.kanjiClock ?? true
    readonly property bool showDate: Config.options?.bar?.modules?.dateLabel ?? true
    readonly property bool showWeather: (Config.options?.bar?.modules?.weatherIcon ?? true)
        && (Config.options?.bar?.weather?.enable ?? false)

    readonly property color colWeather: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.ryokuEverywhere ? Appearance.ryoku.colTextSecondary
        : Appearance.colors.colSubtext

    implicitWidth: row.implicitWidth + 16
    implicitHeight: Appearance.sizes.barHeight

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 0

            RyokuClock {
                visible: root.showClock
                Layout.alignment: Qt.AlignHCenter
            }

            RyokuDateLabel {
                compact: true
                visible: root.showDate
                Layout.alignment: Qt.AlignHCenter
            }
        }

        MaterialSymbol {
            visible: root.showWeather
            Layout.alignment: Qt.AlignVCenter
            fill: 0
            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
            iconSize: Appearance.font.pixelSize.large
            color: root.colWeather
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton

        ClockWidgetTooltip {
            hoverTarget: hoverArea
        }
    }
}
