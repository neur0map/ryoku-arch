import QtQuick
import Quickshell
import "Singletons"

// clock module content, per reference dialect.
//   caelestia = a calendar glyph in the accent beside the time (their clock
//               module row); vertical stacks glyph, hour, minute.
//   noctalia  = the stacked readout: time at full size over the date at 62%,
//               both centred (their kStackedPrimary/SecondaryScale).
Item {
    id: clock

    property real s: 1
    property bool vertical: false
    readonly property string style: Config.barStyle
    readonly property bool caelestia: style === "caelestia"
    readonly property bool aegis: style === "aegis"
    readonly property bool stele: style === "stele"
    readonly property var loc: Qt.locale("en_US")

    implicitWidth: caelestia ? (vertical ? cvcol.implicitWidth : chrow.implicitWidth)
        : aegis ? aerow.implicitWidth
        : stele ? strow.implicitWidth
        : nstack.implicitWidth
    implicitHeight: caelestia ? (vertical ? cvcol.implicitHeight : chrow.implicitHeight)
        : aegis ? aerow.implicitHeight
        : stele ? strow.implicitHeight
        : nstack.implicitHeight

    SystemClock {
        id: sys
        precision: SystemClock.Minutes
    }

    // ---- caelestia: glyph + time ------------------------------------------
    Row {
        id: chrow
        visible: clock.caelestia && !clock.vertical
        spacing: 6 * clock.s

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: "calendar_month"
            color: Theme.verm
            font.pixelSize: 14 * clock.s
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(sys.date, "HH:mm")
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * clock.s
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }
    }

    Column {
        id: cvcol
        visible: clock.caelestia && clock.vertical
        spacing: 2 * clock.s

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "calendar_month"
            color: Theme.verm
            font.pixelSize: 13 * clock.s
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(sys.date, "HH")
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * clock.s
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(sys.date, "mm")
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * clock.s
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }
    }

    // aegis: an accent tick, then mono time and a dim uppercase date kicker.
    Row {
        id: aerow
        visible: clock.aegis && !clock.vertical
        spacing: 7 * clock.s

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, clock.s)
            height: 12 * clock.s
            color: Theme.verm
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(sys.date, "HH:mm")
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: 12 * clock.s
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: clock.loc.toString(sys.date, "ddd d MMM").toUpperCase()
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 9.5 * clock.s
            font.weight: Font.Medium
            font.letterSpacing: 1.5
        }
    }

    // stele: mono time, an engraved hairline divider, a wide-tracked date.
    Row {
        id: strow
        visible: clock.stele && !clock.vertical
        spacing: 8 * clock.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(sys.date, "HH:mm")
            color: Theme.cream
            font.family: Theme.mono
            font.pixelSize: 12 * clock.s
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
            font.letterSpacing: 1
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(1, clock.s)
            height: 11 * clock.s
            color: Theme.line
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: clock.loc.toString(sys.date, "ddd dd MMM").toUpperCase()
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 9 * clock.s
            font.weight: Font.Medium
            font.letterSpacing: 2.5
        }
    }

    // ---- noctalia: stacked time over date, or one line on a thin band -------
    // the stacked readout needs room (noctalia runs a 34px bar); under 30 the
    // capsule would clip, so the readout folds to a single line.
    readonly property bool stacked: Config.barHeight >= 30

    Column {
        id: nstack
        visible: !clock.caelestia && !clock.aegis && !clock.stele
        spacing: 0

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !clock.vertical && !clock.stacked
            spacing: 6 * clock.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatTime(sys.date, "HH:mm")
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 11.5 * clock.s
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: clock.loc.toString(sys.date, "ddd d MMM")
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 11.5 * 0.72 * clock.s
                font.weight: Font.Medium
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !clock.vertical && clock.stacked
            text: Qt.formatTime(sys.date, "HH:mm")
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 12 * clock.s
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !clock.vertical && clock.stacked
            text: clock.loc.toString(sys.date, "ddd d MMM")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 12 * 0.62 * clock.s
            font.weight: Font.Medium
        }
        // vertical: hour over minute, date has no room sideways.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: clock.vertical
            text: Qt.formatTime(sys.date, "HH")
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 11 * clock.s
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: clock.vertical
            text: Qt.formatTime(sys.date, "mm")
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 11 * clock.s
            font.weight: Font.Medium
            font.features: ({ "tnum": 1 })
        }
    }
}
