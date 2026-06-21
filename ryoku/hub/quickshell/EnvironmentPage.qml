pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"

// Environment: custom NAME=value pairs layered over the base Hyprland session and
// edited through the shared HyprStore. Add, edit, or remove rows, then Save writes
// them into settings.lua. Unlike the appearance knobs, a session reads its
// environment only at startup, so these take full effect at the next login.
Item {
    id: page

    HyprStore { id: store }

    // editList swaps the whole array reference (so the Repeater rebinds), which
    // would tear down and rebuild the delegate that owns a focused field. To keep
    // that from happening mid-type, rows commit on editing-finished only, and every
    // helper hands editList a fresh slice rather than mutating the live list.
    function patch(i, key, val) {
        var a = store.env.slice();
        a[i] = Object.assign({}, a[i]);
        a[i][key] = val;
        store.editList("env", a);
    }
    function remove(i) {
        var a = store.env.slice();
        a.splice(i, 1);
        store.editList("env", a);
    }
    function add() {
        var a = store.env.slice();
        a.push({ "key": "", "value": "" });
        store.editList("env", a);
    }

    Text {
        id: intro
        anchors.left: parent.left
        anchors.right: addBtn.left
        anchors.rightMargin: 18
        anchors.top: parent.top
        wrapMode: Text.WordWrap
        text: "Environment variables for the Hyprland session, layered over the base. They take full effect at next login."
        color: Theme.subtle
        font.family: Theme.font
        font.pixelSize: 13
    }

    HubButton {
        id: addBtn
        anchors.right: parent.right
        anchors.top: parent.top
        label: "Add variable"
        icon: "plus"
        onClicked: page.add()
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.max(intro.height, addBtn.height) + 24
        anchors.bottom: bar.top
        anchors.bottomMargin: 18
        contentWidth: width
        contentHeight: Math.max(col.height, height)
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
            id: col
            width: flick.width - 12
            spacing: 10

            Repeater {
                model: store.env

                delegate: Rectangle {
                    id: rowRect
                    required property int index
                    required property var modelData

                    readonly property real gap: 10
                    readonly property real delW: 32
                    readonly property real fieldsW: width - 24 - delW - gap * 2
                    readonly property real keyW: Math.round(fieldsW * 0.42)

                    width: col.width
                    height: 48
                    radius: 12
                    color: Theme.surface
                    border.width: 1
                    border.color: Theme.line

                    Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: rowRect.gap

                        Rectangle {
                            width: rowRect.keyW
                            height: 32
                            radius: 9
                            color: Theme.surfaceLo
                            border.width: 1
                            border.color: keyInput.activeFocus ? Theme.ember : Theme.line
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            TextInput {
                                id: keyInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                text: rowRect.modelData.key
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onEditingFinished: {
                                    if (text !== rowRect.modelData.key)
                                        page.patch(rowRect.index, "key", text);
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: keyInput.text === "" && !keyInput.activeFocus
                                    text: "NAME"
                                    color: Theme.faint
                                    font: keyInput.font
                                }
                            }
                        }

                        Rectangle {
                            width: rowRect.fieldsW - rowRect.keyW
                            height: 32
                            radius: 9
                            color: Theme.surfaceLo
                            border.width: 1
                            border.color: valInput.activeFocus ? Theme.ember : Theme.line
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            TextInput {
                                id: valInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                text: rowRect.modelData.value
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onEditingFinished: {
                                    if (text !== rowRect.modelData.value)
                                        page.patch(rowRect.index, "value", text);
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: valInput.text === "" && !valInput.activeFocus
                                    text: "value"
                                    color: Theme.faint
                                    font: valInput.font
                                }
                            }
                        }

                        Item {
                            width: rowRect.delW
                            height: 32
                            scale: delTap.pressed ? 0.94 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                color: delHover.hovered ? Theme.keyTop : "transparent"
                                border.width: 1
                                border.color: delHover.hovered ? Theme.bad : Theme.line
                                Behavior on color { ColorAnimation { duration: Theme.quick } }
                                Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: "trash"
                                size: 16
                                weight: 1.8
                                tint: delHover.hovered ? Theme.bad : Theme.dim
                            }

                            HoverHandler { id: delHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { id: delTap; onTapped: page.remove(rowRect.index) }
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: flick
        visible: store.ready && store.env.length === 0
        text: "No custom variables yet \u2014 add one to get started."
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 13
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
                icon: "trash"
                enabled: store.env.length > 0
                onClicked: store.editList("env", [])
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
