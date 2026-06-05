pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.ambxst.modules.theme
import qs.ambxst.modules.components
import qs.ambxst.config
import "../../../../config/KeybindActions.js" as KeybindActions

Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2

    property string currentCategory: "ambxst"

    Process {
        id: unbindProcess
    }

    function unbindKeybind(bind) {
        if (!bind)
            return;

        if (bind.keys && bind.keys.length > 0) {
            for (let k = 0; k < bind.keys.length; k++) {
                const keyObj = bind.keys[k];
                const mods = keyObj.modifiers && keyObj.modifiers.length > 0 ? keyObj.modifiers.join(" ") : "";
                const key = keyObj.key || "";
                const command = `axctl config unbind-key ${mods},${key}`;
                console.log("BindsPanel: Unbinding keybind:", command);
                unbindProcess.command = ["sh", "-c", command];
                unbindProcess.running = true;
            }
        } else {
            const mods = bind.modifiers && bind.modifiers.length > 0 ? bind.modifiers.join(" ") : "";
            const key = bind.key || "";
            const command = `axctl config unbind-key ${mods},${key}`;
            console.log("BindsPanel: Unbinding keybind:", command);
            unbindProcess.command = ["sh", "-c", command];
            unbindProcess.running = true;
        }
    }

    property bool editMode: false
    property int editingIndex: -1
    property var editingBind: null
    property bool isEditingAmbxst: false
    property bool isCreatingNew: false

    property string editName: ""
    property var editKeys: []  // Array of { modifiers: [], key: "" }
    property var editActions: []  // Array of { id: "", args: {}, layouts: [] }
    property int currentKeyPage: 0
    property int currentActionPage: 0

    // Current key being edited (derived from editKeys[currentKeyPage])
    property var editModifiers: editKeys.length > currentKeyPage ? (editKeys[currentKeyPage].modifiers || []) : []
    property string editKey: editKeys.length > currentKeyPage ? (editKeys[currentKeyPage].key || "") : ""

    // Current action being edited (derived from editActions[currentActionPage])
    property string editActionId: editActions.length > currentActionPage ? (editActions[currentActionPage].id || "") : ""
    property var editActionArgs: editActions.length > currentActionPage ? (editActions[currentActionPage].args || {}) : ({})
    property var editLayouts: editActions.length > currentActionPage ? (editActions[currentActionPage].layouts || []) : []
    readonly property var actionOptions: {
        const options = KeybindActions.getActionOptions();
        if (editActionId === "legacy.dispatcher") {
            return options.concat([{ id: "legacy.dispatcher", label: "Legacy Dispatcher", category: "Advanced" }]);
        }
        return options;
    }
    readonly property var editActionFields: KeybindActions.getActionFields(editActionId)

    readonly property var availableModifiers: ["SUPER", "SHIFT", "CTRL", "ALT"]
    readonly property var availableLayouts: ["dwindle", "master", "scrolling"]

    function updateCurrentKey(modifiers, key) {
        if (editKeys.length <= currentKeyPage)
            return;
        let newKeys = [];
        for (let i = 0; i < editKeys.length; i++) {
            if (i === currentKeyPage) {
                newKeys.push({
                    "modifiers": modifiers,
                    "key": key
                });
            } else {
                newKeys.push(editKeys[i]);
            }
        }
        editKeys = newKeys;
    }

    function updateCurrentAction(actionId, args, layouts) {
        if (editActions.length <= currentActionPage)
            return;
        let newActions = [];
        for (let i = 0; i < editActions.length; i++) {
            if (i === currentActionPage) {
                newActions.push({
                    "id": actionId,
                    "args": args,
                    "layouts": layouts
                });
            } else {
                newActions.push(editActions[i]);
            }
        }
        editActions = newActions;
    }

    function updateCurrentActionArg(key, value) {
        if (editActions.length <= currentActionPage)
            return;
        const current = editActions[currentActionPage] || {};
        let nextArgs = {};
        const currentArgs = current.args || {};
        for (const k in currentArgs) {
            nextArgs[k] = currentArgs[k];
        }
        nextArgs[key] = value;
        updateCurrentAction(current.id || "", nextArgs, current.layouts || []);
    }

    function setCurrentAction(actionId) {
        const current = editActions.length > currentActionPage ? editActions[currentActionPage] : {};
        updateCurrentAction(actionId, KeybindActions.defaultArgs(actionId), current.layouts || []);
    }

    function getActionIndex(actionId) {
        for (let i = 0; i < actionOptions.length; i++) {
            if (actionOptions[i].id === actionId)
                return i;
        }
        return -1;
    }

    function getActionLabel(actionId) {
        for (let i = 0; i < actionOptions.length; i++) {
            if (actionOptions[i].id === actionId)
                return actionOptions[i].label;
        }
        return "";
    }

    function hasLayout(layout) {
        const layouts = root.editLayouts;
        if (!layouts || layouts.length === 0)
            return false;
        return layouts.indexOf(layout) !== -1;
    }

    function toggleLayout(layout) {
        if (root.editActions.length <= root.currentActionPage)
            return;

        const currentAction = root.editActions[root.currentActionPage];
        let layouts = currentAction.layouts ? currentAction.layouts.slice() : [];

        const idx = layouts.indexOf(layout);
        if (idx !== -1) {
            layouts.splice(idx, 1);
        } else {
            layouts.push(layout);
        }

        updateCurrentAction(currentAction.id || "", currentAction.args || {}, layouts);
    }

    function addKeyPage() {
        let newKeys = editKeys.slice();
        newKeys.push({
            "modifiers": ["SUPER"],
            "key": ""
        });
        editKeys = newKeys;
        currentKeyPage = newKeys.length - 1;
    }

    function removeKeyPage() {
        if (editKeys.length <= 1)
            return;
        let newKeys = [];
        for (let i = 0; i < editKeys.length; i++) {
            if (i !== currentKeyPage) {
                newKeys.push(editKeys[i]);
            }
        }
        editKeys = newKeys;
        if (currentKeyPage >= newKeys.length) {
            currentKeyPage = newKeys.length - 1;
        }
    }

    function addActionPage() {
        let newActions = editActions.slice();
        newActions.push({
            "id": "command.run",
            "args": KeybindActions.defaultArgs("command.run"),
            "layouts": []
        });
        editActions = newActions;
        currentActionPage = newActions.length - 1;
    }

    function removeActionPage() {
        if (editActions.length <= 1)
            return;
        let newActions = [];
        for (let i = 0; i < editActions.length; i++) {
            if (i !== currentActionPage) {
                newActions.push(editActions[i]);
            }
        }
        editActions = newActions;
        if (currentActionPage >= newActions.length) {
            currentActionPage = newActions.length - 1;
        }
    }

    function openEditDialog(bind, index, isAmbxst) {
        root.editingIndex = index;
        root.editingBind = bind;
        root.isEditingAmbxst = isAmbxst;

        if (isAmbxst) {
            const bindData = bind.bind;
            root.editName = "";
            root.editKeys = [
                {
                    "modifiers": bindData.modifiers ? bindData.modifiers.slice() : [],
                    "key": bindData.key || ""
                }
            ];
            const action = KeybindActions.ensureAction(bindData.action || bindData);
            root.editActions = [
                Object.assign({ layouts: [] }, action)
            ];
        } else {
            root.editName = bind.name || "";
            if (bind.keys && bind.actions) {
                root.editKeys = JSON.parse(JSON.stringify(bind.keys));
                root.editActions = bind.actions.map(action => {
                    const fixed = KeybindActions.ensureAction(action);
                    fixed.layouts = action.layouts || [];
                    return fixed;
                });
            } else {
                root.editKeys = [
                    {
                        "modifiers": bind.modifiers ? bind.modifiers.slice() : [],
                        "key": bind.key || ""
                    }
                ];
                const action = KeybindActions.ensureAction(bind);
                root.editActions = [
                    Object.assign({ layouts: [] }, action)
                ];
            }
        }

        root.currentKeyPage = 0;
        root.currentActionPage = 0;

        editFlickable.contentY = 0;

        root.editMode = true;
    }

    function closeEditDialog() {
        root.editMode = false;
        root.isCreatingNew = false;
        root.currentKeyPage = 0;
        root.currentActionPage = 0;
    }

    function hasModifier(mod) {
        const currentMods = root.editKeys.length > root.currentKeyPage ? (root.editKeys[root.currentKeyPage].modifiers || []) : [];
        return currentMods.indexOf(mod) !== -1;
    }

    function toggleModifier(mod) {
        if (root.editKeys.length <= root.currentKeyPage)
            return;

        let currentMods = root.editKeys[root.currentKeyPage].modifiers || [];
        let newMods = [];
        let found = false;
        for (let i = 0; i < currentMods.length; i++) {
            if (currentMods[i] === mod) {
                found = true;
            } else {
                newMods.push(currentMods[i]);
            }
        }
        if (!found) {
            newMods.push(mod);
        }
        updateCurrentKey(newMods, root.editKeys[root.currentKeyPage].key || "");
    }

    function saveEdit() {
        if (root.isEditingAmbxst) {
            const path = root.editingBind.path.split(".");
            
            const adapter = Config.keybindsLoader.adapter;
            if (adapter && adapter.ambxst) {
                let bindObj = null;
                if (path.length === 2) {
                    bindObj = adapter.ambxst[path[1]];
                } else if (path.length === 3) {
                    bindObj = adapter.ambxst[path[1]][path[2]];
                }

                if (bindObj) {
                    const firstKey = root.editKeys.length > 0 ? root.editKeys[0] : {
                        modifiers: [],
                        key: ""
                    };
                    bindObj.modifiers = firstKey.modifiers || [];
                    bindObj.key = firstKey.key || "";
                    bindObj.action = root.editActions[0];
                }
            }
        } else if (root.isCreatingNew) {
            const customBinds = Config.keybindsLoader.adapter.custom || [];
            let newBinds = customBinds.slice();
            const newBind = {
                "name": root.editName,
                "keys": root.editKeys,
                "actions": root.editActions,
                "enabled": true
            };
            newBinds.push(newBind);
            Config.keybindsLoader.adapter.custom = newBinds;
        } else {
            const customBinds = Config.keybindsLoader.adapter.custom;
            if (customBinds && customBinds[root.editingIndex]) {
                let newBinds = [];
                for (let i = 0; i < customBinds.length; i++) {
                    if (i === root.editingIndex) {
                        let updatedBind = {
                            "name": root.editName,
                            "keys": root.editKeys,
                            "actions": root.editActions,
                            "enabled": customBinds[i].enabled !== false
                        };
                        newBinds.push(updatedBind);
                    } else {
                        newBinds.push(customBinds[i]);
                    }
                }
                Config.keybindsLoader.adapter.custom = newBinds;
            }
        }

        root.editMode = false;
        root.isCreatingNew = false;
        root.currentKeyPage = 0;
        root.currentActionPage = 0;
    }

    readonly property var categories: [
        {
            id: "ambxst",
            label: "Ambxst",
            icon: Icons.widgets
        },
        {
            id: "custom",
            label: "Custom",
            icon: Icons.gear
        }
    ]

    function formatModifiers(modifiers) {
        if (!modifiers || modifiers.length === 0)
            return "";
        return modifiers.join(" + ");
    }

    function formatSingleKey(keyObj) {
        const mods = formatModifiers(keyObj.modifiers);
        return mods ? mods + " + " + keyObj.key : keyObj.key;
    }

    function formatKeybind(bind) {
        if (bind.keys && bind.keys.length > 0) {
            let formatted = [];
            for (let i = 0; i < bind.keys.length; i++) {
                formatted.push(formatSingleKey(bind.keys[i]));
            }
            return formatted.join(", ");
        }
        const mods = formatModifiers(bind.modifiers);
        return mods ? mods + " + " + bind.key : bind.key;
    }

    function getAmbxstBinds() {
        const adapter = Config.keybindsLoader.adapter;
        if (!adapter || !adapter.ambxst)
            return [];

        const binds = [];
        const ambxst = adapter.ambxst;

        const coreKeys = ["launcher", "dashboard", "assistant", "clipboard", "emoji", "notes", "tmux", "wallpapers"];
        for (const key of coreKeys) {
            if (ambxst[key]) {
                binds.push({
                    category: "Ambxst",
                    name: key.charAt(0).toUpperCase() + key.slice(1),
                    path: "ambxst." + key,
                    bind: ambxst[key]
                });
            }
        }

        if (ambxst.system) {
            const systemKeys = ["overview", "powermenu", "config", "lockscreen", "tools", "screenshot", "screenrecord", "lens", "reload", "quit"];
            for (const key of systemKeys) {
                if (ambxst.system[key]) {
                    binds.push({
                        category: "System",
                        name: key.charAt(0).toUpperCase() + key.slice(1),
                        path: "ambxst.system." + key,
                        bind: ambxst.system[key]
                    });
                }
            }
        }

        return binds;
    }

    function getCustomBinds() {
        const adapter = Config.keybindsLoader.adapter;
        if (!adapter || !adapter.custom)
            return [];
        return adapter.custom;
    }

    function addNewBind() {
            const newBind = {
                "name": "",
                "keys": [
                    {
                        "modifiers": ["SUPER"],
                        "key": ""
                    }
                ],
                "actions": [
                    {
                        "id": "command.run",
                        "args": KeybindActions.defaultArgs("command.run"),
                        "layouts": []
                    }
                ],
                "enabled": true
            };

        root.currentCategory = "custom";

        scrollToBottomTimer.start();

        root.isCreatingNew = true;
        root.openEditDialog(newBind, -1, false);
    }

    function deleteBind(index) {
        const customBinds = Config.keybindsLoader.adapter.custom;
        if (!customBinds || index < 0 || index >= customBinds.length)
            return;

        const bindToDelete = customBinds[index];
        unbindKeybind(bindToDelete);

        let newBinds = [];
        for (let i = 0; i < customBinds.length; i++) {
            if (i !== index) {
                newBinds.push(customBinds[i]);
            }
        }
        Config.keybindsLoader.adapter.custom = newBinds;
        root.editMode = false;
    }

    Timer {
        id: scrollToBottomTimer
        interval: 50
        onTriggered: {
            mainFlickable.contentY = mainFlickable.contentHeight - mainFlickable.height;
        }
    }

    ColumnLayout {
        id: fixedHeader
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8
        z: 10

        opacity: root.editMode ? 0 : 1
        transform: Translate {
            x: root.editMode ? -30 : 0

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutQuart
                }
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuart
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: titlebar.height

            PanelTitlebar {
                id: titlebar
                width: root.contentWidth
                anchors.horizontalCenter: parent.horizontalCenter
                title: "Keybinds"
                statusText: ""

                actions: [
                    {
                        icon: Icons.plus,
                        tooltip: "Add keybind",
                        onClicked: function () {
                            root.addNewBind();
                        }
                    },
                    {
                        icon: Icons.sync,
                        tooltip: "Reload binds",
                        onClicked: function () {
                            Config.keybindsLoader.reload();
                        }
                    }
                ]
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: categoryRow.height

            Row {
                id: categoryRow
                width: root.contentWidth
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Repeater {
                    model: root.categories

                    delegate: StyledRect {
                        id: categoryTag
                        required property var modelData
                        required property int index

                        property bool isSelected: root.currentCategory === modelData.id
                        property bool isHovered: false

                        variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                        enableShadow: true
                        width: categoryContent.width + 32
                        height: 36
                        radius: Styling.radius(-2)

                        Row {
                            id: categoryContent
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: categoryTag.modelData.icon
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: categoryTag.item
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: categoryTag.modelData.label
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                font.weight: categoryTag.isSelected ? Font.Bold : Font.Normal
                                color: categoryTag.item
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: categoryTag.isHovered = true
                            onExited: categoryTag.isHovered = false
                            onClicked: root.currentCategory = categoryTag.modelData.id
                        }
                    }
                }
            }
        }
    }

    Flickable {
        id: mainFlickable
        anchors.top: fixedHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !root.editMode

        opacity: root.editMode ? 0 : 1
        transform: Translate {
            x: root.editMode ? -30 : 0

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutQuart
                }
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuart
            }
        }

        ColumnLayout {
            id: contentColumn
            width: root.contentWidth
            x: root.sideMargin
            spacing: 4

            Repeater {
                id: ambxstRepeater
                model: root.currentCategory === "ambxst" ? root.getAmbxstBinds() : []

                delegate: BindItem {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    bindName: modelData.name
                    keybindText: root.formatKeybind(modelData.bind)
                    dispatcher: KeybindActions.describeAction(modelData.bind.action || modelData.bind)
                    argument: ""
                    isAmbxst: true

                    onEditRequested: {
                        root.openEditDialog(modelData, index, true);
                    }
                }
            }

            Repeater {
                id: customRepeater
                model: root.currentCategory === "custom" ? root.getCustomBinds() : []

                delegate: BindItem {
                    required property var modelData
                    required property int index

                    readonly property string firstDispatcher: modelData.actions && modelData.actions.length > 0 ? KeybindActions.describeAction(modelData.actions[0]) : KeybindActions.describeAction(modelData)
                    readonly property string firstArgument: ""

                    function getUniqueLayouts() {
                        if (!modelData.actions || modelData.actions.length === 0)
                            return [];
                        let allLayouts = [];
                        for (let i = 0; i < modelData.actions.length; i++) {
                            const action = modelData.actions[i];
                            if (action.layouts) {
                                for (let j = 0; j < action.layouts.length; j++) {
                                    const layout = action.layouts[j];
                                    if (allLayouts.indexOf(layout) === -1) {
                                        allLayouts.push(layout);
                                    }
                                }
                            }
                        }
                        return allLayouts;
                    }

                    Layout.fillWidth: true
                    customName: modelData.name || ""
                    bindName: firstDispatcher
                    keybindText: root.formatKeybind(modelData)
                    dispatcher: firstDispatcher
                    argument: firstArgument
                    isEnabled: modelData.enabled !== false
                    isAmbxst: false
                    layouts: getUniqueLayouts()

                    onToggleEnabled: {
                        const customBinds = Config.keybindsLoader.adapter.custom;
                        if (customBinds && customBinds[index]) {
                            let newBinds = [];
                            for (let i = 0; i < customBinds.length; i++) {
                                if (i === index) {
                                    let updatedBind = JSON.parse(JSON.stringify(customBinds[i]));
                                    updatedBind.enabled = !isEnabled;
                                    newBinds.push(updatedBind);
                                } else {
                                    newBinds.push(customBinds[i]);
                                }
                            }
                            Config.keybindsLoader.adapter.custom = newBinds;
                        }
                    }

                    onEditRequested: {
                        root.openEditDialog(modelData, index, false);
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 20
                visible: (root.currentCategory === "ambxst" && ambxstRepeater.count === 0) || (root.currentCategory === "custom" && customRepeater.count === 0)
                text: root.currentCategory === "ambxst" ? "No Ambxst binds configured" : "No custom binds configured"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overSurfaceVariant
            }
        }
    }

    Item {
        id: editContainer
        anchors.fill: parent
        clip: true
        z: 100

        opacity: root.editMode ? 1 : 0
        visible: opacity > 0
        transform: Translate {
            x: root.editMode ? 0 : 30

            Behavior on x {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                    easing.type: Easing.OutQuart
                }
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuart
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.editMode
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            propagateComposedEvents: false
            onPressed: event => event.accepted = true
            onReleased: event => event.accepted = true
            onClicked: event => event.accepted = true
            onWheel: event => event.accepted = true
        }

        Flickable {
            id: editFlickable
            anchors.fill: parent
            contentHeight: editContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: editContent
                width: editFlickable.width
                spacing: 8

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: editTitlebar.height

                    RowLayout {
                        id: editTitlebar
                        width: root.contentWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        StyledRect {
                            id: backButton
                            variant: backButtonArea.containsMouse ? "focus" : "common"
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: Styling.radius(-2)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.caretLeft
                                font.family: Icons.font
                                font.pixelSize: 16
                                color: backButton.item
                            }

                            MouseArea {
                                id: backButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.closeEditDialog()
                            }
                        }

                        Text {
                            text: root.isCreatingNew ? "New Keybind" : "Edit Keybind"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                            Layout.fillWidth: true
                        }

                        StyledRect {
                            id: deleteButton
                            visible: !root.isEditingAmbxst && !root.isCreatingNew
                            variant: deleteButtonArea.containsMouse ? "focus" : "common"
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: Styling.radius(-2)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.trash
                                font.family: Icons.font
                                font.pixelSize: 16
                                color: Colors.error
                            }

                            MouseArea {
                                id: deleteButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteBind(root.editingIndex)
                            }

                            StyledToolTip {
                                visible: deleteButtonArea.containsMouse
                                tooltipText: "Delete keybind"
                            }
                        }

                        StyledRect {
                            id: resetButton
                            visible: root.isEditingAmbxst
                            variant: resetButtonArea.pressed ? "primary" : (resetButtonArea.containsMouse ? "focus" : "common")
                            Layout.preferredWidth: resetButtonContent.width + 24
                            Layout.preferredHeight: 36
                            radius: Styling.radius(-2)

                            Row {
                                id: resetButtonContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: Icons.arrowCounterClockwise
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    color: Styling.srItem(resetButton.variant)
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Reset to default"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: Font.Medium
                                    color: Styling.srItem(resetButton.variant)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: resetButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.isEditingAmbxst && root.editingBind) {
                                        const path = root.editingBind.path.split(".");
                                        const section = path[1];
                                        const bindName = path[2];
                                        
                                        const defaultBind = Config.keybindsLoader.adapter.getAmbxstDefault(section, bindName);
                                        
                                        if (defaultBind) {
                                            root.editKeys = [{
                                                "modifiers": defaultBind.modifiers || [],
                                                "key": defaultBind.key || ""
                                            }];
                                            root.editActions = [{
                                                "dispatcher": defaultBind.dispatcher || "",
                                                "argument": defaultBind.argument || "",
                                                "flags": defaultBind.flags || ""
                                            }];
                                            
                                            root.saveEdit();
                                        }
                                    }
                                }
                            }
                        }

                        StyledRect {
                            id: saveButton
                            variant: saveButtonArea.containsMouse ? "primaryfocus" : "primary"
                            Layout.preferredWidth: saveButtonContent.width + 24
                            Layout.preferredHeight: 36
                            radius: Styling.radius(-2)

                            Row {
                                id: saveButtonContent
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: Icons.accept
                                    font.family: Icons.font
                                    font.pixelSize: 14
                                    color: saveButton.item
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Save"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    font.weight: Font.Medium
                                    color: saveButton.item
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: saveButtonArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.saveEdit()
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: formColumn.implicitHeight

                    ColumnLayout {
                        id: formColumn
                        width: root.contentWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: !root.isEditingAmbxst

                            Text {
                                text: "Name (optional)"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                variant: nameInput.activeFocus ? "focus" : "common"
                                radius: Styling.radius(-2)

                                TextInput {
                                    id: nameInput
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    text: root.editName
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    verticalAlignment: Text.AlignVCenter
                                    selectByMouse: true
                                    onTextChanged: {
                                        if (root.editName !== text) {
                                            root.editName = text
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !nameInput.text && !nameInput.activeFocus
                                        text: "e.g. Open Terminal, Switch to Workspace 1..."
                                        font: nameInput.font
                                        color: Colors.overSurfaceVariant
                                    }
                                }
                            }
                        }

                        Text {
                            visible: root.isEditingAmbxst && root.editingBind !== null
                            text: root.editingBind ? (root.editingBind.name || "") : ""
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(1)
                            font.weight: Font.Medium
                            color: Colors.overBackground
                        }

                        StyledRect {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            variant: "common"
                            radius: Styling.radius(-2)

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (root.editKeys.length === 0)
                                        return "?";
                                    let formatted = [];
                                    for (let i = 0; i < root.editKeys.length; i++) {
                                        const k = root.editKeys[i];
                                        const mods = root.formatModifiers(k.modifiers);
                                        const key = k.key || "?";
                                        formatted.push(mods ? mods + " + " + key : key);
                                    }
                                    return formatted.join(", ");
                                }
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(root.editKeys.length > 2 ? 0 : 2)
                                font.weight: Font.Bold
                                color: Styling.srItem("overprimary")
                                elide: Text.ElideRight
                                width: parent.width - 24
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Key Combination"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Medium
                                    color: Colors.overSurfaceVariant
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: root.editKeys.length > 1
                                    text: (root.currentKeyPage + 1) + " / " + root.editKeys.length
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    color: Colors.overSurfaceVariant
                                }

                                StyledRect {
                                    id: removeKeyBtn
                                    visible: root.editKeys.length > 1 && !root.isEditingAmbxst
                                    variant: removeKeyBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.trash
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: Colors.error
                                    }

                                    MouseArea {
                                        id: removeKeyBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeKeyPage()
                                    }

                                    StyledToolTip {
                                        visible: removeKeyBtnArea.containsMouse
                                        tooltipText: "Remove this key"
                                    }
                                }

                                StyledRect {
                                    id: prevKeyBtn
                                    visible: root.editKeys.length > 1
                                    variant: prevKeyBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)
                                    opacity: root.currentKeyPage > 0 ? 1 : 0.3

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.caretLeft
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: prevKeyBtn.item
                                    }

                                    MouseArea {
                                        id: prevKeyBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.currentKeyPage > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (root.currentKeyPage > 0) {
                                                root.currentKeyPage--;
                                            }
                                        }
                                    }
                                }

                                StyledRect {
                                    id: nextKeyBtn
                                    visible: root.editKeys.length > 1
                                    variant: nextKeyBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)
                                    opacity: root.currentKeyPage < root.editKeys.length - 1 ? 1 : 0.3

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.caretRight
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: nextKeyBtn.item
                                    }

                                    MouseArea {
                                        id: nextKeyBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.currentKeyPage < root.editKeys.length - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (root.currentKeyPage < root.editKeys.length - 1) {
                                                root.currentKeyPage++;
                                            }
                                        }
                                    }
                                }

                                StyledRect {
                                    id: addKeyBtn
                                    visible: !root.isEditingAmbxst
                                    variant: addKeyBtnArea.containsMouse ? "primaryfocus" : "primary"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.plus
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: addKeyBtn.item
                                    }

                                    MouseArea {
                                        id: addKeyBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.addKeyPage()
                                    }

                                    StyledToolTip {
                                        visible: addKeyBtnArea.containsMouse
                                        tooltipText: "Add another key"
                                    }
                                }
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: root.availableModifiers

                                    delegate: StyledRect {
                                        id: modTag
                                        required property string modelData
                                        required property int index

                                        property bool isSelected: root.hasModifier(modelData)
                                        property bool isHovered: false

                                        variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                                        width: modLabel.width + 32
                                        height: 40
                                        radius: Styling.radius(-2)

                                        Text {
                                            id: modLabel
                                            anchors.centerIn: parent
                                            text: modTag.modelData
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.weight: modTag.isSelected ? Font.Bold : Font.Normal
                                            color: modTag.item
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: modTag.isHovered = true
                                            onExited: modTag.isHovered = false
                                            onClicked: root.toggleModifier(modTag.modelData)
                                        }
                                    }
                                }
                            }

                            StyledRect {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                variant: keyInput.activeFocus ? "focus" : "common"
                                radius: Styling.radius(-2)

                                TextInput {
                                    id: keyInput
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    text: root.editKey
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    verticalAlignment: Text.AlignVCenter
                                    selectByMouse: true
                                    onTextChanged: {
                                        if (root.editKeys.length > root.currentKeyPage) {
                                            const currentKey = root.editKeys[root.currentKeyPage];
                                            const keyVal = currentKey.key || "";
                                            if (keyVal !== text) {
                                                root.updateCurrentKey(currentKey.modifiers || [], text);
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !keyInput.text && !keyInput.activeFocus
                                        text: "e.g. R, TAB, ESCAPE, mouse:272..."
                                        font: keyInput.font
                                        color: Colors.overSurfaceVariant
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Text {
                                    text: "Action"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Medium
                                    color: Colors.overSurfaceVariant
                                    Layout.fillWidth: true
                                }

                                Text {
                                    visible: root.editActions.length > 1 && !root.isEditingAmbxst
                                    text: (root.currentActionPage + 1) + " / " + root.editActions.length
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    color: Colors.overSurfaceVariant
                                }

                                StyledRect {
                                    id: removeActionBtn
                                    visible: root.editActions.length > 1 && !root.isEditingAmbxst
                                    variant: removeActionBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.trash
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: Colors.error
                                    }

                                    MouseArea {
                                        id: removeActionBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeActionPage()
                                    }

                                    StyledToolTip {
                                        visible: removeActionBtnArea.containsMouse
                                        tooltipText: "Remove this action"
                                    }
                                }

                                StyledRect {
                                    id: prevActionBtn
                                    visible: root.editActions.length > 1 && !root.isEditingAmbxst
                                    variant: prevActionBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)
                                    opacity: root.currentActionPage > 0 ? 1 : 0.3

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.caretLeft
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: prevActionBtn.item
                                    }

                                    MouseArea {
                                        id: prevActionBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.currentActionPage > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (root.currentActionPage > 0) {
                                                root.currentActionPage--;
                                            }
                                        }
                                    }
                                }

                                StyledRect {
                                    id: nextActionBtn
                                    visible: root.editActions.length > 1 && !root.isEditingAmbxst
                                    variant: nextActionBtnArea.containsMouse ? "focus" : "common"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)
                                    opacity: root.currentActionPage < root.editActions.length - 1 ? 1 : 0.3

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.caretRight
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: nextActionBtn.item
                                    }

                                    MouseArea {
                                        id: nextActionBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.currentActionPage < root.editActions.length - 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (root.currentActionPage < root.editActions.length - 1) {
                                                root.currentActionPage++;
                                            }
                                        }
                                    }
                                }

                                StyledRect {
                                    id: addActionBtn
                                    visible: !root.isEditingAmbxst
                                    variant: addActionBtnArea.containsMouse ? "primaryfocus" : "primary"
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: Styling.radius(-4)

                                    Text {
                                        anchors.centerIn: parent
                                        text: Icons.plus
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: addActionBtn.item
                                    }

                                    MouseArea {
                                        id: addActionBtnArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.addActionPage()
                                    }

                                    StyledToolTip {
                                        visible: addActionBtnArea.containsMouse
                                        tooltipText: "Add another action"
                                    }
                                }
                            }

                            Text {
                                text: "Action"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                            }

                            StyledRect {
                                id: actionDropdown
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                variant: actionDropdownArea.containsMouse ? "focus" : "common"
                                radius: Styling.radius(-2)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Text {
                                        text: root.getActionLabel(root.editActionId)
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        color: Colors.overBackground
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        text: Icons.caretDown
                                        font.family: Icons.font
                                        font.pixelSize: 14
                                        color: Colors.overSurfaceVariant
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    id: actionDropdownArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const pos = actionDropdown.mapToItem(root, 0, actionDropdown.height);
                                        actionPopup.x = Math.max(0, Math.min(pos.x, root.width - actionPopup.implicitWidth - 16));
                                        actionPopup.y = Math.max(0, Math.min(pos.y, root.height - actionPopup.implicitHeight - 16));
                                        actionPopup.open();
                                    }
                                }
                            }

                            Popup {
                                id: actionPopup
                                parent: root
                                modal: false
                                focus: true
                                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                                implicitWidth: actionDropdown.width
                                padding: 8
                                implicitHeight: Math.min(actionList.implicitHeight + padding * 2, 280)

                                background: StyledRect {
                                    variant: "popup"
                                    radius: Styling.radius(-2)
                                }

                                ScrollView {
                                    anchors.fill: parent
                                    contentWidth: availableWidth
                                    clip: true

                                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                                    ColumnLayout {
                                        id: actionList
                                        width: parent.width
                                        spacing: 4

                                        Repeater {
                                            model: root.actionOptions

                                            delegate: ActionMenuItem {
                                                required property string id
                                                required property string label
                                                required property string category

                                                actionLabel: label
                                                actionCategory: category
                                                onSelected: {
                                                    root.setCurrentAction(id);
                                                    actionPopup.close();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: root.editActionFields

                                delegate: ColumnLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: modelData.label
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.weight: Font.Medium
                                        color: Colors.overSurfaceVariant
                                    }

                                    StyledRect {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        variant: fieldInput.activeFocus ? "focus" : "common"
                                        radius: Styling.radius(-2)

                                        TextInput {
                                            id: fieldInput
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            text: root.editActionArgs[modelData.key] !== undefined ? root.editActionArgs[modelData.key].toString() : ""
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            color: Colors.overBackground
                                            verticalAlignment: Text.AlignVCenter
                                            selectByMouse: true
                                            onTextChanged: {
                                                root.updateCurrentActionArg(modelData.key, text);
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: !fieldInput.text && !fieldInput.activeFocus
                                                text: modelData.placeholder
                                                font: fieldInput.font
                                                color: Colors.overSurfaceVariant
                                            }
                                        }
                                    }
                                }
                            }

                            // =====================
                            // LAYOUT SELECTOR (for AxctlService)
                            // =====================
                            Text {
                                text: "Layouts (AxctlService)"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.weight: Font.Medium
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: 8
                            }

                            Text {
                                text: "Leave all unselected to work in all layouts"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overSurfaceVariant
                                Layout.topMargin: -4
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 8

                                Repeater {
                                    model: root.availableLayouts

                                    delegate: StyledRect {
                                        id: layoutTag
                                        required property string modelData
                                        required property int index

                                        property bool isSelected: root.hasLayout(modelData)
                                        property bool isHovered: false

                                        variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                                        width: layoutContent.width + 24 + (isSelected ? layoutCheckIcon.width + 4 : 0)
                                        height: 36
                                        radius: Styling.radius(-2)

                                        Behavior on width {
                                            enabled: (Config.animDuration ?? 0) > 0
                                            NumberAnimation {
                                                duration: (Config.animDuration ?? 0) / 3
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: layoutTag.isSelected ? 4 : 0

                                            Item {
                                                width: layoutCheckIcon.visible ? layoutCheckIcon.width : 0
                                                height: layoutCheckIcon.height
                                                clip: true

                                                Text {
                                                    id: layoutCheckIcon
                                                    text: Icons.accept
                                                    font.family: Icons.font
                                                    font.pixelSize: 14
                                                    color: layoutTag.item
                                                    visible: layoutTag.isSelected
                                                    opacity: layoutTag.isSelected ? 1 : 0

                                                    Behavior on opacity {
                                                        enabled: (Config.animDuration ?? 0) > 0
                                                        NumberAnimation {
                                                            duration: (Config.animDuration ?? 0) / 3
                                                            easing.type: Easing.OutCubic
                                                        }
                                                    }
                                                }

                                                Behavior on width {
                                                    enabled: (Config.animDuration ?? 0) > 0
                                                    NumberAnimation {
                                                        duration: (Config.animDuration ?? 0) / 3
                                                        easing.type: Easing.OutCubic
                                                    }
                                                }
                                            }

                                            Text {
                                                id: layoutContent
                                                text: layoutTag.modelData.charAt(0).toUpperCase() + layoutTag.modelData.slice(1)
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(0)
                                                font.weight: layoutTag.isSelected ? Font.Bold : Font.Normal
                                                color: layoutTag.item
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: layoutTag.isHovered = true
                                            onExited: layoutTag.isHovered = false
                                            onClicked: root.toggleLayout(layoutTag.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component ActionMenuItem: StyledRect {
        id: actionItem
        required property string actionLabel
        required property string actionCategory
        signal selected

        property bool isHovered: false

        Layout.fillWidth: true
        Layout.preferredHeight: 36
        radius: Styling.radius(-4)
        variant: isHovered ? "focus" : "common"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Text {
                text: actionItem.actionLabel
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                Layout.fillWidth: true
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                text: actionItem.actionCategory
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: actionItem.isHovered = true
            onExited: actionItem.isHovered = false
            onClicked: actionItem.selected()
        }
    }

    component BindItem: StyledRect {
        id: bindItem

        property string customName: ""
        property string bindName: ""
        property string keybindText: ""
        property string dispatcher: ""
        property string argument: ""
        property bool isEnabled: true
        property bool isAmbxst: true
        property bool isHovered: false
        property var layouts: []

        property string label: displayName
        property string keywords: keybindText + " " + dispatcher + " " + argument + " bind shortcut"

        readonly property bool hasCustomName: customName !== ""
        readonly property string displayName: hasCustomName ? customName : bindName
        readonly property string displaySubtitle: hasCustomName ? "" : (argument || dispatcher)
        readonly property bool hasLayoutRestriction: layouts && layouts.length > 0
        readonly property var displayLayouts: hasLayoutRestriction ? layouts : ["dwindle", "master", "scrolling"]

        signal editRequested
        signal toggleEnabled

        variant: isHovered ? "focus" : "common"
        height: 56
        radius: Styling.radius(-2)
        enableShadow: true
        opacity: isEnabled ? 1 : 0.5

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 12

            Item {
                id: checkboxItem
                visible: !bindItem.isAmbxst
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32

                Item {
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        radius: Styling.radius(-4)
                        color: Colors.background
                        visible: !bindItem.isEnabled
                    }

                    StyledRect {
                        variant: "primary"
                        anchors.fill: parent
                        radius: Styling.radius(-4)
                        visible: bindItem.isEnabled
                        opacity: bindItem.isEnabled ? 1.0 : 0.0

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutQuart
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: Icons.accept
                            color: Styling.srItem("primary")
                            font.family: Icons.font
                            font.pixelSize: 16
                            scale: bindItem.isEnabled ? 1.0 : 0.0

                            Behavior on scale {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.5
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: bindItem.displayName
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.Medium
                    color: bindItem.item
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: bindItem.displaySubtitle
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overSurfaceVariant
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: text !== ""
                    }

                    Row {
                        visible: !bindItem.isAmbxst
                        spacing: 4
                        Layout.alignment: Qt.AlignVCenter

                        Repeater {
                            model: bindItem.displayLayouts

                            delegate: Rectangle {
                                id: layoutBadge
                                required property string modelData
                                property bool isHovered: false
                                width: layoutBadgeText.width + 8
                                height: 16
                                radius: 4
                                color: Styling.srItem("overprimary")
                                opacity: isHovered ? 1.0 : 0.8

                                Text {
                                    id: layoutBadgeText
                                    anchors.centerIn: parent
                                    text: layoutBadge.modelData.charAt(0).toUpperCase()
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    font.weight: Font.Bold
                                    color: Styling.srItem("primary")
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: layoutBadge.isHovered = true
                                    onExited: layoutBadge.isHovered = false
                                }

                                StyledToolTip {
                                    visible: layoutBadge.isHovered
                                    tooltipText: layoutBadge.modelData.charAt(0).toUpperCase() + layoutBadge.modelData.slice(1) + " layout"
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                variant: "internalbg"
                Layout.preferredWidth: keybindLabel.width + 24
                Layout.preferredHeight: 28
                radius: Styling.radius(-4)

                Text {
                    id: keybindLabel
                    anchors.centerIn: parent
                    text: bindItem.keybindText
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-1)
                    font.weight: Font.Medium
                    color: Styling.srItem("overprimary")
                }
            }
        }

        MouseArea {
            id: editClickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: bindItem.isHovered = true
            onExited: bindItem.isHovered = false
            onClicked: bindItem.editRequested()
        }

        MouseArea {
            id: checkboxClickArea
            visible: !bindItem.isAmbxst
            x: 12
            y: (parent.height - 32) / 2
            width: 32
            height: 32
            z: 1
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onEntered: bindItem.isHovered = true
            onExited: bindItem.isHovered = false
            onClicked: mouse => {
                bindItem.toggleEnabled();
                mouse.accepted = true;
            }
        }
    }
}
