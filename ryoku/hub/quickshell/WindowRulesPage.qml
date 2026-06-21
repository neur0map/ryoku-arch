pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"

// Custom Hyprland window rules layered over the ones Ryoku ships, edited as a
// list through the shared HyprStore. Each row matches a window by class and/or
// title and applies one action (a few actions carry a typed value). List edits
// are not previewed live: they apply on Save, so add/edit/delete all rebuild the
// draft array and go through store.editList with a fresh reference.
Item {
    id: page

    HyprStore { id: store }

    readonly property var actionOptions: [
        { "key": "float", "label": "Float" },
        { "key": "tile", "label": "Tile" },
        { "key": "pin", "label": "Pin" },
        { "key": "fullscreen", "label": "Fullscreen" },
        { "key": "center", "label": "Center" },
        { "key": "noblur", "label": "No blur" },
        { "key": "noborder", "label": "No border" },
        { "key": "noshadow", "label": "No shadow" },
        { "key": "opacity", "label": "Opacity" },
        { "key": "size", "label": "Size (WxH)" },
        { "key": "move", "label": "Move (XxY)" },
        { "key": "workspace", "label": "Workspace" }
    ]
    // Actions whose effect needs a free-form value the user types in.
    readonly property var valueActions: ["opacity", "size", "move", "workspace"]

    // Every mutation replaces the whole list with a new array: editList needs a
    // fresh reference and the Repeater rebuilds its rows on each change, so text
    // edits are committed on editing-finished, never per keystroke.
    function patch(i, key, val) {
        var a = store.windowRules.slice();
        a[i] = Object.assign({}, a[i]);
        a[i][key] = val;
        store.editList("windowRules", a);
    }
    function addRule() {
        var a = store.windowRules.slice();
        a.push({ "class": "", "title": "", "action": "float", "value": "" });
        store.editList("windowRules", a);
    }
    function removeRule(i) {
        var a = store.windowRules.slice();
        a.splice(i, 1);
        store.editList("windowRules", a);
    }

    HubButton {
        id: addBtn
        anchors.right: parent.right
        anchors.top: parent.top
        label: "Add rule"
        icon: "plus"
        onClicked: page.addRule()
    }

    Text {
        id: intro
        anchors.left: parent.left
        anchors.right: addBtn.left
        anchors.rightMargin: 18
        anchors.verticalCenter: addBtn.verticalCenter
        wrapMode: Text.WordWrap
        text: "Custom window rules layered over the ones Ryoku ships. Match by class and/or title, then pick an action."
        color: Theme.subtle
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: addBtn.bottom
        anchors.topMargin: 22
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
            spacing: 12

            Text {
                visible: store.windowRules.length === 0
                width: parent.width
                topPadding: 28
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "No custom rules yet. Add one to override how a specific window opens."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 13
            }

            Repeater {
                model: store.windowRules

                delegate: Rectangle {
                    id: rrow
                    required property int index
                    required property var modelData

                    readonly property bool needsValue: page.valueActions.indexOf(rrow.modelData.action) >= 0
                    readonly property string valueHint: {
                        var a = rrow.modelData.action;
                        return a === "opacity" ? "0.0-1.0"
                            : a === "size" ? "1500x850"
                            : a === "move" ? "100x100"
                            : a === "workspace" ? "3" : "";
                    }
                    // Fixed widths for the action/value/delete cluster; the two
                    // match fields split whatever space is left.
                    readonly property real gap: 10
                    readonly property real ddW: 150
                    readonly property real valW: 110
                    readonly property real tfW: (width - 24 - ddW - 30
                        - gap * (needsValue ? 4 : 3) - (needsValue ? valW : 0)) / 2

                    width: col.width
                    height: 56
                    radius: 12
                    color: Theme.surfaceLo
                    border.width: 1
                    border.color: Theme.line

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: rrow.gap

                        Rectangle {
                            width: rrow.tfW
                            height: 30
                            radius: 9
                            color: Theme.surfaceLo
                            border.width: 1
                            border.color: classInput.activeFocus ? Theme.ember : Theme.line
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            TextInput {
                                id: classInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                text: rrow.modelData["class"] || ""
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onEditingFinished: {
                                    if (text !== (rrow.modelData["class"] || ""))
                                        page.patch(rrow.index, "class", text);
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: classInput.text === "" && !classInput.activeFocus
                                    text: "Match class"
                                    color: Theme.faint
                                    font: classInput.font
                                }
                            }
                        }

                        Rectangle {
                            width: rrow.tfW
                            height: 30
                            radius: 9
                            color: Theme.surfaceLo
                            border.width: 1
                            border.color: titleInput.activeFocus ? Theme.ember : Theme.line
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            TextInput {
                                id: titleInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                text: rrow.modelData.title || ""
                                color: Theme.bright
                                font.family: Theme.font
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onEditingFinished: {
                                    if (text !== (rrow.modelData.title || ""))
                                        page.patch(rrow.index, "title", text);
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: titleInput.text === "" && !titleInput.activeFocus
                                    text: "Match title"
                                    color: Theme.faint
                                    font: titleInput.font
                                }
                            }
                        }

                        Dropdown {
                            width: rrow.ddW
                            height: 30
                            fieldWidth: rrow.ddW
                            options: page.actionOptions
                            current: rrow.modelData.action
                            onChosen: (k) => page.patch(rrow.index, "action", k)
                        }

                        Rectangle {
                            visible: rrow.needsValue
                            width: rrow.valW
                            height: 30
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
                                text: rrow.modelData.value || ""
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onEditingFinished: {
                                    if (text !== (rrow.modelData.value || ""))
                                        page.patch(rrow.index, "value", text);
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: valInput.text === "" && !valInput.activeFocus
                                    text: rrow.valueHint
                                    color: Theme.faint
                                    font: valInput.font
                                }
                            }
                        }

                        Item {
                            id: delBtn
                            width: 30
                            height: 30

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: delHov.hovered ? Qt.rgba(Theme.bad.r, Theme.bad.g, Theme.bad.b, 0.12) : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.quick } }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: "trash"
                                size: 17
                                tint: delHov.hovered ? Theme.bad : Theme.dim
                                Behavior on tint { ColorAnimation { duration: Theme.quick } }
                            }

                            HoverHandler { id: delHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: page.removeRule(rrow.index) }
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
                icon: "trash"
                enabled: store.windowRules.length > 0
                onClicked: store.editList("windowRules", [])
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
