pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/cal.js" as Cal
import "lib/events.js" as EventsModel

// heat face: the month as an activity heatmap. each day is a rounded tile whose
// fill grows with how many notes sit on it (a GitHub-contribution read on your
// own calendar), tinted along the wallust ramp so a busy month lights up in the
// wallpaper's colours. today keeps an accent ring; a Less..More legend anchors
// the scale. clicking a day opens the same editor the other faces use, so it
// still writes the shared Events store the pill reads. the data-forward look.
Item {
    id: face

    readonly property real s: Config.calScale
    readonly property int weekStart: Config.calWeekStart === "sun" ? 0 : 1
    readonly property color accent: Config.calAccent === "brand" ? Theme.brand
        : (Config.calAccent === "mono" ? Theme.ink : Wallust.accent)
    readonly property bool ramped: Config.calAccent === "wallust"
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
    readonly property real cellH: Math.round(32 * s)
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

    // event count (0..4+) -> fill. level 0 is a bare outline; 1..4 climb the
    // wallust ramp (or a single-hue alpha climb when the accent isn't wallust),
    // so intensity reads at a glance and still honours the accent knob.
    function levelOf(count) {
        return count <= 0 ? 0 : Math.min(4, count);
    }
    function tileColor(level) {
        if (level <= 0)
            return "transparent";
        if (face.ramped)
            return Wallust.colorAt(0.15 + (level - 1) / 3 * 0.8);
        return Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.2 + (level - 1) / 3 * 0.65);
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

        // heat grid.
        Grid {
            columns: 7
            rowSpacing: Math.round(3 * face.s)
            columnSpacing: Math.round(3 * face.s)

            Repeater {
                model: face.rows * 7
                Item {
                    id: cell
                    required property int index
                    readonly property int dayNum: index - face.offset + 1
                    readonly property bool inMonth: dayNum >= 1 && dayNum <= face.monthLen
                    readonly property bool current: inMonth && face.isToday(dayNum)
                    readonly property string key: inMonth ? EventsModel.dateKey(face.viewYear, face.viewMonth, dayNum) : ""
                    readonly property bool selected: inMonth && key === face.selectedKey
                    readonly property int count: inMonth ? Events.forDate(key).length : 0
                    readonly property int level: face.levelOf(count)

                    width: face.colW
                    height: face.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: face.colW - Math.round(4 * face.s)
                        height: face.cellH - Math.round(4 * face.s)
                        radius: Math.round(7 * face.s)
                        visible: cell.inMonth
                        color: cell.level > 0 ? face.tileColor(cell.level)
                            : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, dayArea.containsMouse ? 0.08 : 0.04)
                        border.width: (cell.current || cell.selected) ? 1 : 0
                        border.color: cell.current
                            ? Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.9)
                            : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.3)

                        Text {
                            anchors.centerIn: parent
                            text: cell.dayNum
                            color: cell.level >= 3 ? Theme.cardBot
                                : (cell.current ? face.accent : (cell.level > 0 ? Theme.ink : Theme.inkDim))
                            font.family: Theme.font
                            font.pixelSize: Math.round(11 * face.s)
                            font.weight: (cell.current || cell.level >= 3) ? Font.DemiBold : Font.Normal
                            font.features: { "tnum": 1 }
                        }
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

        // Less..More legend.
        Row {
            spacing: Math.round(4 * face.s)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Less"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Math.round(9 * face.s)
                font.weight: Font.Medium
            }
            Repeater {
                model: 5
                Rectangle {
                    id: leg
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(11 * face.s)
                    height: Math.round(11 * face.s)
                    radius: Math.round(3 * face.s)
                    color: leg.index > 0 ? face.tileColor(leg.index)
                        : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.06)
                    border.width: leg.index === 0 ? 1 : 0
                    border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.2)
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "More"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Math.round(9 * face.s)
                font.weight: Font.Medium
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
