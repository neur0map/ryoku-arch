pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"

// Autostart: the commands Hyprland runs once at login, layered over the fixed
// Ryoku autostart. Edits stage in the draft and are written to settings.lua on
// Save; the list is not previewed live. Rows commit on edit-finish, because
// replacing the list rebuilds the Repeater's delegates mid-type otherwise.
Item {
    id: page

    HyprStore { id: store }

    function patch(i, val) {
        var a = store.autostart.slice();
        a[i] = Object.assign({}, a[i]);
        a[i].command = val;
        store.editList("autostart", a);
    }
    function remove(i) {
        var a = store.autostart.slice();
        a.splice(i, 1);
        store.editList("autostart", a);
    }
    function add() {
        var a = store.autostart.slice();
        a.push({ "command": "" });
        store.editList("autostart", a);
    }

    Text {
        id: intro
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        wrapMode: Text.WordWrap
        text: "Commands run once at login, after the base Ryoku autostart."
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 12
    }

    HubButton {
        id: addBtn
        anchors.left: parent.left
        anchors.top: intro.bottom
        anchors.topMargin: 14
        label: "Add command"
        icon: "plus"
        onClicked: page.add()
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: addBtn.bottom
        anchors.topMargin: 16
        anchors.bottom: bar.top
        anchors.bottomMargin: 16
        contentWidth: width
        contentHeight: rows.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: sb
            policy: ScrollBar.AsNeeded
            width: 7
            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.line
                opacity: sb.pressed ? 0.9 : (sb.hovered ? 0.7 : 0.4)
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
            }
        }

        Column {
            id: rows
            width: flick.width - 12
            spacing: 10

            Text {
                visible: store.autostart.length === 0
                text: "No autostart commands yet."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 13
            }

            Repeater {
                model: store.autostart

                delegate: Rectangle {
                    id: rowItem
                    required property int index
                    required property var modelData
                    width: rows.width
                    height: 56
                    radius: 12
                    color: Theme.surfaceLo
                    border.width: 1
                    border.color: Theme.line

                    Item {
                        id: delBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 26
                        height: 26
                        Icon {
                            anchors.centerIn: parent
                            name: "trash"
                            size: 15
                            tint: delHov.hovered ? Theme.bad : Theme.faint
                        }
                        HoverHandler { id: delHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: page.remove(rowItem.index) }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.right: delBtn.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        height: 32
                        radius: 9
                        color: Theme.surface
                        border.width: 1
                        border.color: cmdIn.activeFocus ? Theme.ember : Theme.line
                        Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                        TextInput {
                            id: cmdIn
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            text: rowItem.modelData.command
                            color: Theme.bright
                            font.family: Theme.mono
                            font.pixelSize: 13
                            clip: true
                            selectByMouse: true
                            onEditingFinished: page.patch(rowItem.index, text)

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: cmdIn.text === "" && !cmdIn.activeFocus
                                text: "command to run"
                                color: Theme.faint
                                font: cmdIn.font
                            }
                        }
                    }
                }
            }
        }
    }

    // --- action bar (mirrors Shell Settings) --------------------------------
    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        height: 60
        radius: 14
        color: store.dirty ? Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.08) : Theme.surfaceLo
        border.width: 1
        border.color: store.dirty ? Qt.rgba(Theme.ember.r, Theme.ember.g, Theme.ember.b, 0.4) : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.medium } }
        Behavior on border.color { ColorAnimation { duration: Theme.medium } }

        Rectangle {
            id: statusDot
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 9
            height: 9
            radius: 4.5
            color: store.dirty ? Theme.ember : Theme.ok
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }

        Text {
            anchors.left: statusDot.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: store.dirty ? "Unsaved changes" : "Saved \u00b7 applies on save"
            color: store.dirty ? Theme.bright : Theme.dim
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Clear all"
                icon: "refresh"
                onClicked: store.editList("autostart", [])
            }
            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Revert"
                icon: "close"
                enabled: store.dirty
                onClicked: store.revert()
            }
            HubButton {
                anchors.verticalCenter: parent.verticalCenter
                label: "Save"
                icon: "check"
                primary: true
                enabled: store.dirty
                onClicked: store.save()
            }
        }
    }
}
