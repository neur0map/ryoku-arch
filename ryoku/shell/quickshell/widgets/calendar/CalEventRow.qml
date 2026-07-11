pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

// one event line for the calendar faces: an accent tick, the start time (a
// range when it has an end, or "all"), the note, and a delete tick. clicking
// the note re-opens the event in the face's add field for editing, and the row
// tints while it is the one being edited. the delete tick arms on the first tap
// (accent fill, a couple of seconds) and only removes on a second tap, so a
// stray click can't drop a note. reused by the month, week, agenda and heat
// faces so the row reads the same everywhere; removing writes the shared Events
// store the pill's calendar reads.
Item {
    id: root

    property var event: null
    property real s: 1
    property color accent: Theme.ink
    // true while this row's event is loaded in the add field; the face binds it
    // off the field's edit id, so the tint tracks the real edit target.
    property bool editing: false

    // ask the face to load this event into its add field for editing.
    signal editRequested(var ev)

    readonly property real gap: Math.round(8 * root.s)
    readonly property real tickW: Math.round(3 * root.s)
    readonly property real timeW: root.hasRange ? Math.round(70 * root.s) : Math.round(34 * root.s)
    readonly property real delW: Math.round(24 * root.s)

    readonly property bool hasRange: !!(root.event && root.event.endTime && root.event.endTime.length > 0)
    readonly property string timeLabel: {
        if (!root.event || !root.event.time || root.event.time.length === 0)
            return "all";
        return root.hasRange ? root.event.time + "-" + root.event.endTime : root.event.time;
    }

    height: Math.round(20 * root.s)

    // armed-delete state: first tap arms, a second tap within the window deletes.
    property bool armed: false
    Timer {
        id: disarm
        interval: 2000
        onTriggered: root.armed = false
    }

    // editing tint behind the whole row.
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Math.round(4 * root.s)
        anchors.rightMargin: -Math.round(4 * root.s)
        radius: Math.round(6 * root.s)
        visible: root.editing
        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12)
    }

    Row {
        anchors.fill: parent
        spacing: root.gap

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.tickW
            height: Math.round(12 * root.s)
            radius: width / 2
            color: root.accent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: root.timeW
            text: root.timeLabel
            color: Theme.inkDim
            font.family: Theme.font
            font.pixelSize: Math.round(10 * root.s)
            font.features: { "tnum": 1 }
        }

        Text {
            id: note
            anchors.verticalCenter: parent.verticalCenter
            width: root.width - root.tickW - root.timeW - root.delW - root.gap * 3
            text: root.event ? root.event.text : ""
            elide: Text.ElideRight
            color: Theme.ink
            font.family: Theme.font
            font.pixelSize: Math.round(11 * root.s)

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.event) root.editRequested(root.event)
            }
        }

        // >=24x24 hit area; the × glyph stays small.
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.delW
            height: root.delW
            radius: Math.round(6 * root.s)
            color: root.armed
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.85)
                : (delArea.containsMouse ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.08) : "transparent")

            Text {
                anchors.centerIn: parent
                text: "\u00d7"
                color: root.armed ? Theme.cardBot : (delArea.containsMouse ? Theme.brand : Theme.faint)
                font.family: Theme.font
                font.pixelSize: Math.round(13 * root.s)
            }

            MouseArea {
                id: delArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.event)
                        return;
                    if (root.armed)
                        Events.remove(root.event.id);
                    else {
                        root.armed = true;
                        disarm.restart();
                    }
                }
            }
        }
    }
}
