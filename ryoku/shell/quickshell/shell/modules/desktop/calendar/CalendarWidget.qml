pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import shell.services
import "../../../services/lib/calendar.js" as CalendarModel
import ".."
import "../Singletons"

Item {
    id: root

    property string style: "glass"
    property int weeks: 6
    property bool showWeekNumbers: true
    property string holidayRegion: ""
    property bool active: true
    property real s: 1
    property real underL: Scheme.wallLstar
    property Item wallpaperSource: null
    property rect wallpaperRect: Qt.rect(0, 0, 0, 0)

    readonly property bool paper: root.style === "paper"
    readonly property var loc: Qt.locale()
    readonly property int firstDay: root.loc.firstDayOfWeek === 7 ? 0 : root.loc.firstDayOfWeek
    readonly property date today: systemClock.date
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    readonly property int visibleWeeks: root.days.length / 7
    property string selectedKey: CalendarModel.dateKey(today.getFullYear(), today.getMonth(), today.getDate())
    property string hoveredKey: ""
    readonly property string activeKey: root.hoveredKey.length > 0 ? root.hoveredKey : root.selectedKey
    readonly property var days: CalendarModel.buildRange(today, viewYear, viewMonth, weeks, firstDay)
    readonly property var years: {
        const result = [];
        for (const day of root.days)
            if (result.indexOf(day.year) < 0) result.push(day.year);
        return result;
    }
    readonly property var selectedHolidays: Holidays.forDate(root.activeKey)
    readonly property var selectedEvents: Events.forDate(root.activeKey)
    readonly property string selectedDateLabel: {
        const parts = root.activeKey.split("-");
        if (parts.length !== 3) return "";
        const date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
        return root.loc.toString(date, "dddd, MMMM d, yyyy");
    }
    readonly property var currentWeek: CalendarModel.isoWeek(root.today)

    implicitWidth: grid.implicitWidth + 40 * root.s
    implicitHeight: header.height + grid.implicitHeight + details.implicitHeight + 32 * root.s

    onHolidayRegionChanged: Holidays.configure(root.holidayRegion, root.years)
    onYearsChanged: Holidays.configure(root.holidayRegion, root.years)
    Component.onCompleted: Holidays.configure(root.holidayRegion, root.years)

    function shift(delta) {
        if (delta === 0) {
            root.viewYear = root.today.getFullYear();
            root.viewMonth = root.today.getMonth();
            root.selectedKey = CalendarModel.dateKey(root.today.getFullYear(), root.today.getMonth(), root.today.getDate());
        } else {
            const next = CalendarModel.shiftMonth(root.viewYear, root.viewMonth, delta);
            root.viewYear = next.year;
            root.viewMonth = next.month;
        }
        reveal.restart();
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
        enabled: root.active
        onDateChanged: if (root.active) sweep.restart()
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.paper ? paperBackground : glassBackground
    }
    Component {
        id: glassBackground
        WidgetGlass {
            hovered: hover.hovered
            s: root.s
            sourceItem: root.wallpaperSource
            sourceRect: root.wallpaperRect
        }
    }
    Component { id: paperBackground; CalendarPaper { hovered: hover.hovered; s: root.s } }

    HoverHandler { id: hover }

    Item {
        id: header
        x: 20 * root.s
        y: 14 * root.s
        width: parent.width - 40 * root.s
        height: 42 * root.s

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * root.s
            Text {
                text: root.loc.standaloneMonthName(root.viewMonth, Locale.LongFormat) + " " + root.viewYear
                color: Theme.ink
                font.family: Theme.display
                font.pixelSize: 23 * root.s
                font.weight: Font.Medium
            }
            Text {
                text: qsTr("WEEK %1 · %2 WEEKS").arg(root.currentWeek.week).arg(root.visibleWeeks)
                color: Theme.faint
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
                font.letterSpacing: 1.1 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5 * root.s
            Repeater {
                model: [
                    { label: "‹", name: qsTr("Previous month"), delta: -1 },
                    { label: qsTr("Today"), name: qsTr("Return to today"), delta: 0 },
                    { label: "›", name: qsTr("Next month"), delta: 1 }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: modelData.delta === 0 ? 48 * root.s : 28 * root.s
                    height: 28 * root.s
                    radius: Theme.radiusTile * root.s
                    color: navHover.hovered || activeFocus ? (root.paper ? Theme.ink : Theme.tileHover) : "transparent"
                    border.width: activeFocus ? 1 : 0
                    border.color: Theme.accent
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: root.paper && (navHover.hovered || parent.activeFocus) ? Theme.surface : Theme.ink
                        font.family: Theme.font
                        font.pixelSize: modelData.delta === 0 ? 10 * root.s : 18 * root.s
                        font.weight: Font.Medium
                    }
                    HoverHandler { id: navHover }
                    TapHandler { onTapped: root.shift(modelData.delta) }
                    Keys.onReturnPressed: root.shift(modelData.delta)
                    Keys.onSpacePressed: root.shift(modelData.delta)
                }
            }
        }
    }

    CalendarGrid {
        id: grid
        x: 20 * root.s
        y: header.y + header.height + 8 * root.s
        days: root.days
        weeks: root.visibleWeeks
        firstDay: root.firstDay
        showWeekNumbers: root.showWeekNumbers
        paper: root.paper
        selectedKey: root.activeKey
        s: root.s
        holidayForDate: function(key) { return Holidays.forDate(key); }
        eventForDate: function(key) { return Events.forDate(key); }
        onSelected: key => root.selectedKey = key
        onDayHoverChanged: (key, inside) => {
            if (inside)
                root.hoveredKey = key;
            else if (root.hoveredKey === key)
                root.hoveredKey = "";
        }
    }

    CalendarDetails {
        id: details
        x: 20 * root.s
        y: grid.y + grid.implicitHeight + 8 * root.s
        width: parent.width - 40 * root.s
        dateLabel: root.selectedDateLabel
        holidays: root.selectedHolidays
        events: root.selectedEvents
        paper: root.paper
        s: root.s
    }

    NumberAnimation {
        id: reveal
        target: grid
        property: "opacity"
        from: 0
        to: 1
        duration: Theme.medium
        easing.type: Theme.ease
    }

    SequentialAnimation {
        id: sweep
        running: false
        NumberAnimation { target: grid; property: "pulse"; from: 0; to: 1; duration: Theme.medium; easing.type: Theme.ease }
        NumberAnimation { target: grid; property: "pulse"; from: 1; to: 0; duration: Theme.medium; easing.type: Easing.InOutCubic }
    }
}
