pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "Singletons"

/**
 * Calendar surface content: header with month/year label and prev/next nav,
 * weekday headers and a day grid sized to exactly the rows the month needs.
 * Today gets a warm frame; weekend columns are dimmed and the leading/trailing
 * cells ghost the neighbouring months' day numbers. View date resets to the
 * real "today" (via SystemClock) every time the surface opens. implicitHeight
 * lets the pill shrink to the live row count, and todayX/todayY/todayVisible
 * expose today's cell centre for the flame lap.
 */
PillSurface {
    id: root

    mTop: 16
    mLeft: 18
    mRight: 18
    mBottom: 16

    readonly property var loc: Qt.locale("en_US")

    readonly property date today: sysClock.date
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

    readonly property int offset: firstWeekdayOffset(viewYear, viewMonth)
    readonly property int monthLen: daysInMonth(viewYear, viewMonth)
    readonly property int rows: Math.ceil((offset + monthLen) / 7)

    readonly property real cellH: 24 * s
    readonly property real rowGap: 2 * s

    implicitHeight: grid.y + rows * cellH + (rows - 1) * rowGap

    readonly property bool todayVisible: viewMonth === today.getMonth()
        && viewYear === today.getFullYear()
    readonly property int todayIndex: offset + today.getDate() - 1
    readonly property real cellW: grid.width / 7
    readonly property real todayX: grid.x + (todayIndex % 7 + 0.5) * cellW
    readonly property real todayY: grid.y + (Math.floor(todayIndex / 7) + 0.5) * (cellH + rowGap) - rowGap / 2

    ameForm: todayVisible ? "ring" : "dock"
    amePoint: todayVisible ? Qt.point(todayX, todayY) : Qt.point(width / 2, height / 2)

    SystemClock {
        id: sysClock
        precision: SystemClock.Minutes
    }

    function firstWeekdayOffset(year, month) {
        var d = new Date(year, month, 1).getDay();
        return (d + 6) % 7;
    }

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function isToday(day) {
        return day === today.getDate()
            && viewMonth === today.getMonth()
            && viewYear === today.getFullYear();
    }

    function shiftMonth(delta) {
        var m = viewMonth + delta;
        var y = viewYear;
        while (m < 0) { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        viewMonth = m;
        viewYear = y;
    }

    function resetToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    onActiveChanged: if (active) resetToday()

    Item {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 24 * root.s

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8 * root.s

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "暦"
                color: Theme.cream
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: 16 * root.s
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.loc.standaloneMonthName(root.viewMonth, Locale.LongFormat)
                    + " " + root.viewYear
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: 11 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.0 * root.s
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * root.s

            Repeater {
                model: [-1, 1]

                Rectangle {
                    id: nav
                    required property int modelData
                    width: 22 * root.s
                    height: 22 * root.s
                    radius: Motion.rSmall * root.s
                    color: navArea.containsMouse ? Theme.frameBg : "transparent"
                    border.width: navArea.containsMouse ? 1 : 0
                    border.color: Theme.frameBorder

                    GlyphIcon {
                        anchors.centerIn: parent
                        width: 16 * root.s
                        height: 16 * root.s
                        name: nav.modelData < 0 ? "chevron-left" : "chevron-right"
                        color: navArea.containsMouse ? Theme.cream : Theme.iconDim
                        stroke: 1.8
                    }

                    MouseArea {
                        id: navArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shiftMonth(nav.modelData)
                    }
                }
            }
        }
    }

    Rectangle {
        id: divider
        anchors.top: header.bottom
        anchors.topMargin: 9 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.hair
    }

    Row {
        id: weekdays
        anchors.top: divider.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right

        Repeater {
            model: 7

            Item {
                id: wd
                required property int index
                readonly property bool weekend: index >= 5
                width: weekdays.width / 7
                height: 16 * root.s

                Text {
                    anchors.centerIn: parent
                    text: root.loc.standaloneDayName((wd.index + 1) % 7, Locale.NarrowFormat)
                    color: wd.weekend ? Theme.faint : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 9 * root.s
                    font.weight: Font.Medium
                    font.letterSpacing: 0.5 * root.s
                }
            }
        }
    }

    Grid {
        id: grid
        y: weekdays.y + weekdays.height + 4 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        columns: 7
        rowSpacing: root.rowGap
        columnSpacing: 0

        Repeater {
            model: root.rows * 7

            Item {
                id: cell
                required property int index
                readonly property int weekday: index % 7
                readonly property bool weekend: weekday >= 5
                width: grid.width / 7
                height: root.cellH

                readonly property int dayNum: index - root.offset + 1
                readonly property bool inMonth: dayNum >= 1 && dayNum <= root.monthLen
                readonly property bool current: inMonth && root.isToday(dayNum)
                readonly property int ghostNum: dayNum < 1
                    ? root.daysInMonth(root.viewYear, root.viewMonth - 1) + dayNum
                    : dayNum - root.monthLen

                Rectangle {
                    anchors.centerIn: parent
                    width: 22 * root.s
                    height: 22 * root.s
                    radius: Motion.rSmall * root.s
                    color: cellArea.containsMouse && cell.inMonth && !cell.current
                        ? Qt.rgba(0.94, 0.88, 0.84, 0.04) : "transparent"
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 24 * root.s
                    height: 24 * root.s
                    radius: Motion.rSmall * root.s
                    visible: cell.current
                    color: Theme.frameBg
                    border.width: 1
                    border.color: Theme.frameBorder
                }

                Text {
                    anchors.centerIn: parent
                    text: cell.inMonth ? cell.dayNum : cell.ghostNum
                    color: cell.inMonth
                        ? (cell.current ? Theme.todayWarm
                            : (cell.weekend ? Theme.subtle : Theme.cream))
                        : Theme.ghost
                    opacity: cell.inMonth && !cell.current && !cell.weekend ? 0.85 : 1.0
                    font.family: Theme.font
                    font.pixelSize: 11 * root.s
                    font.weight: cell.current ? Font.DemiBold : Font.Normal
                    font.features: { "tnum": 1 }
                }

                MouseArea {
                    id: cellArea
                    anchors.fill: parent
                    hoverEnabled: true
                }
            }
        }
    }
}
