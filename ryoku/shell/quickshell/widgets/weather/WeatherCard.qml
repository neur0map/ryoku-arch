pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

// card design: rounded "sky window" with the live animation, big temperature
// beside it, then either today's humidity + wind or the week ahead (by
// scope). the sky window's gradient shifts with day/night and the rough
// condition so the animation always reads against a fitting backdrop. the
// flagship weather look.
Item {
    id: card

    readonly property real s: Config.weatherScale
    readonly property color accent: Wallust.accent
    readonly property bool ok: WeatherData.available

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    function skyTop() {
        if (WeatherData.category === "storm") return "#3a4358";
        if (!WeatherData.isDay) return "#161c34";
        if (WeatherData.category === "rain") return "#5a6b86";
        return "#5b8fcf";
    }
    function skyBot() {
        if (WeatherData.category === "storm") return "#566179";
        if (!WeatherData.isDay) return "#2b3358";
        if (WeatherData.category === "rain") return "#8aa1be";
        return "#9cc3ea";
    }

    Column {
        id: col
        spacing: Math.round(16 * card.s)

        Row {
            id: header
            spacing: Math.round(18 * card.s)

            Rectangle {
                id: skyBox
                width: Math.round(120 * card.s)
                height: width
                radius: Math.round(22 * card.s)
                clip: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: card.skyTop() }
                    GradientStop { position: 1.0; color: card.skyBot() }
                }
                Sky {
                    anchors.fill: parent
                    category: WeatherData.category
                    isDay: WeatherData.isDay
                    animate: Config.weatherAnimate
                }
            }

            Column {
                anchors.verticalCenter: skyBox.verticalCenter
                spacing: Math.round(2 * card.s)

                Row {
                    spacing: Math.round(4 * card.s)
                    Text {
                        text: card.ok ? WeatherData.tempNow + "\u00b0" : "--\u00b0"
                        color: Theme.ink
                        font.family: Theme.mono
                        font.pixelSize: Math.round(62 * card.s)
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: Math.round(12 * card.s)
                        text: Config.weatherUnit
                        color: Theme.inkDim
                        font.family: Theme.mono
                        font.pixelSize: Math.round(24 * card.s)
                        font.weight: Font.DemiBold
                    }
                }
                Text {
                    text: card.ok ? WeatherData.condition : "Loading"
                    color: card.accent
                    font.family: Theme.font
                    font.pixelSize: Math.round(21 * card.s)
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: WeatherData.city.length > 0
                    text: WeatherData.city
                    color: Theme.inkDim
                    font.family: Theme.font
                    font.pixelSize: Math.round(15 * card.s)
                    font.weight: Font.Medium
                }
            }
        }

        Loader {
            sourceComponent: Config.weatherScope === "week" ? weekRow : todayRow
        }
    }

    component Stat: Column {
        property string label: ""
        property string value: ""
        spacing: Math.round(2 * card.s)
        Text {
            text: parent.value
            color: Theme.ink
            font.family: Theme.mono
            font.pixelSize: Math.round(20 * card.s)
            font.weight: Font.DemiBold
        }
        Text {
            text: parent.label
            color: Theme.inkDim
            font.family: Theme.font
            font.pixelSize: Math.round(13 * card.s)
            font.weight: Font.Medium
            font.letterSpacing: 1
        }
    }

    Component {
        id: todayRow
        Row {
            spacing: Math.round(28 * card.s)
            Stat { label: "HUMIDITY"; value: card.ok ? WeatherData.humidity + "%" : "--" }
            Stat { label: "WIND"; value: card.ok ? WeatherData.wind + " km/h" : "--" }
        }
    }

    Component {
        id: weekRow
        Row {
            spacing: Math.round(18 * card.s)
            Repeater {
                model: Math.min(6, WeatherData.daily.length)
                DayCell {
                    required property int index
                    readonly property var d: WeatherData.daily[index]
                    s: card.s
                    accent: card.accent
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
