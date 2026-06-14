pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Ryoku.Config
import qs.components
import qs.components.effects
import qs.services

// Sticky note content hosted inside a DesktopWidget. Empty header area falls through
// to the DesktopWidget body-drag MouseArea (so the note drags); the TextArea edits;
// the corner trash deletes the note. Text + geometry persist via cfg.save() (Notes
// service → $XDG_RUNTIME_DIR file).
StyledRect {
    id: note

    required property var cfg

    implicitWidth: 220
    implicitHeight: 170
    radius: Tokens.rounding.normal
    color: Qt.alpha(Colours.palette.m3tertiaryContainer, 0.92)
    border.width: 1
    border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)

    Elevation {
        anchors.fill: parent
        z: -1
        radius: parent.radius
        level: 2
    }

    StyledClippingRect {
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 14
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.alpha(Colours.palette.m3onSurface, 0.08)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
    }

    HoverHandler {
        id: noteHover
    }

    Timer {
        id: saveTimer
        interval: 600
        onTriggered: note.cfg.save()
    }

    // Header strip: draggable empty space + corner trash.
    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 26

        // 6-dot drag grip. Non-interactive (no MouseArea), so press+drag falls
        // through to the DesktopWidget body-drag handler and moves the note instead
        // of selecting text. Brightens on hover.
        MaterialIcon {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 6
            text: "drag_indicator"
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.normal
            opacity: noteHover.hovered ? 0.95 : 0.55

            Behavior on opacity {
                Anim {}
            }
        }

        StyledRect {
            id: trash

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 6

            implicitWidth: 22
            implicitHeight: 22
            radius: width / 2
            color: trashArea.containsMouse ? Qt.alpha(Colours.palette.m3error, 0.18) : "transparent"
            opacity: noteHover.hovered || trashArea.containsMouse ? 1 : 0

            Behavior on opacity {
                Anim {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: "delete"
                color: Colours.palette.m3error
                font.pointSize: Tokens.font.size.small
            }

            MouseArea {
                id: trashArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notes.remove(note.cfg.noteId)
            }
        }

        // "Done" button — shown only while editing; finishes editing (releases the
        // text cursor). Escape does the same.
        StyledRect {
            id: doneBtn

            anchors.right: trash.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 2

            implicitWidth: 22
            implicitHeight: 22
            radius: width / 2
            visible: input.activeFocus
            color: doneArea.containsMouse ? Qt.alpha(Colours.palette.m3primary, 0.18) : "transparent"

            MaterialIcon {
                anchors.centerIn: parent
                text: "check"
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.small
            }

            MouseArea {
                id: doneArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: input.focus = false
            }
        }
    }

    TextArea {
        id: input

        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 10
        anchors.topMargin: 0

        text: note.cfg.text
        placeholderText: qsTr("Note…")
        wrapMode: TextArea.Wrap
        color: Colours.palette.m3onSurface
        placeholderTextColor: Qt.alpha(Colours.palette.m3onSurface, 0.45)
        font.pointSize: Tokens.font.size.normal
        selectByMouse: true
        background: null

        onTextChanged: {
            if (text !== note.cfg.text) {
                note.cfg.text = text;
                saveTimer.restart();
            }
        }

        // Escape finishes editing (releases the text cursor so keys stop registering).
        Keys.onEscapePressed: event => {
            input.focus = false;
            note.cfg.save();
            event.accepted = true;
        }
    }
}
