import QtQuick
import Quickshell
import "Singletons"

Item {
    id: clock

    property real s: 1
    property var barWindow

    readonly property var deLocale: Qt.locale("de_DE")

    implicitWidth: layout.implicitWidth
    implicitHeight: parent ? parent.height : 34 * s

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 9 * clock.s

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(sysClock.date, "HH:mm")
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 13 * clock.s
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 13 * clock.s
            color: Theme.hair
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: sysClock.date.toLocaleDateString(clock.deLocale, "ddd dd MMM").toUpperCase()
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 10 * clock.s
            font.weight: Font.Medium
            font.letterSpacing: 1.2 * clock.s
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: calendar.open = !calendar.open
    }

    Calendar {
        id: calendar
        s: clock.s
        anchorWindow: clock.barWindow
    }
}
