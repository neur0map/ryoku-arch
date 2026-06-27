pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

// minimal = small live sky + temp + condition, nothing else. for a quiet
// corner of the desktop. in week scope a four-day strip tucks underneath.
Item {
    id: m

    readonly property real s: Config.weatherScale
    readonly property color accent: Wallust.accent
    readonly property bool ok: WeatherData.available

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: Math.round(14 * m.s)

        Row {
            spacing: Math.round(14 * m.s)

            Item {
                width: Math.round(84 * m.s)
                height: width
                anchors.verticalCenter: info.verticalCenter
                Sky {
                    anchors.fill: parent
                    category: WeatherData.category
                    isDay: WeatherData.isDay
                    animate: Config.weatherAnimate
                }
            }

            Column {
                id: info
                spacing: Math.round(2 * m.s)

                Row {
                    spacing: Math.round(3 * m.s)
                    Text {
                        text: m.ok ? WeatherData.tempNow + "\u00b0" : "--\u00b0"
                        color: Theme.ink
                        font.family: Theme.mono
                        font.pixelSize: Math.round(52 * m.s)
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: Math.round(10 * m.s)
                        text: Config.weatherUnit
                        color: Theme.inkDim
                        font.family: Theme.mono
                        font.pixelSize: Math.round(20 * m.s)
                        font.weight: Font.DemiBold
                    }
                }
                Text {
                    text: m.ok ? WeatherData.condition : "Loading"
                    color: m.accent
                    font.family: Theme.font
                    font.pixelSize: Math.round(18 * m.s)
                    font.weight: Font.DemiBold
                }
            }
        }

        Row {
            visible: Config.weatherScope === "week"
            spacing: Math.round(16 * m.s)
            Repeater {
                model: Config.weatherScope === "week" ? Math.min(4, Math.max(0, WeatherData.daily.length - 1)) : 0
                DayCell {
                    required property int index
                    readonly property var d: WeatherData.daily[index + 1]
                    s: m.s * 0.66
                    accent: m.accent
                    day: d.day
                    category: d.category
                    hi: d.hi
                    lo: d.lo
                }
            }
        }
    }
}
