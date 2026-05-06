import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.bar
import qs.modules.bar.weather
import qs.services
import qs
import Quickshell
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

        // Clock + date column with hover popup (date / uptime / todos).
        MouseArea {
            id: clockArea
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: clockColumn.implicitWidth
            implicitHeight: clockColumn.implicitHeight
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            ColumnLayout {
                id: clockColumn
                anchors.centerIn: parent
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

            ClockWidgetTooltip {
                hoverTarget: clockArea
            }
        }

        // Weather icon with hover popup (full forecast) + click to refresh.
        MouseArea {
            id: weatherArea
            visible: root.showWeather
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: weatherIcon.implicitWidth
            implicitHeight: weatherIcon.implicitHeight
            hoverEnabled: true
            onPressed: {
                Weather.getData()
                Quickshell.execDetached(["/usr/bin/notify-send",
                    Translation.tr("Weather"),
                    Translation.tr("Refreshing (manually triggered)"),
                    "-a", "Shell"
                ])
            }

            MaterialSymbol {
                id: weatherIcon
                anchors.centerIn: parent
                fill: 0
                text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                iconSize: Appearance.font.pixelSize.large
                color: weatherArea.containsMouse
                    ? (Appearance.angelEverywhere ? Appearance.angel.colText
                        : Appearance.ryokuEverywhere ? Appearance.ryoku.colText
                        : Appearance.colors.colOnLayer1)
                    : root.colWeather
            }

            WeatherPopup {
                hoverTarget: weatherArea
            }
        }
    }
}
