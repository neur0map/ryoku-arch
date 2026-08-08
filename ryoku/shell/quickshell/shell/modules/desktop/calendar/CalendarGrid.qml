pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

Item {
    id: root

    property var days: []
    property int weeks: 6
    property int firstDay: 1
    property bool showWeekNumbers: true
    property bool paper: false
    property string selectedKey: ""
    property real s: 1
    property real pulse: 0
    property var holidayForDate: function(key) { return []; }
    property var eventForDate: function(key) { return []; }
    signal selected(string key)
    signal dayHoverChanged(string key, bool inside)

    readonly property real weekWidth: root.showWeekNumbers ? 28 * root.s : 0
    readonly property real cellWidth: 40 * root.s
    readonly property real cellHeight: 34 * root.s
    readonly property real headerHeight: 22 * root.s
    implicitWidth: root.weekWidth + root.cellWidth * 7
    implicitHeight: root.headerHeight + root.cellHeight * root.weeks

    Row {
        x: root.weekWidth
        y: 0
        Repeater {
            model: 7
            delegate: Item {
                required property int index
                width: root.cellWidth
                height: root.headerHeight
                Text {
                    anchors.centerIn: parent
                    text: Qt.locale().standaloneDayName((index + root.firstDay) % 7, Locale.NarrowFormat)
                    color: Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.letterSpacing: 1 * root.s
                }
            }
        }
    }

    Repeater {
        model: root.weeks
        delegate: Rectangle {
            required property int index
            x: root.weekWidth
            y: root.headerHeight + index * root.cellHeight
            width: root.cellWidth * 7
            height: root.cellHeight
            radius: Theme.radiusTile * root.s
            color: {
                const day = root.days[index * 7];
                const current = day && root.days.some(function(candidate) { return candidate.row === index && candidate.today; });
                if (!current) return "transparent";
                const alpha = 0.035 + root.pulse * 0.055;
                return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, alpha);
            }
        }
    }

    Repeater {
        model: root.showWeekNumbers ? root.weeks : 0
        delegate: Item {
            required property int index
            x: 0
            y: root.headerHeight + index * root.cellHeight
            width: root.weekWidth
            height: root.cellHeight
            Text {
                anchors.centerIn: parent
                text: {
                    const day = root.days[index * 7];
                    return day ? String(day.isoWeek).padStart(2, "0") : "";
                }
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
            }
        }
    }

    Repeater {
        model: root.days
        delegate: CalendarDay {
            required property var modelData
            day: modelData
            x: root.weekWidth + modelData.column * root.cellWidth
            y: root.headerHeight + modelData.row * root.cellHeight
            width: root.cellWidth
            height: root.cellHeight
            holidays: root.holidayForDate(modelData.key)
            events: root.eventForDate(modelData.key)
            paper: root.paper
            selected: root.selectedKey === modelData.key
            s: root.s
            onActivated: key => root.selected(key)
            onHoverChanged: (key, inside) => root.dayHoverChanged(key, inside)
        }
    }
}
