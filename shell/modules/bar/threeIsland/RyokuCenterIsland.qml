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

    // The frame's centerNotchWidth adds another +16, so the visible padding
    // around the centered stack ends up at ~24px each side.
    implicitWidth: stack.implicitWidth + 32
    implicitHeight: Appearance.sizes.barHeight

    // Outer ColumnLayout — top row (clock + weather) and the date label are
    // siblings, each independently horizontally centered. This keeps the date
    // centered in the island regardless of the weather icon's width, instead
    // of inheriting the clock column's left-skewed position.
    ColumnLayout {
        id: stack
        anchors.centerIn: parent
        spacing: 0

        RowLayout {
            id: topRow
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            // Clock with hover popup (date / uptime / todos).
            MouseArea {
                id: clockArea
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: clockMain.implicitWidth
                implicitHeight: clockMain.implicitHeight
                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                RyokuClock {
                    id: clockMain
                    visible: root.showClock
                    anchors.centerIn: parent
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

        RyokuDateLabel {
            compact: true
            visible: root.showDate
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
