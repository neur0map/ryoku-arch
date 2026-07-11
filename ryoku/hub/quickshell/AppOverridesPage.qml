pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import "Singletons"

// Per-app appearance overrides: give one app its own look, on top of the global
// Appearance. Match by class (and optionally title), then override opacity,
// corners, border, blur, shadow, dim, animations, or force it fully opaque.
// Anything left on Inherit follows the global setting. Each app becomes a single
// Hyprland window rule on Save that beats the global decoration for its windows,
// so this is the smart, non-destructive way to make Chromium opaque or a
// terminal square without touching everyone else. Edits apply on Save (window
// rules aren't live-previewed), like the Window Rules page it sits beside.
Item {
    id: page

    HyprStore { id: store }

    readonly property var offChoice: [{ "key": "inherit", "label": "Inherit" }, { "key": "off", "label": "Off" }]
    readonly property var onChoice: [{ "key": "inherit", "label": "Inherit" }, { "key": "on", "label": "On" }]

    // every mutation replaces the whole list with a new array: editList wants a
    // fresh reference and the Repeater rebuilds its cards, so text edits commit
    // on editing-finished, not per keystroke.
    function patch(i, key, val) {
        var a = store.appOverrides.slice();
        a[i] = Object.assign({}, a[i]);
        a[i][key] = val;
        store.editList("appOverrides", a);
    }
    function addApp() {
        var a = store.appOverrides.slice();
        a.push({
            "class": "", "title": "",
            "opacity": -1, "rounding": -1, "borderSize": -1,
            "blur": "inherit", "shadow": "inherit", "dim": "inherit",
            "anim": "inherit", "opaque": "inherit"
        });
        store.editList("appOverrides", a);
    }
    function removeApp(i) {
        var a = store.appOverrides.slice();
        a.splice(i, 1);
        store.editList("appOverrides", a);
    }

    HubButton {
        id: addBtn
        anchors.right: parent.right
        anchors.top: parent.top
        label: "Add app"
        icon: "plus"
        onClicked: page.addApp()
    }

    Text {
        id: intro
        anchors.left: parent.left
        anchors.right: addBtn.left
        anchors.rightMargin: 18
        anchors.verticalCenter: addBtn.verticalCenter
        wrapMode: Text.WordWrap
        text: "Give one app its own look, overriding the global Appearance. Match by class (run hyprctl clients to find it) and an optional title; anything left on Inherit follows the global setting."
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

        QQC.ScrollBar.vertical: QQC.ScrollBar {
            id: sb
            policy: QQC.ScrollBar.AsNeeded
            width: 7
            contentItem: Rectangle {
                implicitWidth: 4
                radius: Theme.radius
                color: Theme.line
                opacity: sb.pressed ? 0.9 : (sb.hovered ? 0.7 : 0.4)
                Behavior on opacity { NumberAnimation { duration: Theme.quick } }
            }
        }

        Column {
            id: col
            width: flick.width - 12
            spacing: 14

            Text {
                visible: store.appOverrides.length === 0
                width: parent.width
                topPadding: 28
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "No app overrides yet. Add an app to give it its own opacity, corners, blur, or borders."
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: 13
            }

            Repeater {
                model: store.appOverrides

                delegate: Rectangle {
                    id: card
                    required property int index
                    required property var modelData

                    width: col.width
                    height: cardCol.implicitHeight + 28
                    radius: Theme.radius
                    color: Theme.surfaceLo
                    border.width: 1
                    border.color: Theme.line

                    Column {
                        id: cardCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 14
                        spacing: 11

                        // match row: class + title + delete.
                        Item {
                            width: parent.width
                            height: 30

                            MatchField {
                                id: classField
                                anchors.left: parent.left
                                width: (parent.width - 30 - 20) / 2
                                value: card.modelData["class"] || ""
                                placeholder: "Match class (e.g. kitty)"
                                mono: true
                                onCommitted: (t) => page.patch(card.index, "class", t)
                            }
                            MatchField {
                                anchors.left: classField.right
                                anchors.leftMargin: 10
                                width: classField.width
                                value: card.modelData.title || ""
                                placeholder: "Match title (optional)"
                                onCommitted: (t) => page.patch(card.index, "title", t)
                            }
                            Item {
                                width: 30
                                height: 30
                                anchors.right: parent.right
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radius
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
                                TapHandler { onTapped: page.removeApp(card.index) }
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: Theme.line }

                        // numeric overrides: inherit or a custom value.
                        OvNum {
                            width: parent.width
                            label: "Opacity"
                            value: card.modelData.opacity
                            from: 0.2; to: 1.0; step: 0.01; percent: true; customDefault: 0.9
                            onChanged: (v) => page.patch(card.index, "opacity", v)
                        }
                        OvNum {
                            width: parent.width
                            label: "Corners"
                            value: card.modelData.rounding
                            from: 0; to: 24; step: 1; decimals: 0; customDefault: 8
                            onChanged: (v) => page.patch(card.index, "rounding", Math.round(v))
                        }
                        OvNum {
                            width: parent.width
                            label: "Border"
                            value: card.modelData.borderSize
                            from: 0; to: 8; step: 1; decimals: 0; customDefault: 2
                            onChanged: (v) => page.patch(card.index, "borderSize", Math.round(v))
                        }

                        // decoration toggles: inherit or force off (opaque forces on).
                        OvChoice {
                            width: parent.width
                            label: "Blur"
                            value: card.modelData.blur || "inherit"
                            options: page.offChoice
                            onChose: (k) => page.patch(card.index, "blur", k)
                        }
                        OvChoice {
                            width: parent.width
                            label: "Shadow"
                            value: card.modelData.shadow || "inherit"
                            options: page.offChoice
                            onChose: (k) => page.patch(card.index, "shadow", k)
                        }
                        OvChoice {
                            width: parent.width
                            label: "Dim inactive"
                            value: card.modelData.dim || "inherit"
                            options: page.offChoice
                            onChose: (k) => page.patch(card.index, "dim", k)
                        }
                        OvChoice {
                            width: parent.width
                            label: "Animations"
                            value: card.modelData.anim || "inherit"
                            options: page.offChoice
                            onChose: (k) => page.patch(card.index, "anim", k)
                        }
                        OvChoice {
                            width: parent.width
                            label: "Force opaque"
                            value: card.modelData.opaque || "inherit"
                            options: page.onChoice
                            onChose: (k) => page.patch(card.index, "opaque", k)
                        }
                    }
                }
            }
        }
    }

    // --- action bar (mirrors Window Rules) ---------------------------------
    Rectangle {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        height: 60
        radius: Theme.radius
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
                enabled: store.appOverrides.length > 0
                onClicked: store.editList("appOverrides", [])
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

    // --- inline field components -------------------------------------------

    // a bordered text field; commits on editing-finished so the list rebuild
    // never steals a keystroke.
    component MatchField: Rectangle {
        id: mf
        property string value: ""
        property string placeholder: ""
        property bool mono: false
        signal committed(string text)

        height: 30
        radius: Theme.radius
        color: Theme.surfaceLo
        border.width: 1
        border.color: mfIn.activeFocus ? Theme.ember : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }

        TextInput {
            id: mfIn
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            text: mf.value
            color: Theme.bright
            font.family: mf.mono ? Theme.mono : Theme.font
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            onEditingFinished: if (text !== mf.value) mf.committed(text)

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: mfIn.text === "" && !mfIn.activeFocus
                text: mf.placeholder
                color: Theme.faint
                font: mfIn.font
            }
        }
    }

    // label + Inherit/Custom toggle; the slider and readout appear only when a
    // custom value is chosen. changed(v) carries the new value, or -1 to inherit.
    component OvNum: Item {
        id: ov
        property string label: ""
        property real value: -1
        property real from: 0
        property real to: 1
        property real step: 0.01
        property int decimals: 2
        property bool percent: false
        property real customDefault: 0.9
        signal changed(real v)

        readonly property bool custom: ov.value >= 0
        height: 36

        Text {
            id: ovLbl
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 104
            text: ov.label
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        Segmented {
            id: ovMode
            anchors.left: ovLbl.right
            anchors.verticalCenter: parent.verticalCenter
            model: [{ "key": "inherit", "label": "Inherit" }, { "key": "custom", "label": "Custom" }]
            current: ov.custom ? "custom" : "inherit"
            onSelected: (k) => ov.changed(k === "custom" ? (ov.value >= 0 ? ov.value : ov.customDefault) : -1)
        }

        Text {
            id: ovVal
            visible: ov.custom
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 42
            horizontalAlignment: Text.AlignRight
            text: ov.percent ? Math.round(ov.value * 100) + "%" : ov.value.toFixed(ov.decimals)
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        Slider {
            visible: ov.custom
            anchors.left: ovMode.right
            anchors.leftMargin: 16
            anchors.right: ovVal.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            from: ov.from
            to: ov.to
            step: ov.step
            value: ov.value >= 0 ? ov.value : ov.from
            onMoved: (v) => ov.changed(v)
        }
    }

    // label + a small Inherit/Off (or Inherit/On) segmented.
    component OvChoice: Item {
        id: oc
        property string label: ""
        property string value: "inherit"
        property var options: []
        signal chose(string key)

        height: 34

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 104
            text: oc.label
            color: Theme.cream
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.Medium
        }

        Segmented {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            model: oc.options
            current: oc.value
            onSelected: (k) => oc.chose(k)
        }
    }
}
