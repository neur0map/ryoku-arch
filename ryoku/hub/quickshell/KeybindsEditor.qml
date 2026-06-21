pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"

// Custom keybinds editor: user shortcuts layered over the shipped binds. Each row
// is a key combo plus an action (run a command, or a window dispatcher). They are
// written to settings.lua and applied on Save. The shared store persists them.
Item {
    id: page

    HyprStore { id: store }

    readonly property var actionOpts: [
        { "key": "exec", "label": "Run command" },
        { "key": "close", "label": "Close window" },
        { "key": "fullscreen", "label": "Fullscreen" },
        { "key": "togglefloating", "label": "Toggle floating" }
    ]

    function patch(i, key, val) {
        var a = store.keybinds.slice();
        a[i] = Object.assign({}, a[i]);
        a[i][key] = val;
        store.editList("keybinds", a);
    }
    function remove(i) {
        var a = store.keybinds.slice();
        a.splice(i, 1);
        store.editList("keybinds", a);
    }
    function add() {
        var a = store.keybinds.slice();
        a.push({ "keys": "", "action": "exec", "value": "" });
        store.editList("keybinds", a);
    }

    Text {
        id: intro
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        wrapMode: Text.WordWrap
        text: "Custom shortcuts layered over the ones Ryoku ships. Write the combo the way Hyprland does, e.g. SUPER + J or SUPER + SHIFT + Return."
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 12
    }

    HubButton {
        id: addBtn
        anchors.left: parent.left
        anchors.top: intro.bottom
        anchors.topMargin: 14
        label: "Add shortcut"
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
            }
        }

        Column {
            id: rows
            width: flick.width - 12
            spacing: 10

            Text {
                visible: store.keybinds.length === 0
                text: "No custom shortcuts yet."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 13
            }

            Repeater {
                model: store.keybinds

                delegate: Rectangle {
                    id: rowItem
                    required property int index
                    required property var modelData
                    readonly property bool needsValue: rowItem.modelData.action === "exec" || rowItem.modelData.action === undefined
                    width: rows.width
                    height: 56
                    radius: 12
                    color: Theme.surfaceLo
                    border.width: 1
                    border.color: Theme.line

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 10

                        // key combo
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 200
                            height: 32
                            radius: 9
                            color: Theme.surface
                            border.width: 1
                            border.color: keysIn.activeFocus ? Theme.ember : Theme.line
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            TextInput {
                                id: keysIn
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                text: rowItem.modelData.keys
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                clip: true
                                selectByMouse: true
                                onEditingFinished: page.patch(rowItem.index, "keys", text)

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: keysIn.text === "" && !keysIn.activeFocus
                                    text: "SUPER + J"
                                    color: Theme.faint
                                    font: keysIn.font
                                }
                            }
                        }

                        Dropdown {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 230
                            fieldWidth: 150
                            label: ""
                            options: page.actionOpts
                            current: rowItem.modelData.action || "exec"
                            onChosen: (k) => page.patch(rowItem.index, "action", k)
                        }

                        // command (exec only)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 200 - 230 - delBtn.width - 40
                            height: 32
                            radius: 9
                            visible: rowItem.needsValue
                            color: Theme.surface
                            border.width: 1
                            border.color: valIn.activeFocus ? Theme.ember : Theme.line
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            TextInput {
                                id: valIn
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                text: rowItem.modelData.value
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onEditingFinished: page.patch(rowItem.index, "value", text)

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: valIn.text === "" && !valIn.activeFocus
                                    text: "command to run"
                                    color: Theme.faint
                                    font: valIn.font
                                }
                            }
                        }
                    }

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
                }
            }
        }
    }

    // --- action bar ---------------------------------------------------------
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
            id: dot
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 9; height: 9; radius: 4.5
            color: store.dirty ? Theme.ember : Theme.ok
        }
        Text {
            anchors.left: dot.right
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            text: store.dirty ? "Unsaved shortcuts" : "Saved"
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
                onClicked: store.editList("keybinds", [])
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
