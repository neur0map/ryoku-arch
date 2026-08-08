pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services

// The quick-settings clock entry (contract 06 sec 2.5): a big bold weekday on
// the left, with a stacked date and time taking the rest of the row. Rendered at
// fixed reference pixels like the rest of the quick-settings stack; 24h format
// follows the Ryoku shell-wide convention (the reference default is 12h,
// recorded as a minor divergence). The calendar/weather clock MENU is separate
// (MenuClock.qml); this card lives only inside the quick-settings stack.
Item {
    id: root

    property real s: 1
    property bool open: false

    readonly property var loc: Qt.locale()

    implicitHeight: row.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.open
    }

    Row {
        id: row
        width: root.width
        spacing: 20

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 12
            text: root.loc.toString(clock.date, "dddd")
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontXxl
            font.weight: Font.Bold
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
                text: Qt.formatDate(clock.date, "M/dd/yyyy")
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontMd
                font.weight: Font.Bold
            }
            Text {
                text: Qt.formatTime(clock.date, "HH:mm")
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
            }
        }
    }
}
