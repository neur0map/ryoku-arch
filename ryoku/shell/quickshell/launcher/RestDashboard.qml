import QtQuick
import Quickshell
import "Singletons"

// Zero-query home card, one filled Squircle framed by concentric corners. Left
// column reads the clock (mono HH, vermilion colon, mono mm) over a greeting so
// the user's own time reads first. Right column carries the weather glance when
// resolved: a vector glyph next to the big temperature on top, condition and
// city under it, today hi and lo arrows next to the mixed-case date at the base
// so the card carries real weather info instead of one bare number. Falls back
// to a clean date-only readout while Weather is still fetching, so the right
// column is never dead space. Corner radius steps one inside the window so the
// nested corners read concentric. No accent bar.
Item {
    id: root

    property real s: 1
    implicitHeight: 92 * s

    readonly property var now: clock.date
    readonly property string hh: Qt.formatTime(now, "HH")
    readonly property string mm: Qt.formatTime(now, "mm")
    readonly property string date: Qt.locale("en_US").toString(now, "dddd, MMM d")
    readonly property string greeting: {
        var h = now.getHours();
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
    }
    readonly property bool wxReady: Weather.available
    readonly property bool hasDaily: Weather.daily.length > 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Squircle {
        anchors.fill: parent
        radius: Metrics.radiusCard
        power: 4
        color: Theme.frameBg
        borderColor: Theme.hair
        borderWidth: 1

        // left: clock over greeting.
        Column {
            anchors.left: parent.left
            anchors.leftMargin: Metrics.padOuter * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * root.s

            Row {
                spacing: 0
                Text {
                    text: root.hh
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 34 * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
                Text {
                    text: ":"
                    color: Theme.verm
                    font.family: Theme.mono
                    font.pixelSize: 34 * root.s
                    font.weight: Font.Medium
                }
                Text {
                    text: root.mm
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 34 * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }
            Text {
                text: root.greeting
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: Metrics.fontSubtitle * root.s
            }
        }

        // right: weather glance when resolved, date-only fallback while it is
        // still fetching so the column never reads as dead space.
        Column {
            id: wxCol
            anchors.right: parent.right
            anchors.rightMargin: Metrics.padOuter * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * root.s

            // headline: icon + temperature, matched in weight to the left clock.
            Row {
                anchors.right: parent.right
                spacing: 6 * root.s
                visible: root.wxReady

                WeatherGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22 * root.s
                    height: 22 * root.s
                    name: Weather.glyph
                    color: Theme.cream
                    stroke: 1.7
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.temp
                    color: Theme.bright
                    font.family: Theme.font
                    font.pixelSize: 22 * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }

            // fallback headline while weather has not resolved yet. Uses the
            // same visual slot as the temperature so the layout does not jump
            // once data arrives.
            Text {
                anchors.right: parent.right
                visible: !root.wxReady
                text: root.date
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 22 * root.s
                font.weight: Font.Medium
            }

            Text {
                anchors.right: parent.right
                visible: root.wxReady
                text: Weather.condition + (Weather.city.length ? "  \u00b7  " + Weather.city : "")
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: Metrics.fontSubtitle * root.s
            }

            // base line: today hi and lo arrows next to the date. Arrows match
            // the pill's Calendar footer so the two shells read the same when
            // weather is present. When wxReady is true but daily is empty
            // (Open-Meteo occasionally omits it) we still show the date.
            Row {
                anchors.right: parent.right
                spacing: 6 * root.s
                visible: root.wxReady

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasDaily
                    text: root.hasDaily
                        ? "\u2191" + Weather.daily[0].hi + "\u00b0  \u2193" + Weather.daily[0].lo + "\u00b0"
                        : ""
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: Metrics.fontEyebrow * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.hasDaily
                    text: "\u00b7"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: Metrics.fontEyebrow * root.s
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.date
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: Metrics.fontEyebrow * root.s
                }
            }
        }
    }
}
