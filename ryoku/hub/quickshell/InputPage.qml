pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "Singletons"

// Input: keyboard, pointer, touchpad, and key-repeat behaviour, edited live
// through the ryoku-hub hypr backend (settings.lua applied via hyprctl eval).
// Every control writes a scalar draft on the shared HyprStore and previews at
// once; Save persists and reloads, Revert and leaving restore the saved state,
// and Reset returns just the input domain to its shipped defaults.
Item {
    id: page

    HyprStore { id: store }

    // Read by the hub to drop an unsaved live preview when this page is left.
    readonly property bool previewDirty: store.dirty

    // Keyboard layouts from the xkb rules base, mapped to Dropdown options.
    property var layoutOptions: []

    Process {
        id: layoutsProc
        command: ["ryoku-hub", "hypr", "layouts"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(this.text);
                    var out = [];
                    for (var i = 0; i < arr.length; i++)
                        out.push({ "key": arr[i].code, "label": arr[i].name + " (" + arr[i].code + ")" });
                    page.layoutOptions = out;
                } catch (e) {}
            }
        }
    }

    // A labelled free-text row (label left, entry right). It commits on
    // editing-finished rather than per keystroke, and re-binds to the draft on
    // focus loss so Reset/Revert refresh the shown text after a manual edit.
    component TextFieldRow: Item {
        id: tfr

        property string label: ""
        property string placeholder: ""
        property string text: ""
        signal committed(string value)

        implicitWidth: 320
        implicitHeight: 38

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - box.width - 14
            elide: Text.ElideRight
            text: tfr.label
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        Rectangle {
            id: box
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 240
            height: 30
            radius: 9
            color: Theme.surfaceLo
            border.width: 1
            border.color: entry.activeFocus ? Theme.ember : Theme.line
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

            TextInput {
                id: entry
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                text: tfr.text
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 13
                clip: true
                selectByMouse: true
                onActiveFocusChanged: {
                    if (activeFocus)
                        selectAll();
                    else
                        text = Qt.binding(() => tfr.text);
                }
                onEditingFinished: tfr.committed(text)

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: entry.text === "" && !entry.activeFocus
                    text: tfr.placeholder
                    color: Theme.faint
                    font: entry.font
                }
            }
        }
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
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
            spacing: 30

            SettingSection {
                width: parent.width
                title: "KEYBOARD"
                Dropdown {
                    width: Math.min(parent.width, 460); label: "Layout"
                    fieldWidth: 240
                    options: page.layoutOptions
                    current: store.kbLayout
                    placeholder: store.kbLayout
                    onChosen: (k) => store.edit("kbLayout", k)
                }
                TextFieldRow {
                    width: Math.min(parent.width, 460); label: "Variant"
                    placeholder: "e.g. dvorak, colemak\u2026"
                    text: store.kbVariant
                    onCommitted: (v) => store.edit("kbVariant", v)
                }
                TextFieldRow {
                    width: Math.min(parent.width, 460); label: "Options"
                    placeholder: "e.g. ctrl:nocaps, grp:alt_shift_toggle\u2026"
                    text: store.kbOptions
                    onCommitted: (v) => store.edit("kbOptions", v)
                }
            }

            SettingSection {
                width: parent.width
                title: "POINTER"
                SliderRow {
                    width: Math.min(parent.width, 460); label: "Sensitivity"
                    from: -1; to: 1; step: 0.05; decimals: 2
                    value: store.sensitivity
                    onModified: (v) => store.edit("sensitivity", v)
                }
                ChoiceRow {
                    width: Math.min(parent.width, 460); label: "Follow mouse"
                    options: [{ "key": "0", "label": "Off" }, { "key": "1", "label": "Normal" }, { "key": "2", "label": "Loose" }]
                    current: String(store.followMouse)
                    onChosen: (k) => store.edit("followMouse", parseInt(k))
                }
                ChoiceRow {
                    width: Math.min(parent.width, 460); label: "Acceleration"
                    options: [{ "key": "", "label": "Default" }, { "key": "flat", "label": "Flat" }, { "key": "adaptive", "label": "Adaptive" }]
                    current: store.accelProfile
                    onChosen: (k) => store.edit("accelProfile", k)
                }
            }

            SettingSection {
                width: parent.width
                title: "TOUCHPAD"
                ToggleRow {
                    width: Math.min(parent.width, 460); label: "Natural scroll"
                    checked: store.naturalScroll
                    onToggled: (v) => store.edit("naturalScroll", v)
                }
                ToggleRow {
                    width: Math.min(parent.width, 460); label: "Tap to click"
                    checked: store.tapToClick
                    onToggled: (v) => store.edit("tapToClick", v)
                }
                ToggleRow {
                    width: Math.min(parent.width, 460); label: "Disable while typing"
                    checked: store.disableWhileTyping
                    onToggled: (v) => store.edit("disableWhileTyping", v)
                }
                ToggleRow {
                    width: Math.min(parent.width, 460); label: "Swipe between workspaces"
                    checked: store.workspaceSwipe
                    onToggled: (v) => store.edit("workspaceSwipe", v)
                }
                ChoiceRow {
                    width: Math.min(parent.width, 460); label: "Swipe fingers"
                    visible: store.workspaceSwipe
                    options: [{ "key": "3", "label": "3" }, { "key": "4", "label": "4" }]
                    current: String(store.swipeFingers)
                    onChosen: (k) => store.edit("swipeFingers", parseInt(k, 10))
                }
            }

            SettingSection {
                width: parent.width
                title: "KEY REPEAT"
                NumberField {
                    width: Math.min(parent.width, 460); label: "Repeat rate"; unit: "/s"
                    from: 1; to: 100; value: store.repeatRate
                    onModified: (v) => store.edit("repeatRate", v)
                }
                NumberField {
                    width: Math.min(parent.width, 460); label: "Repeat delay"; unit: "ms"
                    from: 100; to: 2000; step: 50; value: store.repeatDelay
                    onModified: (v) => store.edit("repeatDelay", v)
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
            text: store.dirty ? "Previewing unsaved changes" : "Saved \u00b7 live on your desktop"
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
                label: "Reset to defaults"
                icon: "refresh"
                onClicked: store.resetInput()
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
