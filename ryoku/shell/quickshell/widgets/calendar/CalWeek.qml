pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/cal.js" as Cal
import "lib/events.js" as EventsModel

// week face: the current week as a horizontal strip, seven day columns honouring
// the week-start knob. today's number sits in an accent ring, weekends dim, a
// day with notes shows a dot. clicking a day opens a compact editor below it
// (its notes + an add field) that writes the shared Events store the pill reads.
// the low, wide calendar for an edge of the desktop.
Item {
    id: face

    readonly property real s: Config.calScale
    readonly property int weekStart: Config.calWeekStart === "sun" ? 0 : 1
    readonly property color accent: Config.calAccent === "brand" ? Theme.brand
        : (Config.calAccent === "mono" ? Theme.ink : Wallust.accent)
    readonly property alias editing: addField.editing

    readonly property date today: Now.date
    readonly property string todayKey: EventsModel.dateKey(today.getFullYear(), today.getMonth(), today.getDate())
    // derive the week from the day KEY (+ weekStart), not the per-second `today`,
    // so a Now tick doesn't rebuild the strip (which would drop add-field focus).
    readonly property var days: face.weekFromKey(todayKey, weekStart)
    property string selectedKey: ""

    readonly property real colW: Math.round(40 * s)
    readonly property real stripW: colW * 7
    readonly property var selEvents: selectedKey.length > 0 ? Events.forDate(selectedKey) : []

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    function weekFromKey(key, ws) {
        var p = key.split("-");
        return Cal.weekOf(new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2])), ws);
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
        spacing: Math.round(10 * face.s)

        Row {
            spacing: Math.round(8 * face.s)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u529b"
                color: Theme.brand
                font.family: Theme.fontJp
                font.weight: Font.Medium
                font.pixelSize: Math.round(14 * face.s)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Cal.MONTH[face.today.getMonth()] + " " + face.today.getFullYear()
                color: Theme.ink
                font.family: Theme.font
                font.pixelSize: Math.round(12 * face.s)
                font.weight: Font.DemiBold
            }
        }

        Row {
            Repeater {
                model: face.days
                Item {
                    id: dayCell
                    required property var modelData
                    readonly property string key: EventsModel.dateKey(modelData.year, modelData.month, modelData.day)
                    readonly property bool current: key === face.todayKey
                    readonly property bool selected: key === face.selectedKey
                    readonly property bool weekend: Cal.isWeekend(modelData.weekday)
                    readonly property bool hasEv: Events.hasEvents(key)

                    width: face.colW
                    height: Math.round(58 * face.s)

                    Column {
                        anchors.centerIn: parent
                        spacing: Math.round(5 * face.s)

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Cal.WEEKDAY_MIN[dayCell.modelData.weekday]
                            color: dayCell.weekend ? Theme.faint : Theme.inkDim
                            font.family: Theme.font
                            font.pixelSize: Math.round(9 * face.s)
                            font.weight: Font.Medium
                            font.letterSpacing: Math.round(0.5 * face.s)
                        }

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.round(28 * face.s)
                            height: width

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.round(9 * face.s)
                                visible: dayCell.current || dayCell.selected || cellArea.containsMouse
                                color: dayCell.current ? Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.16)
                                    : (cellArea.containsMouse && !dayCell.selected ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.05) : "transparent")
                                border.width: (dayCell.current || dayCell.selected) ? 1 : 0
                                border.color: dayCell.current
                                    ? Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.55)
                                    : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.22)
                            }
                            Text {
                                anchors.centerIn: parent
                                text: dayCell.modelData.day
                                color: dayCell.current ? face.accent : (dayCell.weekend ? Theme.inkDim : Theme.ink)
                                font.family: Theme.mono
                                font.pixelSize: Math.round(14 * face.s)
                                font.weight: dayCell.current ? Font.Bold : Font.Medium
                                font.features: { "tnum": 1 }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.round(3 * face.s)
                            height: width
                            radius: width / 2
                            visible: dayCell.hasEv
                            color: dayCell.current ? face.accent : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.5)
                        }
                    }

                    MouseArea {
                        id: cellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: face.selectedKey = (face.selectedKey === dayCell.key ? "" : dayCell.key)
                    }
                }
            }
        }

        // compact editor for the picked day.
        Column {
            visible: face.selectedKey.length > 0
            width: face.stripW
            spacing: Math.round(6 * face.s)

            Rectangle { width: parent.width; height: 1; color: Theme.hair }

            Text {
                text: face.prettyKey(face.selectedKey)
                color: Theme.inkDim
                font.family: Theme.font
                font.pixelSize: Math.round(10 * face.s)
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Math.round(0.8 * face.s)
            }

            Repeater {
                model: face.selEvents
                CalEventRow {
                    required property var modelData
                    width: face.stripW
                    s: face.s
                    accent: face.accent
                    event: modelData
                }
            }

            CalAddField {
                id: addField
                width: face.stripW
                s: face.s
                accent: face.accent
                dateKey: face.selectedKey
            }
        }
    }
}
