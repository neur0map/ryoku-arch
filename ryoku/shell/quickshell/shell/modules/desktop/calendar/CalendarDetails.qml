import QtQuick
import "../Singletons"

Item {
    id: root

    property string dateLabel: ""
    property var holidays: []
    property var events: []
    property bool paper: false
    property real s: 1

    readonly property bool hasDetails: root.holidays.length > 0 || root.events.length > 0
    readonly property string holidayText: root.holidays.map(function(item) { return item.name; }).join(" · ")
    readonly property string eventText: root.events.map(function(item) {
        return (item.time ? item.time + "  " : "") + item.text;
    }).join(" · ")

    implicitHeight: 52 * root.s

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Theme.line
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.topMargin: 9 * root.s
        text: root.dateLabel
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 9 * root.s
        font.letterSpacing: 0.8 * root.s
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6 * root.s
        text: root.hasDetails
            ? [root.holidayText, root.eventText].filter(function(value) { return value.length > 0; }).join("   //   ")
            : qsTr("No holidays or events")
        color: root.hasDetails ? Theme.ink : Theme.faint
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: 11 * root.s
        opacity: root.hasDetails ? 1 : 0.7
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
    }
}
