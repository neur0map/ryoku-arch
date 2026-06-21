pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"

// Custom Hyprland layer rules: tweak layer-shell surfaces (bars, launchers,
// notification daemons) by namespace. Edited as a list through the shared
// HyprStore; like window rules they are not previewed live but apply on Save.
Item {
    id: page

    HyprStore { id: store }

    readonly property var actionOptions: [
        { "key": "blur", "label": "Blur" },
        { "key": "blurpopups", "label": "Blur popups" },
        { "key": "noanim", "label": "No animation" },
        { "key": "noshadow", "label": "No shadow" },
        { "key": "ignorealpha", "label": "Ignore alpha" },
        { "key": "dimaround", "label": "Dim around" }
    ]
    readonly property var valueActions: ["ignorealpha", "dimaround"]

    function patch(i, key, val) {
        var a = store.layerRules.slice();
        a[i] = Object.assign({}, a[i]);
        a[i][key] = val;
        store.editList("layerRules", a);
    }
    function addRule() {
        var a = store.layerRules.slice();
        a.push({ "namespace": "", "action": "blur", "value": "" });
        store.editList("layerRules", a);
    }
    function removeRule(i) {
        var a = store.layerRules.slice();
        a.splice(i, 1);
        store.editList("layerRules", a);
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
        text: "Rules for layer-shell surfaces, matched by namespace (e.g. the bar, a launcher). Advanced: a wrong namespace simply matches nothing."
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
                visible: store.layerRules.length === 0
                width: parent.width
                topPadding: 28
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "No custom layer rules yet."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 13
            }

            Repeater {
                model: store.layerRules

                delegate: Rectangle {
                    id: lrow
                    required property int index
                    required property var modelData

                    readonly property bool needsValue: page.valueActions.indexOf(lrow.modelData.action) >= 0
                    readonly property string valueHint: lrow.modelData.action === "ignorealpha" ? "0.0-1.0"
                        : lrow.modelData.action === "dimaround" ? "0.0-1.0" : ""
                    readonly property real gap: 10
                    readonly property real ddW: 160
                    readonly property real valW: 110
                    readonly property real nsW: width - 24 - ddW - 30
                        - gap * (needsValue ? 3 : 2) - (needsValue ? valW : 0)

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
                        spacing: lrow.gap

                        Rectangle {
                            width: lrow.nsW
                            height: 30
                            radius: 9
                            color: Theme.surfaceLo
                            border.width: 1
                            border.color: nsInput.activeFocus ? Theme.ember : Theme.line
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            TextInput {
                                id: nsInput
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                verticalAlignment: TextInput.AlignVCenter
                                text: lrow.modelData.namespace || ""
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onEditingFinished: {
                                    if (text !== (lrow.modelData.namespace || ""))
                                        page.patch(lrow.index, "namespace", text);
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: nsInput.text === "" && !nsInput.activeFocus
                                    text: "Namespace"
                                    color: Theme.faint
                                    font: nsInput.font
                                }
                            }
                        }

                        Dropdown {
                            width: lrow.ddW
                            height: 30
                            fieldWidth: lrow.ddW
                            options: page.actionOptions
                            current: lrow.modelData.action
                            onChosen: (k) => page.patch(lrow.index, "action", k)
                        }

                        Rectangle {
                            visible: lrow.needsValue
                            width: lrow.valW
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
                                text: lrow.modelData.value || ""
                                color: Theme.bright
                                font.family: Theme.mono
                                font.pixelSize: 13
                                clip: true
                                selectByMouse: true
                                onEditingFinished: {
                                    if (text !== (lrow.modelData.value || ""))
                                        page.patch(lrow.index, "value", text);
                                }

                                Text {
                                    anchors.fill: parent
                                    verticalAlignment: Text.AlignVCenter
                                    visible: valInput.text === "" && !valInput.activeFocus
                                    text: lrow.valueHint
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
                            TapHandler { onTapped: page.removeRule(lrow.index) }
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
                enabled: store.layerRules.length > 0
                onClicked: store.editList("layerRules", [])
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
