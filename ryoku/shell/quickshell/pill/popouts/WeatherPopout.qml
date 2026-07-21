pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../Singletons"
import "../lib/weather.js" as WX

// weather popout content: the current reading as a hero, a short hourly strip,
// then the daily forecast, drawn straight from the Weather singleton. a bare,
// transparent Item -- the Popout blob behind it IS the surface; this panel only
// reports its implicit size so the popout melts open to fit. pointer-driven.
Item {
    id: root

    property real s: 1
    property bool open: false

    anchors.fill: parent

    implicitWidth: 300 * s
    implicitHeight: body.implicitHeight + 27 * s

    // WMO code -> shell weather glyph -> Material Symbol, reusing the tested map.
    readonly property var symFor: ({
        "sun": "clear_day", "cloud": "cloud", "fog": "foggy",
        "rain": "rainy", "snow": "weather_snowy", "storm": "thunderstorm"
    })
    function codeSym(code) { return root.symFor[WX.glyphFor(code)] || "cloud"; }

    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 13 * root.s
        anchors.leftMargin: 16 * root.s
        anchors.rightMargin: 16 * root.s
        spacing: 12 * root.s

        // header: condition glyph + WEATHER eyebrow, the city on the right.
        Item {
            width: parent.width
            height: hdr.implicitHeight

            Row {
                id: hdr
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.s
                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.symFor[Weather.glyph] || "cloud"
                    fill: 1
                    color: Theme.brand
                    font.pixelSize: 16 * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WEATHER"
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 10 * root.s
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6 * root.s
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.city
                elide: Text.ElideRight
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.2 * root.s
            }
        }

        // hero: temperature as the figure, condition on its baseline.
        Item {
            width: parent.width
            height: tempText.implicitHeight

            Text {
                id: tempText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.temp
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 26 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: -0.5 * root.s
                font.features: ({ "tnum": 1 })
            }
            Text {
                anchors.right: parent.right
                anchors.baseline: tempText.baseline
                text: Weather.condition + (Weather.humidity > 0 ? "  \u00b7  " + Weather.humidity + "%" : "")
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
            }
        }

        // hourly strip: the next hours as hour / glyph / temp columns.
        Rectangle { width: parent.width; height: 1; color: Theme.hair; visible: hourRow.count > 0 }
        Row {
            id: hourRow
            width: parent.width
            readonly property int count: Math.min(7, Weather.hourly.length)
            visible: count > 0
            Repeater {
                model: hourRow.count
                delegate: Column {
                    id: hourCol
                    required property int index
                    readonly property var h: Weather.hourly[hourCol.index]
                    width: hourRow.width / hourRow.count
                    spacing: 4 * root.s
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: hourCol.h.hour
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 8.5 * root.s
                        font.features: ({ "tnum": 1 })
                    }
                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.codeSym(hourCol.h.code)
                        fill: 1
                        color: Theme.subtle
                        font.pixelSize: 13 * root.s
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: hourCol.h.temp + "\u00b0"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }

        // daily forecast: day / glyph / hi-lo rows.
        Rectangle { width: parent.width; height: 1; color: Theme.hair; visible: dayCol.count > 0 }
        Column {
            id: dayCol
            width: parent.width
            spacing: 8 * root.s
            readonly property int count: Math.min(5, Weather.daily.length)
            visible: count > 0
            Repeater {
                model: dayCol.count
                delegate: Item {
                    id: dayRow
                    required property int index
                    readonly property var d: Weather.daily[dayRow.index]
                    width: parent.width
                    height: 15 * root.s
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: dayRow.d.day
                        color: Theme.subtle
                        font.family: Theme.mono
                        font.pixelSize: 9.5 * root.s
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1 * root.s
                    }
                    MaterialIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.codeSym(dayRow.d.code)
                        fill: 1
                        color: Theme.subtle
                        font.pixelSize: 13 * root.s
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: dayRow.d.hi + "\u00b0 / " + dayRow.d.lo + "\u00b0"
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                        font.weight: Font.Medium
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }
    }
}
