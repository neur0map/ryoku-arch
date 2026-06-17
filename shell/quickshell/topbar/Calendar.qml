pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons"

PanelWindow {
    id: pop

    property real s: 1
    property var anchorWindow
    property bool open: false

    readonly property var deLocale: Qt.locale("de_DE")

    property date today: new Date()
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()

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
        today = new Date();
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
    }

    screen: anchorWindow ? anchorWindow.screen : null
    visible: open
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "topbar-calendar"

    anchors { top: true; left: true; right: true; bottom: true }

    onVisibleChanged: {
        if (visible) {
            resetToday();
            frame.forceActiveFocus();
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: pop.open = false
    }

    FocusScope {
        anchors.fill: parent
        focus: pop.open

        Keys.onEscapePressed: pop.open = false

        Rectangle {
            id: frame
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: 50 * pop.s
            width: 252 * pop.s
            radius: 14 * pop.s
            clip: true
            focus: true
            border.width: 1
            border.color: Theme.border
            implicitHeight: column.implicitHeight + 28 * pop.s
            height: implicitHeight

            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.cardTop }
                GradientStop { position: 1.0; color: Theme.cardBot }
            }

            Keys.onEscapePressed: pop.open = false

            MouseArea { anchors.fill: parent }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                height: 1
                color: Theme.sheen
            }

            Column {
                id: column
                anchors.fill: parent
                anchors.margins: 14 * pop.s
                spacing: 10 * pop.s

                Item {
                    width: parent.width
                    height: 22 * pop.s

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: pop.deLocale.standaloneMonthName(pop.viewMonth, Locale.LongFormat)
                            + " " + pop.viewYear
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 13 * pop.s
                        font.weight: Font.DemiBold
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2 * pop.s

                        Repeater {
                            model: [-1, 1]

                            Rectangle {
                                id: nav
                                required property int modelData
                                width: 22 * pop.s
                                height: 22 * pop.s
                                radius: 6
                                color: navArea.containsMouse ? Theme.slotBg : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: nav.modelData < 0 ? "‹" : "›"
                                    color: Theme.vermLit
                                    font.family: Theme.font
                                    font.pixelSize: 15 * pop.s
                                    font.weight: Font.DemiBold
                                }

                                MouseArea {
                                    id: navArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: pop.shiftMonth(nav.modelData)
                                }
                            }
                        }
                    }
                }

                Row {
                    id: weekdays
                    width: parent.width

                    Repeater {
                        model: 7

                        Item {
                            id: wd
                            required property int index
                            width: weekdays.width / 7
                            height: 18 * pop.s

                            Text {
                                anchors.centerIn: parent
                                text: pop.deLocale.standaloneDayName((wd.index + 1) % 7, Locale.NarrowFormat)
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: 9 * pop.s
                                font.weight: Font.Medium
                                font.letterSpacing: 0.5 * pop.s
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.hair
                }

                Grid {
                    id: grid
                    width: parent.width
                    columns: 7
                    rowSpacing: 2 * pop.s
                    columnSpacing: 0

                    Repeater {
                        model: 42

                        Item {
                            id: cell
                            required property int index
                            width: grid.width / 7
                            height: 26 * pop.s

                            readonly property int dayNum: index - pop.firstWeekdayOffset(pop.viewYear, pop.viewMonth) + 1
                            readonly property bool inMonth: dayNum >= 1 && dayNum <= pop.daysInMonth(pop.viewYear, pop.viewMonth)
                            readonly property bool current: inMonth && pop.isToday(dayNum)

                            Rectangle {
                                anchors.centerIn: parent
                                width: 24 * pop.s
                                height: 24 * pop.s
                                radius: 6
                                visible: cell.current

                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Theme.vermLit }
                                    GradientStop { position: 1.0; color: Theme.vermDeep }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: cell.inMonth
                                text: cell.dayNum
                                color: cell.current ? Theme.bright : Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 11 * pop.s
                                font.weight: cell.current ? Font.DemiBold : Font.Normal
                                font.features: { "tnum": 1 }
                            }
                        }
                    }
                }
            }
        }
    }
}
