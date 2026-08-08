pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import shell.services

// The clock menu: calendar above weather. Composes QsCalendarEmbed (the
// calendar grid) and MenuWeather in a vertical column, matching the original
// layout. MenuWidgetHost hosts this as the "clock" widget; the Calendar and
// Weather quick-settings tabs embed those components directly instead.
Item {
    id: root

    property real s: 1
    property bool open: false

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: root.width
        spacing: 10 * root.s

        QsCalendarEmbed {
            width: parent.width
            s: root.s
            open: root.open
        }

        Item { width: parent.width; height: 10 * root.s }

        MenuWeather {
            width: parent.width
            s: root.s
            open: root.open
        }
    }
}
