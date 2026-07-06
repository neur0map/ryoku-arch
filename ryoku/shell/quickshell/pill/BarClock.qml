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
    readonly property bool caelestia: Config.barStyle === "caelestia"
    readonly property var loc: Qt.locale("en_US")

    implicitWidth: caelestia ? (vertical ? cvcol.implicitWidth : chrow.implicitWidth)
                             : nstack.implicitWidth
    implicitHeight: caelestia ? (vertical ? cvcol.implicitHeight : chrow.implicitHeight)
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

    // ---- noctalia: stacked time over date, or one line on a thin band -------
    // the stacked readout needs room (noctalia runs a 34px bar); under 30 the
    // capsule would clip, so the readout folds to a single line.
    readonly property bool stacked: Config.barHeight >= 30

    Column {
        id: nstack
        visible: !clock.caelestia
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
