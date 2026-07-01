pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/cal.js" as Cal
import "lib/events.js" as EventsModel

// minimal face: no grid. a big today number, the weekday and month around it,
// then today's notes as a quiet "up next" list under a short accent rule. earns
// its place through type and spacing; reads events from the shared store so a
// note added in the pill (or another face) shows here. display-only.
Item {
    id: face

    readonly property real s: Config.calScale
    readonly property color accent: Config.calAccent === "brand" ? Theme.brand
        : (Config.calAccent === "mono" ? Theme.ink : Wallust.accent)

    readonly property date today: Now.date
    readonly property string todayKey: EventsModel.dateKey(today.getFullYear(), today.getMonth(), today.getDate())
    readonly property var todays: Events.forDate(todayKey)

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: Math.round(12 * face.s)

        Row {
            spacing: Math.round(14 * face.s)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: face.today.getDate()
                color: Theme.ink
                font.family: Theme.mono
                font.pixelSize: Math.round(72 * face.s)
                font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(3 * face.s)
                Text {
                    text: Cal.WEEKDAY[face.today.getDay()]
                    color: face.accent
                    font.family: Theme.font
                    font.pixelSize: Math.round(21 * face.s)
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Cal.MONTH[face.today.getMonth()] + " " + face.today.getFullYear()
                    color: Theme.inkDim
                    font.family: Theme.font
                    font.pixelSize: Math.round(15 * face.s)
                    font.weight: Font.Medium
                }
                Rectangle {
                    width: Math.round(46 * face.s)
                    height: Math.max(2, Math.round(3 * face.s))
                    radius: height / 2
                    color: face.accent
                    visible: face.todays.length === 0
                }
            }
        }

        Column {
            visible: face.todays.length > 0
            spacing: Math.round(6 * face.s)

            Text {
                text: "UP NEXT"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Math.round(9 * face.s)
                font.weight: Font.DemiBold
                font.letterSpacing: Math.round(2 * face.s)
            }

            Repeater {
                model: Math.min(4, face.todays.length)
                Row {
                    id: ev
                    required property int index
                    readonly property var e: face.todays[index]
                    spacing: Math.round(8 * face.s)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(38 * face.s)
                        text: ev.e.time && ev.e.time.length > 0 ? ev.e.time : "all"
                        color: face.accent
                        font.family: Theme.mono
                        font.pixelSize: Math.round(11 * face.s)
                        font.weight: Font.Medium
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ev.e.text
                        color: Theme.inkSoft
                        font.family: Theme.font
                        font.pixelSize: Math.round(12 * face.s)
                    }
                }
            }

            Text {
                visible: face.todays.length > 4
                text: "+" + (face.todays.length - 4) + " more"
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Math.round(10 * face.s)
                font.weight: Font.Medium
            }
        }
    }
}
