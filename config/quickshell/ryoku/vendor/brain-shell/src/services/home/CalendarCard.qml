import QtQuick
import "../../"
import "../../components"

// Calendar card — month grid with prev/next navigation.
// Self-contained: owns all calendar state.

StatCard {
    id: root
    padding: 0

    // ── State ─────────────────────────────────────────────────────────────────
    property int    _year:  0
    property int    _month: 0
    property int    _today: 0
    property var    _days:  []
    property string _label: ""

    readonly property var _monthNames: [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    readonly property var _dowNames: ["Su","Mo","Tu","We","Th","Fr","Sa"]

    Component.onCompleted: {
        var now   = new Date()
        _year     = now.getFullYear()
        _month    = now.getMonth()
        _today    = now.getDate()
        _rebuild()
    }

    function _rebuild() {
        _label = _monthNames[_month].substring(0,3).toUpperCase() + "  " + _year
        var firstDow   = new Date(_year, _month, 1).getDay()
        var daysInMon  = new Date(_year, _month + 1, 0).getDate()
        var daysInPrev = new Date(_year, _month, 0).getDate()
        var days = []
        for (var p = firstDow - 1; p >= 0; p--)
            days.push({ n: daysInPrev - p, cur: false })
        for (var d = 1; d <= daysInMon; d++)
            days.push({ n: d, cur: true })
        var tail = 42 - days.length
        for (var t = 1; t <= tail; t++)
            days.push({ n: t, cur: false })
        _days = days
    }

    function _prev() {
        if (_month === 0) { _month = 11; _year-- } else _month--
        _rebuild()
    }
    function _next() {
        if (_month === 11) { _month = 0; _year++ } else _month++
        _rebuild()
    }

	Timer {
		running: true
		Component.onCompleted: {
			var now = new Date()
			var tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1)
			interval = tomorrow - now // Set interval to exact time until midnight
		}
		onTriggered: {
			var now = new Date()
			root._year  = now.getFullYear()
			root._month = now.getMonth()
			root._today = now.getDate()
			root._rebuild()

			interval = 86400000 // Reset to 24 hours for the next day
			restart()
		}
	}

    // ── UI ────────────────────────────────────────────────────────────────────
    Item {
        anchors { fill: parent; margins: 12 }

        // Header
        Item {
            id: hdr
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 22

            Text {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: "‹"; font.pixelSize: 15
                color: pH.hovered ? Qt.rgba(1,1,1,0.7) : Qt.rgba(1,1,1,0.25)
                Behavior on color { ColorAnimation { duration: 100 } }
                HoverHandler { id: pH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root._prev() }
            }
            Text {
                anchors.centerIn: parent
                text: root._label; font.pixelSize: 10; font.weight: Font.Bold
                color: Theme.text
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "›"; font.pixelSize: 15
                color: nH.hovered ? Qt.rgba(1,1,1,0.7) : Qt.rgba(1,1,1,0.25)
                Behavior on color { ColorAnimation { duration: 100 } }
                HoverHandler { id: nH; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; onClicked: root._next() }
            }
        }

        // DOW row
        Item {
            id: dow
            anchors { left: parent.left; right: parent.right; top: hdr.bottom; topMargin: 3 }
            height: 16
            Row {
                anchors.fill: parent
                Repeater {
                    model: root._dowNames
                    delegate: Text {
                        width: Math.floor(dow.width / 7)
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData; font.pixelSize: 8; font.weight: Font.Bold
                        color: Qt.rgba(1,1,1,0.2)
                    }
                }
            }
        }

        // Day grid
        Grid {
            id: grid
            anchors { left: parent.left; right: parent.right; top: dow.bottom; topMargin: 2; bottom: parent.bottom }
            columns: 7; rows: 6

            readonly property real cW: width  / 7
            readonly property real cH: height / 6

            Repeater {
                model: root._days
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: grid.cW; height: grid.cH

                    readonly property bool isToday:
                        modelData.cur && modelData.n === root._today &&
                        root._month === new Date().getMonth() &&
                        root._year  === new Date().getFullYear()

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 4
                        height: width; radius: width / 2
                        color: isToday ? Qt.rgba(166/255,208/255,247/255,0.15)
                               : dH.hovered && modelData.cur ? Qt.rgba(1,1,1,0.07) : "transparent"
                        border.color: isToday ? Qt.rgba(166/255,208/255,247/255,0.3) : "transparent"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text {
                            anchors.centerIn: parent; text: modelData.n
                            font.pixelSize: 9; font.family: "JetBrains Mono"
                            font.weight: isToday ? Font.Bold : Font.Normal
                            color: isToday ? Theme.active
                                   : modelData.cur ? Qt.rgba(205/255,214/255,244/255,0.55)
                                                   : Qt.rgba(1,1,1,0.13)
                        }
                    }
                    HoverHandler { id: dH; enabled: modelData.cur; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
}
