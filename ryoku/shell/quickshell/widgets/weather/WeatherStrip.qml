pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

// strip design: current conditions on the left, a hairline, then the week
// ahead as a row of day cells. built for the forecast. in today-scope the
// right side becomes humidity + wind instead of the week.
Item {
    id: strip

    readonly property real s: Config.weatherScale
    readonly property color accent: Wallust.accent
    readonly property bool ok: WeatherData.available

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: Math.round(20 * strip.s)

        Column {
            id: current
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(4 * strip.s)

            Item {
                width: Math.round(70 * strip.s)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                Sky {
                    anchors.fill: parent
                    category: WeatherData.category
                    isDay: WeatherData.isDay
                    animate: Config.weatherAnimate
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(2 * strip.s)
                Text {
                    text: strip.ok ? WeatherData.tempNow + "\u00b0" : "--\u00b0"
                    color: Theme.ink
                    font.family: Theme.mono
                    font.pixelSize: Math.round(40 * strip.s)
                    font.weight: Font.Bold
                }
                Text {
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(6 * strip.s)
                    text: Config.weatherUnit
                    color: Theme.inkDim
                    font.family: Theme.mono
                    font.pixelSize: Math.round(16 * strip.s)
                    font.weight: Font.DemiBold
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: strip.ok ? WeatherData.condition : "Loading"
                color: strip.accent
                font.family: Theme.font
                font.pixelSize: Math.round(15 * strip.s)
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: parent.height * 0.7
            color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.14)
        }

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: Config.weatherScope === "today" ? todayCol : weekCells
        }
    }

    component Stat: Column {
        property string label: ""
        property string value: ""
        spacing: Math.round(2 * strip.s)
        Text {
            text: parent.value
            color: Theme.ink
            font.family: Theme.mono
            font.pixelSize: Math.round(22 * strip.s)
            font.weight: Font.DemiBold
        }
        Text {
            text: parent.label
            color: Theme.inkDim
            font.family: Theme.font
            font.pixelSize: Math.round(13 * strip.s)
            font.weight: Font.Medium
            font.letterSpacing: 1
        }
    }

    Component {
        id: todayCol
        Row {
            spacing: Math.round(26 * strip.s)
            Stat { label: "HUMIDITY"; value: strip.ok ? WeatherData.humidity + "%" : "--" }
            Stat { label: "WIND"; value: strip.ok ? WeatherData.wind + " km/h" : "--" }
        }
    }

    Component {
        id: weekCells
        Row {
            spacing: Math.round(18 * strip.s)
            Repeater {
                model: Math.min(6, WeatherData.daily.length)
                DayCell {
                    required property int index
                    readonly property var d: WeatherData.daily[index]
                    s: strip.s
                    accent: strip.accent
                    highlight: index === 0
                    day: d.day
                    category: d.category
                    hi: d.hi
                    lo: d.lo
                }
            }
        }
    }
}
