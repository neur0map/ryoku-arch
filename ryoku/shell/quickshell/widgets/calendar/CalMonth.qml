pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/cal.js" as Cal
import "lib/events.js" as EventsModel

// month face: the full grid. 力 masthead + month/year with prev/next, a weekday
// strip honouring the week-start knob, then a day grid sized to exactly the rows
// the month needs. today wears a warm accent ring, weekend columns dim,
// leading/trailing cells ghost the neighbour months. a day with events shows a
// dot; clicking a day opens its notes below with an add field, which writes the
// shared Events store the pill's calendar reads. flagship calendar look.
Item {
    id: face

    readonly property real s: Config.calScale
    readonly property int weekStart: Config.calWeekStart === "sun" ? 0 : 1
    readonly property color accent: Config.calAccent === "brand" ? Theme.brand
        : (Config.calAccent === "mono" ? Theme.ink : Wallust.accent)
    readonly property alias editing: addField.editing

    readonly property date today: Now.date
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property string selectedKey: EventsModel.dateKey(today.getFullYear(), today.getMonth(), today.getDate())

    readonly property int offset: Cal.firstWeekdayOffset(viewYear, viewMonth, weekStart)
    readonly property int monthLen: Cal.daysInMonth(viewYear, viewMonth)
    readonly property int rows: Cal.weekRows(viewYear, viewMonth, weekStart)
    readonly property var order: Cal.weekdayOrder(weekStart)

    readonly property real colW: Math.round(34 * s)
    readonly property real cellH: Math.round(30 * s)
    readonly property real gridW: colW * 7

    readonly property var selEvents: Events.forDate(selectedKey)

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    function isToday(day) {
        return day === today.getDate() && viewMonth === today.getMonth() && viewYear === today.getFullYear();
    }
    function shiftMonth(delta) {
        var m = viewMonth + delta;
        var y = viewYear;
        while (m < 0) { m += 12; y -= 1; }
        while (m > 11) { m -= 12; y += 1; }
        viewMonth = m;
        viewYear = y;
    }
    function prettyKey(key) {
        var p = key.split("-");
        if (p.length !== 3)
            return "";
        var d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]));
        return Cal.WEEKDAY_SHORT[d.getDay()] + " " + Number(p[2]) + " " + Cal.MONTH_SHORT[Number(p[1]) - 1];
    }

    Column {
        id: col
        spacing: Math.round(8 * face.s)

        // masthead + month nav.
        Item {
            width: face.gridW
            height: Math.round(24 * face.s)

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(8 * face.s)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u529b"
                    color: Theme.brand
                    font.family: Theme.fontJp
                    font.weight: Font.Medium
                    font.pixelSize: Math.round(15 * face.s)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Cal.MONTH[face.viewMonth] + " " + face.viewYear
                    color: Theme.ink
                    font.family: Theme.font
                    font.pixelSize: Math.round(13 * face.s)
                    font.weight: Font.DemiBold
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(2 * face.s)
                Repeater {
                    model: [-1, 1]
                    Rectangle {
                        id: nav
                        required property int modelData
                        width: Math.round(22 * face.s)
                        height: Math.round(22 * face.s)
                        radius: Math.round(7 * face.s)
                        color: navArea.containsMouse ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.08) : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: nav.modelData < 0 ? "\u2039" : "\u203a"
                            color: navArea.containsMouse ? Theme.ink : Theme.inkDim
                            font.family: Theme.font
                            font.pixelSize: Math.round(16 * face.s)
                            font.weight: Font.Medium
                        }
                        MouseArea {
                            id: navArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: face.shiftMonth(nav.modelData)
                        }
                    }
                }
            }
        }

        Rectangle { width: face.gridW; height: 1; color: Theme.hair }

        // weekday strip.
        Row {
            Repeater {
                model: face.order
                Item {
                    id: wd
                    required property int modelData
                    width: face.colW
                    height: Math.round(16 * face.s)
                    Text {
                        anchors.centerIn: parent
                        text: Cal.WEEKDAY_MIN[wd.modelData]
                        color: Cal.isWeekend(wd.modelData) ? Theme.faint : Theme.inkDim
                        font.family: Theme.font
                        font.pixelSize: Math.round(9 * face.s)
                        font.weight: Font.Medium
                        font.letterSpacing: Math.round(0.5 * face.s)
                    }
                }
            }
        }

        // day grid.
        Grid {
            columns: 7
            rowSpacing: Math.round(2 * face.s)
            columnSpacing: 0

            Repeater {
                model: face.rows * 7
                Item {
                    id: cell
                    required property int index
                    readonly property int jsWeekday: face.order[index % 7]
                    readonly property bool weekend: Cal.isWeekend(jsWeekday)
                    readonly property int dayNum: index - face.offset + 1
                    readonly property bool inMonth: dayNum >= 1 && dayNum <= face.monthLen
                    readonly property bool current: inMonth && face.isToday(dayNum)
                    readonly property string key: inMonth ? EventsModel.dateKey(face.viewYear, face.viewMonth, dayNum) : ""
                    readonly property bool selected: inMonth && key === face.selectedKey
                    readonly property bool hasEv: inMonth && Events.hasEvents(key)
                    readonly property int ghostNum: dayNum < 1
                        ? Cal.daysInMonth(face.viewYear, face.viewMonth - 1) + dayNum
                        : dayNum - face.monthLen

                    width: face.colW
                    height: face.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(26 * face.s)
                        height: width
                        radius: Math.round(8 * face.s)
                        visible: cell.current || cell.selected
                        color: cell.current ? Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.16) : "transparent"
                        border.width: 1
                        border.color: cell.current
                            ? Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.55)
                            : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.22)
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.round(26 * face.s)
                        height: width
                        radius: Math.round(8 * face.s)
                        visible: dayArea.containsMouse && cell.inMonth && !cell.current && !cell.selected
                        color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.05)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.inMonth ? cell.dayNum : cell.ghostNum
                        color: cell.inMonth
                            ? (cell.current ? face.accent : (cell.weekend ? Theme.inkDim : Theme.ink))
                            : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.22)
                        font.family: Theme.font
                        font.pixelSize: Math.round(11 * face.s)
                        font.weight: cell.current ? Font.DemiBold : Font.Normal
                        font.features: { "tnum": 1 }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.verticalCenter
                        anchors.topMargin: Math.round(9 * face.s)
                        width: Math.round(3 * face.s)
                        height: width
                        radius: width / 2
                        visible: cell.hasEv
                        color: cell.current ? face.accent : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.5)
                    }

                    MouseArea {
                        id: dayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: cell.inMonth ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (cell.inMonth) face.selectedKey = cell.key
                    }
                }
            }
        }

        // selected-day editor.
        Rectangle { width: face.gridW; height: 1; color: Theme.hair }

        Text {
            text: face.prettyKey(face.selectedKey)
            color: Theme.inkDim
            font.family: Theme.font
            font.pixelSize: Math.round(10 * face.s)
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: Math.round(0.8 * face.s)
        }

        Column {
            width: face.gridW
            spacing: Math.round(4 * face.s)
            Repeater {
                model: face.selEvents
                CalEventRow {
                    required property var modelData
                    width: face.gridW
                    s: face.s
                    accent: face.accent
                    event: modelData
                }
            }
        }

        CalAddField {
            id: addField
            width: face.gridW
            s: face.s
            accent: face.accent
            dateKey: face.selectedKey
        }
    }
}
