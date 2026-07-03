pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import "Singletons"

// input: keyboard, pointer, touchpad, key-repeat. edited live through the
// ryoku-hub hypr backend (settings.lua applied via hyprctl eval). every
// control writes a scalar draft on the shared HyprStore and previews at
// once. Save persists + reloads. Revert / leaving restore the saved state.
// Reset returns just the input domain to shipped defaults.
Item {
    id: page

    HyprStore { id: store }

    // read by the hub to drop a live preview when this page is left.
    readonly property bool previewDirty: store.dirty

    // xkb-rules layouts, mapped to Dropdown options.
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
                        out.push({ "key": arr[i].code, "label": arr[i].name, "hint": arr[i].code });
                    page.layoutOptions = out;
                } catch (e) {}
            }
        }
    }

    // ------ layout composition ----------------------------------------------
    // kb_layout may hold "fr,us" (primary + secondary with a switch chord);
    // the two dropdowns edit the halves and recompose the comma form. The
    // variant applies to the primary layout, so a secondary keeps its slot
    // empty ("azerty," aligns variants to layouts positionally in xkb).

    function primaryLayout() { return String(store.kbLayout || "").split(",")[0]; }
    function secondaryLayout() {
        var parts = String(store.kbLayout || "").split(",");
        return parts.length > 1 ? parts[1] : "";
    }
    function primaryVariant() { return String(store.kbVariant || "").split(",")[0]; }

    function setLayouts(primary, secondary) {
        store.edit("kbLayout", secondary ? primary + "," + secondary : primary);
        var v = page.primaryVariant();
        store.edit("kbVariant", secondary && v ? v + "," : v);
    }
    function setVariant(v) {
        store.edit("kbVariant", page.secondaryLayout() && v ? v + "," : v);
    }

    // xkb variants for the primary layout, refetched when it changes. xkb
    // names repeat the language ("French (AZERTY)", "Belgian (alt.)"); inside
    // an already-chosen layout that prefix is noise, so it is stripped and the
    // qualifier alone becomes the label ("AZERTY", "alt."), code as the hint.
    property var variantOptions: [{ "key": "", "label": "Default" }]

    function variantLabel(name) {
        var m = String(name || "").match(/^[^(]+\((.+)\)$/);
        if (!m)
            return name;
        var q = m[1].trim();
        return q.charAt(0).toUpperCase() + q.slice(1);
    }

    Process {
        id: variantsProc
        property string forLayout: ""
        command: ["ryoku-hub", "hypr", "variants", forLayout]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [{ "key": "", "label": "Default" }];
                try {
                    var arr = JSON.parse(this.text);
                    for (var i = 0; i < arr.length; i++)
                        out.push({ "key": arr[i].code, "label": page.variantLabel(arr[i].name), "hint": arr[i].code });
                } catch (e) {}
                page.variantOptions = out;
            }
        }
    }
    function refreshVariants() {
        var l = page.primaryLayout();
        if (l.length === 0 || variantsProc.forLayout === l)
            return;
        variantsProc.forLayout = l;
        variantsProc.running = false;
        variantsProc.running = true;
    }
    Connections {
        target: store
        function onKbLayoutChanged() { page.refreshVariants(); }
    }
    Component.onCompleted: refreshVariants()

    // ------ curated remaps over kb_options ----------------------------------
    // Each picker owns one xkb option family; anything it doesn't recognise
    // stays in the free-text field, so power users lose nothing. All state
    // lives in the single store.kbOptions string.

    readonly property var capsIds: ["caps:escape", "ctrl:nocaps", "caps:swapescape", "caps:none"]
    readonly property var composeIds: ["compose:ralt", "compose:menu"]
    readonly property var grpIds: ["grp:alt_shift_toggle", "grp:win_space_toggle", "grp:caps_toggle"]
    readonly property string swapId: "altwin:swap_alt_win"

    function optTokens() {
        var raw = String(store.kbOptions || "").split(",");
        var out = [];
        for (var i = 0; i < raw.length; i++) {
            var t = raw[i].trim();
            if (t.length)
                out.push(t);
        }
        return out;
    }
    function pickFrom(ids) {
        var toks = page.optTokens();
        for (var i = 0; i < toks.length; i++)
            if (ids.indexOf(toks[i]) !== -1)
                return toks[i];
        return "";
    }
    function knownIds() {
        return page.capsIds.concat(page.composeIds).concat(page.grpIds).concat([page.swapId]);
    }
    function extraOptions() {
        var known = page.knownIds();
        var toks = page.optTokens();
        var out = [];
        for (var i = 0; i < toks.length; i++)
            if (known.indexOf(toks[i]) === -1)
                out.push(toks[i]);
        return out.join(",");
    }
    // rebuild kb_options with one family replaced; "" drops the family.
    function setOption(ids, value) {
        var toks = page.optTokens();
        var out = [];
        for (var j = 0; j < toks.length; j++)
            if (ids.indexOf(toks[j]) === -1)
                out.push(toks[j]);
        if (value.length)
            out.push(value);
        store.edit("kbOptions", out.join(","));
    }
    function setExtra(text) {
        var known = page.knownIds();
        var keep = [];
        var toks = page.optTokens();
        for (var i = 0; i < toks.length; i++)
            if (known.indexOf(toks[i]) !== -1)
                keep.push(toks[i]);
        var raw = String(text || "").split(",");
        for (var j = 0; j < raw.length; j++) {
            var t = raw[j].trim();
            if (t.length)
                keep.push(t);
        }
        store.edit("kbOptions", keep.join(","));
    }

    // localectl converts the X11 keymap to the nearest console keymap too, so
    // one privileged call covers the SDDM greeter AND the TTY. polkit prompts.
    property string sysApplyState: ""
    Process {
        id: sysApplyProc
        command: ["localectl", "set-x11-keymap",
            String(store.kbLayout || "us"), "",
            String(store.kbVariant || ""), String(store.kbOptions || "")]
        onExited: (code, status) => {
            page.sysApplyState = code === 0 ? "ok" : "err";
            sysApplyClear.restart();
        }
    }
    Timer {
        id: sysApplyClear
        interval: 6000
        onTriggered: page.sysApplyState = ""
    }

    // label left, entry right. commits on editing-finished (not per keystroke)
    // and re-binds to the draft on focus loss so Reset/Revert refresh the shown
    // text after a manual edit.
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
            radius: Theme.radius
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
                radius: Theme.radius
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
                    current: page.primaryLayout()
                    placeholder: page.primaryLayout()
                    onChosen: (k) => page.setLayouts(k, page.secondaryLayout())
                }
                Dropdown {
                    width: Math.min(parent.width, 460); label: "Style"
                    fieldWidth: 240
                    options: page.variantOptions
                    current: page.primaryVariant()
                    placeholder: "Default"
                    onChosen: (k) => page.setVariant(k)
                }
                Dropdown {
                    width: Math.min(parent.width, 460); label: "Second layout"
                    fieldWidth: 240
                    options: [{ "key": "", "label": "None" }].concat(page.layoutOptions)
                    current: page.secondaryLayout()
                    placeholder: "None"
                    onChosen: (k) => page.setLayouts(page.primaryLayout(), k)
                }
                ChoiceRow {
                    width: Math.min(parent.width, 460); label: "Switch layouts"
                    visible: page.secondaryLayout().length > 0
                    options: [
                        { "key": "", "label": "Off" },
                        { "key": "grp:alt_shift_toggle", "label": "Alt+Shift" },
                        { "key": "grp:win_space_toggle", "label": "Super+Space" }
                    ]
                    current: page.pickFrom(page.grpIds)
                    onChosen: (k) => page.setOption(page.grpIds, k)
                }
            }

            SettingSection {
                width: parent.width
                title: "KEY REMAPS"
                ChoiceRow {
                    width: Math.min(parent.width, 460); label: "Caps Lock"
                    options: [
                        { "key": "", "label": "Default" },
                        { "key": "caps:escape", "label": "Escape" },
                        { "key": "ctrl:nocaps", "label": "Ctrl" },
                        { "key": "caps:swapescape", "label": "Swap Esc" },
                        { "key": "caps:none", "label": "Off" }
                    ]
                    current: page.pickFrom(page.capsIds)
                    onChosen: (k) => page.setOption(page.capsIds, k)
                }
                ToggleRow {
                    width: Math.min(parent.width, 460); label: "Swap Alt and Super"
                    checked: page.pickFrom([page.swapId]) === page.swapId
                    onToggled: (v) => page.setOption([page.swapId], v ? page.swapId : "")
                }
                ChoiceRow {
                    width: Math.min(parent.width, 460); label: "Compose key"
                    options: [
                        { "key": "", "label": "Off" },
                        { "key": "compose:ralt", "label": "Right Alt" },
                        { "key": "compose:menu", "label": "Menu" }
                    ]
                    current: page.pickFrom(page.composeIds)
                    onChosen: (k) => page.setOption(page.composeIds, k)
                }
                TextFieldRow {
                    width: Math.min(parent.width, 460); label: "Extra options"
                    placeholder: "raw xkb options, comma-separated\u2026"
                    text: page.extraOptions()
                    onCommitted: (v) => page.setExtra(v)
                }
                Item {
                    width: Math.min(parent.width, 460)
                    height: 34

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - sysBtn.width - 14
                        text: page.sysApplyState === "ok" ? "Applied to login screen and console"
                            : page.sysApplyState === "err" ? "Not applied (cancelled or failed)"
                            : "Login screen and TTY keep their own keymap"
                        elide: Text.ElideRight
                        color: page.sysApplyState === "ok" ? Theme.ok
                            : page.sysApplyState === "err" ? Theme.ember : Theme.faint
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    HubButton {
                        id: sysBtn
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Apply system-wide"
                        icon: "check"
                        enabled: !store.dirty && !sysApplyProc.running
                        onClicked: sysApplyProc.running = true
                    }
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

    // --- action bar, mirrors Shell Settings ---------------------------------
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
