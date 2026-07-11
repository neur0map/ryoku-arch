pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/cal.js" as Cal
import "lib/events.js" as EventsModel

// agenda face: the week ahead as a vertical list. each row is a date chip (day
// number over weekday) beside that day's notes; today's chip is accent-filled.
// clicking a day selects it and reveals the add field under it, writing the
// shared Events store the pill reads. the schedule-first calendar look.
Item {
    id: face

    readonly property real s: Config.calScale
    readonly property color accent: Config.calAccent === "brand" ? Theme.brand
        : (Config.calAccent === "mono" ? Theme.ink : Wallust.accent)
    property bool editing: false

    readonly property string todayKey: Now.dayKey
    // offset in 7-day pages from today (0 = the page starting today). the page
    // derives from today + offset, so nav self-heals over a day rollover; keyed
    // off the day KEY, not the per-second `today`, so a Now tick doesn't rebuild
    // the Repeater (which would drop add-field focus).
    property int pageOffset: 0
    readonly property var days: face.pageDays()
    property string selectedKey: face.todayKey

    readonly property real bodyW: Math.round(228 * s)
    readonly property real rowW: Math.round(42 * s) + Math.round(14 * s) + bodyW

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    function pageDays() {
        var p = face.todayKey.split("-");
        var d = new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]) + face.pageOffset * 7);
        return Cal.daysFrom(d, 7);
    }
    function shiftPage(delta) {
        face.pageOffset += delta;
        face.reselectIntoView();
    }
    function resetToday() {
        face.pageOffset = 0;
        face.selectedKey = face.todayKey;
    }
    // keep the selection on the visible page: if the selected day isn't in it,
    // drop it onto the first day of the page.
    function reselectIntoView() {
        for (var i = 0; i < face.days.length; i++)
            if (EventsModel.dateKey(face.days[i].year, face.days[i].month, face.days[i].day) === face.selectedKey)
                return;
        face.selectedKey = EventsModel.dateKey(face.days[0].year, face.days[0].month, face.days[0].day);
    }

    Column {
        id: col
        spacing: Math.round(10 * face.s)

        Item {
            width: face.rowW
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
                    text: "AGENDA"
                    color: Theme.inkDim
                    font.family: Theme.font
                    font.pixelSize: Math.round(11 * face.s)
                    font.weight: Font.DemiBold
                    font.letterSpacing: Math.round(2 * face.s)
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(4 * face.s)
                Rectangle {
                    id: todayChip
                    anchors.verticalCenter: parent.verticalCenter
                    visible: face.pageOffset !== 0
                    width: todayLabel.implicitWidth + Math.round(14 * face.s)
                    height: Math.round(18 * face.s)
                    radius: Math.round(6 * face.s)
                    color: todayArea.containsMouse
                        ? Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.28)
                        : Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.16)
                    Text {
                        id: todayLabel
                        anchors.centerIn: parent
                        text: "TODAY"
                        color: face.accent
                        font.family: Theme.mono
                        font.pixelSize: Math.round(9 * face.s)
                        font.weight: Font.DemiBold
                        font.letterSpacing: Math.round(1 * face.s)
                    }
                    MouseArea {
                        id: todayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: face.resetToday()
                    }
                }
                Repeater {
                    model: [-1, 1]
                    Rectangle {
                        id: nav
                        required property int modelData
                        width: Math.round(26 * face.s)
                        height: Math.round(26 * face.s)
                        radius: Math.round(8 * face.s)
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
                            onClicked: face.shiftPage(nav.modelData)
                        }
                    }
                }
            }
        }

        Repeater {
            model: face.days
            Item {
                id: dayRow
                required property var modelData
                readonly property string key: EventsModel.dateKey(modelData.year, modelData.month, modelData.day)
                readonly property bool current: key === face.todayKey
                readonly property bool selected: key === face.selectedKey
                readonly property bool weekend: Cal.isWeekend(modelData.weekday)
                readonly property var evs: Events.forDate(key)

                width: chip.width + Math.round(14 * face.s) + face.bodyW
                height: Math.max(chip.height, body.height)

                Rectangle {
                    id: chip
                    width: Math.round(42 * face.s)
                    height: Math.round(44 * face.s)
                    radius: Math.round(10 * face.s)
                    color: dayRow.current
                        ? Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.16)
                        : Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.04)
                    border.width: 1
                    border.color: dayRow.current
                        ? Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.5)
                        : Theme.hair

                    Column {
                        anchors.centerIn: parent
                        spacing: 0
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: dayRow.modelData.day
                            color: dayRow.current ? face.accent : (dayRow.weekend ? Theme.inkDim : Theme.ink)
                            font.family: Theme.mono
                            font.pixelSize: Math.round(18 * face.s)
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Cal.WEEKDAY_SHORT[dayRow.modelData.weekday].toUpperCase()
                            color: dayRow.current ? face.accent : Theme.inkDim
                            font.family: Theme.font
                            font.pixelSize: Math.round(9 * face.s)
                            font.weight: Font.DemiBold
                            font.letterSpacing: Math.round(1 * face.s)
                        }
                    }
                }

                Column {
                    id: body
                    anchors.left: chip.right
                    anchors.leftMargin: Math.round(14 * face.s)
                    anchors.verticalCenter: chip.verticalCenter
                    width: face.bodyW
                    spacing: Math.round(4 * face.s)

                    Text {
                        visible: dayRow.evs.length === 0 && !dayRow.selected
                        text: "\u2014"
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: Math.round(11 * face.s)
                    }

                    Repeater {
                        model: dayRow.evs
                        CalEventRow {
                            required property var modelData
                            width: face.bodyW
                            s: face.s
                            accent: face.accent
                            event: modelData
                            editing: addField.editId === modelData.id
                            onEditRequested: (ev) => { face.selectedKey = dayRow.key; addField.beginEdit(ev); }
                        }
                    }

                    Text {
                        visible: dayRow.selected && dayRow.evs.length === 0
                        text: qsTr("Nothing on this day \u2014 add below")
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: Math.round(10 * face.s)
                    }

                    CalAddField {
                        id: addField
                        visible: dayRow.selected
                        width: face.bodyW
                        s: face.s
                        accent: face.accent
                        dateKey: face.selectedKey
                        onEditingChanged: face.editing = editing
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: face.selectedKey = dayRow.key
                }
            }
        }
    }
}
