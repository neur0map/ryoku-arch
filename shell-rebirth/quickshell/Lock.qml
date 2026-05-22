import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "./colors" as ColorsModule
import qs.components

ShellRoot {
    id: root
    property var colors: ColorsModule.Colors

    // Semantic color mapping from the Material Design 3 palette
    readonly property color base:      colors.background
    readonly property color crust:     colors.surface_dim
    readonly property color mantle:    colors.surface_container_lowest
    readonly property color text:      colors.on_surface
    readonly property color subtext0:  colors.on_surface_variant
    readonly property color overlay0:  colors.surface_container_low
    readonly property color overlay2:  colors.surface_container_high
    readonly property color surface0:  colors.surface_container
    readonly property color surface1:  colors.surface_container_high
    readonly property color surface2:  colors.surface_container_highest

    // Additional semantic accents from the color scheme
    readonly property color mauve:     colors.primary          // primary accent
    readonly property color blue:      colors.secondary        // secondary accent
    readonly property color peach:     colors.tertiary         // tertiary / warning
    readonly property color red:       colors.error            // error / danger
    readonly property color green:     colors.primary_container // success / charging

    // Persistent Settings
    Settings {
        id: lockSettings
        category: "QuickshellLockscreen"
        property bool hidePassword: false
        property int revealDuration: 300
    }

    // Shared state across all monitors
    QtObject {
        id: lockUI
        property bool failed: false
        property bool authenticating: false
        property string statusText: "Locked"
    }

    // System Authentication hook
    PamContext {
        id: pam
        Component.onCompleted: pam.start()
        onCompleted: (result) => {
            lockUI.authenticating = false;
            if (result === PamResult.Success) {
                rootLock.locked = false;
                Qt.quit();
            } else {
                lockUI.failed = true;
                lockUI.statusText = "Access Denied";
                pam.start();
            }
        }
    }

    // System action processes
    Process { id: suspendProcess; command: ["systemctl", "suspend"] }
    Process { id: poweroffProcess; command: ["systemctl", "poweroff"] }
    Process { id: reloadProcess; command: ["systemctl", "reboot"] }

    WlSessionLock {
        id: rootLock
        locked: true

        WlSessionLockSurface {
            id: surface

            Item {
                id: screenRoot
                anchors.fill: parent

                property string staticWallpaperPath: "file:///tmp/lock_bg.png"
                property string batPct: "100"
                property string batStatus: "AC"
                property string currentUser: "User"
                property string faceIconPath: ""
                property string kbLayout: "US"
                property string weatherIcon: ""
                property string weatherTemp: "--°C"

                property real introState: 0.0
                property bool powerMenuOpen: false
                property bool inputActive: false
                property bool isPlayingIntro: true

                Component.onCompleted: introSequence.start()

                property real globalOrbitAngle: 0
                NumberAnimation on globalOrbitAngle {
                    from: 0; to: Math.PI * 2; duration: 90000; loops: Animation.Infinite; running: true
                }

                Timer {
                    id: idleTimer
                    interval: 15000
                    running: screenRoot.inputActive && inputField.text.length === 0
                    repeat: false
                    onTriggered: screenRoot.inputActive = false
                }

                // ---------------------------------------------------------
                // BACKGROUND DATA POLLING (unchanged)
                // ---------------------------------------------------------
                Process {
                    id: userPoller
                    command: ["bash", "-c", "USER_VAR=$(whoami); ICON_PATH=\"\"; if [ -f ~/.face.icon ]; then ICON_PATH=$(readlink -f ~/.face.icon); elif [ -f ~/.face ]; then ICON_PATH=$(readlink -f ~/.face); fi; echo -n \"$USER_VAR|$ICON_PATH\""]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let parts = this.text.trim().split("|");
                            if (parts.length > 0 && parts[0] !== "") screenRoot.currentUser = parts[0];
                            if (parts.length > 1 && parts[1].trim() !== "") {
                                let path = parts[1].trim();
                                screenRoot.faceIconPath = path.startsWith("file://") ? path : "file://" + path;
                            }
                        }
                    }
                    Component.onCompleted: running = true
                }

                Process {
                    id: kbPoller
                    command: ["bash", "-c", "hyprctl devices -j | jq -r '.keyboards[] | select(.main == true) | .active_keymap' | head -n1 | cut -c1-2 | tr '[:lower:]' '[:upper:]'"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let layout = this.text.trim();
                            if (layout !== "" && layout !== "null") screenRoot.kbLayout = layout;
                        }
                    }
                }
                Timer { interval: 150; running: true; repeat: true; triggeredOnStart: true; onTriggered: kbPoller.running = true }

                Process {
                    id: batPoller
                    command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1 || echo '100'; cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1 || echo 'AC'"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let lines = this.text.trim().split("\n");
                            if (lines.length >= 2) {
                                screenRoot.batPct = lines[0] || "100";
                                screenRoot.batStatus = lines[1] || "Unknown";
                            }
                        }
                    }
                }
                Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: batPoller.running = true }

                Process {
                    id: weatherPoller
                    property string scriptPath: Qt.resolvedUrl("calendar/weather.sh").toString().replace(/^file:\/\//, "")
                    command: ["bash", "-c", '"' + scriptPath + '" --current-icon; "' + scriptPath + '" --current-temp']
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let lines = this.text.trim().split("\n");
                            if (lines.length >= 2) {
                                screenRoot.weatherIcon = lines[0] || "";
                                screenRoot.weatherTemp = lines[1] || "--°C";
                            }
                        }
                    }
                }
                Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: weatherPoller.running = true }

                // ---------------------------------------------------------
                // BACKGROUND (Wallpaper + Dim + Orbs)
                // ---------------------------------------------------------
                Rectangle { anchors.fill: parent; color: root.base }

                Image {
                    id: bgWallpaper
                    anchors.fill: parent
                    source: Quickshell.env("HOME") + "/.cache/current_wallpaper"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                    cache: false
                }
                MultiEffect {
                    source: bgWallpaper
                    anchors.fill: bgWallpaper
                    blurEnabled: true
                    blurMax: 64
                    blur: 1.0
                }
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: 0.25
                }

                Item {
                    anchors.fill: parent
                    // Orbs (using semantic colors)
                    Rectangle {
                        width: parent.width * 0.8; height: width; radius: width / 2
                        x: (parent.width / 2 - width / 2) + Math.cos(screenRoot.globalOrbitAngle * 2) * 200
                        y: (parent.height / 2 - height / 2) + Math.sin(screenRoot.globalOrbitAngle * 2) * 150
                        scale: 1.0 + Math.sin(screenRoot.globalOrbitAngle * 6) * 0.05
                        opacity: screenRoot.inputActive ? 0.04 : 0.08
                        color: root.mauve
                    }
                    Rectangle {
                        width: parent.width * 0.9; height: width; radius: width / 2
                        x: (parent.width / 2 - width / 2) + Math.sin(screenRoot.globalOrbitAngle * 1.5) * -200
                        y: (parent.height / 2 - height / 2) + Math.cos(screenRoot.globalOrbitAngle * 1.5) * -150
                        scale: 1.0 + Math.cos(screenRoot.globalOrbitAngle * 5) * 0.05
                        opacity: screenRoot.inputActive ? 0.03 : 0.06
                        color: root.blue
                    }
                    Item {
                        anchors.fill: parent
                        opacity: screenRoot.introState
                        scale: 1.1 - (0.1 * screenRoot.introState)
                        Repeater {
                            model: 4
                            Rectangle {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -40
                                width: 400 + (index * 220)
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.color: lockUI.failed ? root.red : root.text
                                border.width: 1
                                opacity: lockUI.failed ? (0.1 - (index * 0.02)) : (screenRoot.inputActive ? (0.02 - (index * 0.005)) : (0.04 - (index * 0.01)))
                            }
                        }
                    }
                }

                // ---------------------------------------------------------
                // MAIN CONTENT LAYER (Clock & Auth)
                // ---------------------------------------------------------
                MouseArea {
                    anchors.fill: parent
                    enabled: !screenRoot.isPlayingIntro
                    onClicked: {
                        if (screenRoot.powerMenuOpen) screenRoot.powerMenuOpen = false;
                        if (!screenRoot.inputActive) screenRoot.inputActive = true;
                        inputField.forceActiveFocus();
                    }
                }

                Item {
                    anchors.fill: parent
                    opacity: screenRoot.introState
                    transform: Translate { y: 30 * (1.0 - screenRoot.introState) }

                    // --- CLOCK MODULE ---
                    ColumnLayout {
                        id: clockModule
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: screenRoot.inputActive ? -120 : -40
                        spacing: -10
                        opacity: screenRoot.inputActive ? 0.0 : 1.0
                        scale: screenRoot.inputActive ? 0.9 : 1.0
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 0
                            Text {
                                id: clockHours
                                font.family: "JetBrains Mono"
                                font.pixelSize: 140
                                font.weight: Font.Bold
                                color: root.text
                            }
                            Text {
                                text: ":"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 140
                                font.weight: Font.Bold
                                opacity: 0.5
                                color: root.text
                            }
                            Text {
                                id: clockMinutes
                                font.family: "JetBrains Mono"
                                font.pixelSize: 140
                                font.weight: Font.Bold
                                color: root.text
                            }
                        }
                        Text {
                            id: dateText
                            Layout.alignment: Qt.AlignHCenter
                            font.family: "JetBrains Mono"
                            font.pixelSize: 22
                            font.weight: Font.Bold
                            color: root.text
                        }
                        Timer {
                            interval: 1000; running: true; repeat: true; triggeredOnStart: true
                            onTriggered: {
                                let d = new Date();
                                clockHours.text = Qt.formatDateTime(d, "hh");
                                clockMinutes.text = Qt.formatDateTime(d, "mm");
                                dateText.text = Qt.formatDateTime(d, "dddd, MMMM dd");
                                miniTimeText.text = Qt.formatDateTime(d, "hh:mm");
                            }
                        }
                    }

                    // --- COMPACT TIME (shown above auth panel while active) ---
                    Text {
                        id: miniTimeText
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: screenRoot.inputActive ? -220 : -190
                        text: ""
                        font.family: "JetBrains Mono"
                        font.pixelSize: 44
                        font.weight: Font.Light
                        font.letterSpacing: 4
                        color: root.text
                        opacity: screenRoot.inputActive ? 0.55 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }

                    // --- AUTHENTICATION MODULE (Input State) ---
                    RowLayout {
                        id: authModule
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: screenRoot.inputActive ? -40 : 40
                        spacing: 32
                        opacity: screenRoot.inputActive ? 1.0 : 0.0
                        scale: screenRoot.inputActive ? 1.0 : 0.9
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                        Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                        // Left: Avatar
                        Item {
                            Layout.alignment: Qt.AlignVCenter
                            width: 170; height: 170
                            Rectangle {
                                id: avatarMask
                                anchors.fill: parent
                                radius: 85
                                color: "black"
                                visible: false
                                layer.enabled: true
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 85
                                color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.5)
                                visible: avatarImg.status !== Image.Ready
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰄽"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: 64
                                    color: root.subtext0
                                }
                            }
                            Image {
                                id: avatarImg
                                anchors.fill: parent
                                source: Quickshell.env("HOME") + "/.cache/current_avatar"
                                fillMode: Image.PreserveAspectCrop
                                visible: false
                                cache: false
                                asynchronous: true
                            }
                            MultiEffect {
                                source: avatarImg
                                anchors.fill: avatarImg
                                maskEnabled: true
                                maskSource: avatarMask
                                visible: avatarImg.status === Image.Ready
                            }
                            Rectangle {
                                anchors.fill: parent
                                radius: 85
                                color: "transparent"
                                border.color: lockUI.failed ? root.red : (lockUI.authenticating ? root.peach : Qt.rgba(root.text.r, root.text.g, root.text.b, 0.5))
                                border.width: 3
                            }
                        }

                        // Right: User & Password Input
                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 16
                            Text {
                                Layout.alignment: Qt.AlignLeft
                                text: screenRoot.currentUser
                                font.family: "JetBrains Mono"
                                font.pixelSize: 28
                                font.weight: Font.Bold
                                color: root.text
                            }
                            RowLayout {
                                Layout.alignment: Qt.AlignLeft
                                spacing: 12
                                Rectangle {
                                    width: 36; height: 36; radius: 18
                                    color: lockUI.failed ? Qt.rgba(root.red.r, root.red.g, root.red.b, 0.2) :
                                        (lockUI.authenticating ? Qt.rgba(root.peach.r, root.peach.g, root.peach.b, 0.2) :
                                            Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.15))
                                    border.color: lockUI.failed ? root.red : (lockUI.authenticating ? root.peach : root.mauve)
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: lockUI.failed ? "󰌾" : (lockUI.authenticating ? "󰌿" : "󰌾")
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: 18
                                        color: lockUI.failed ? root.red : (lockUI.authenticating ? root.peach : root.mauve)
                                    }
                                }
                                Text {
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    font.letterSpacing: 2.0
                                    color: lockUI.failed ? root.red : (lockUI.authenticating ? root.peach : root.text)
                                    text: lockUI.statusText.toUpperCase()
                                }
                            }

                            // Password input pill with glassmorphic blur
                            Rectangle {
                                id: pinPill
                                Layout.alignment: Qt.AlignLeft
                                width: 320
                                height: 60
                                radius: 30
                                clip: true
                                color: lockUI.failed ? Qt.rgba(root.red.r, root.red.g, root.red.b, 0.1) :
                                    Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.7)
                                border.width: 2
                                border.color: {
                                    if (lockUI.failed) return root.red;
                                    if (lockUI.authenticating) return root.peach;
                                    if (inputField.text.length > 0) return root.text;
                                    return Qt.rgba(root.text.r, root.text.g, root.text.b, 0.08);
                                }
                                scale: lockUI.failed ? 1.05 : (lockUI.authenticating ? 0.98 : 1.0)
                                transform: Translate { id: shakeTranslate; x: 0 }
                                SequentialAnimation {
                                    id: shakeAnim
                                    NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -8; duration: 120; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: shakeTranslate; property: "x"; from: -8; to: 8; duration: 120; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: shakeTranslate; property: "x"; from: 8; to: 0; duration: 120; easing.type: Easing.InOutSine }
                                }
                                Connections {
                                    target: lockUI
                                    function onFailedChanged() { if (lockUI.failed) shakeAnim.restart(); }
                                }

                                // TextInput and password dots (unchanged logic)
                                TextInput {
                                    id: inputField
                                    anchors.fill: parent
                                    opacity: 0
                                    echoMode: TextInput.Password
                                    enabled: !screenRoot.isPlayingIntro
                                    property string oldText: ""
                                    Component.onCompleted: forceActiveFocus()
                                    onActiveFocusChanged: {
                                        if (!activeFocus && !screenRoot.powerMenuOpen && !screenRoot.isPlayingIntro) forceActiveFocus();
                                    }
                                    Keys.onPressed: (event) => {
                                        if (event.key === Qt.Key_Escape) {
                                            screenRoot.inputActive = false;
                                            text = "";
                                            passModel.clear();
                                            event.accepted = true;
                                        } else if (!screenRoot.inputActive) {
                                            screenRoot.inputActive = true;
                                        }
                                    }
                                    onAccepted: {
                                        if (text.length > 0 && pam.responseRequired && !lockUI.authenticating) {
                                            lockUI.authenticating = true;
                                            lockUI.statusText = "Authenticating...";
                                            lockUI.failed = false;
                                            pam.respond(text);
                                            text = "";
                                            oldText = "";
                                            passModel.clear();
                                        }
                                    }
                                    onTextChanged: {
                                        if (lockUI.authenticating) return;
                                        if (text.length > 0 && !screenRoot.inputActive) screenRoot.inputActive = true;
                                        idleTimer.restart();
                                        if (text !== oldText) {
                                            if (text.length > oldText.length) {
                                                for (let i = oldText.length; i < text.length; i++) passModel.append({ "charStr": text.charAt(i), "isDot": lockSettings.hidePassword });
                                            } else if (text.length < oldText.length) {
                                                let diff = oldText.length - text.length;
                                                for (let i = 0; i < diff; i++) passModel.remove(passModel.count - 1);
                                            } else {
                                                passModel.clear();
                                                for (let i = 0; i < text.length; i++) passModel.append({ "charStr": text.charAt(i), "isDot": lockSettings.hidePassword });
                                            }
                                            oldText = text;
                                        }
                                        if (text.length > 0) {
                                            lockUI.failed = false;
                                            lockUI.statusText = "Enter PIN";
                                        } else if (!lockUI.failed) lockUI.statusText = "Locked";
                                    }
                                }
                                ListModel { id: passModel }
                                Item {
                                    anchors.fill: parent
                                    anchors.leftMargin: 20
                                    anchors.rightMargin: 20
                                    clip: true
                                    Row {
                                        id: dotRow
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: width > parent.width ? parent.width - width : (parent.width - width) / 2
                                        spacing: 4
                                        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                        Repeater {
                                            model: passModel
                                            delegate: Item {
                                                width: charText.implicitWidth
                                                height: 30
                                                Timer {
                                                    interval: lockSettings.revealDuration
                                                    running: !model.isDot && !lockSettings.hidePassword
                                                    onTriggered: if (index >= 0 && index < passModel.count) passModel.setProperty(index, "isDot", true);
                                                }
                                                Text {
                                                    id: charText
                                                    anchors.centerIn: parent
                                                    text: model.isDot ? "•" : model.charStr
                                                    font.family: "JetBrains Mono"
                                                    font.pixelSize: model.isDot ? 32 : 24
                                                    font.weight: Font.Bold
                                                    color: lockUI.failed ? root.red : (lockUI.authenticating ? root.peach : root.text)
                                                    NumberAnimation on opacity { from: 0; to: 1; duration: 150 }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------------------------------------------------------
                // CAVABARS INTEGRATION (subtle audio visualizer)
                // ---------------------------------------------------------
                Item {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 120
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360
                    height: 60
                    opacity: screenRoot.introState * (screenRoot.inputActive ? 0.4 : 0.7)
                    Behavior on opacity { NumberAnimation { duration: 400 } }

                    CavaBars {
                        anchors.fill: parent
                        barCount: 32
                        spacing: 2
                        corner: 2
                        enableShadow: false
                        // Use colors from the scheme
                        // (CavaBars internally uses ColorsModule.Colors, but we can override if needed)
                    }
                }

                // ---------------------------------------------------------
                // BOTTOM GRADIENT (depth framing)
                // ---------------------------------------------------------
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 180
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 1.0; color: Qt.rgba(root.base.r, root.base.g, root.base.b, 0.55) }
                    }
                }

                // ---------------------------------------------------------
                // BOTTOM SYSTEM INFO PILLS
                // ---------------------------------------------------------
                RowLayout {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 12
                    opacity: screenRoot.introState
                    transform: Translate { y: 20 * (1.0 - screenRoot.introState) }

                    // Battery pill
                    Rectangle {
                        property bool isHovered: batMouse.containsMouse
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: batLayoutRow.implicitWidth + 32
                        radius: 22
                        color: isHovered ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6) : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.4)
                        border.color: isHovered ? batLayoutRow.dynamicBatColor : Qt.rgba(root.text.r, root.text.g, root.text.b, 0.08)
                        border.width: 1
                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        RowLayout {
                            id: batLayoutRow; anchors.centerIn: parent; spacing: 8
                            property color dynamicBatColor: {
                                if (screenRoot.batStatus === "Charging") return root.green;
                                let pct = parseInt(screenRoot.batPct);
                                if (pct >= 60) return root.green;
                                if (pct >= 25) return root.peach;
                                return root.red;
                            }
                            Text { text: screenRoot.batStatus === "Charging" ? "󰂄" : (parseInt(screenRoot.batPct) < 20 ? "󰂃" : "󰁹"); font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: batLayoutRow.dynamicBatColor }
                            Text { text: screenRoot.batPct + "%"; font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black; color: batLayoutRow.dynamicBatColor }
                        }
                        MouseArea { id: batMouse; anchors.fill: parent; hoverEnabled: true; enabled: !screenRoot.isPlayingIntro }
                    }

                    // Weather pill
                    Rectangle {
                        property bool isHovered: weatherMouse.containsMouse
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: weatherRow.implicitWidth + 32
                        radius: 22
                        visible: screenRoot.weatherTemp !== "--°C"
                        color: isHovered ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6) : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.4)
                        border.color: isHovered ? Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.5) : Qt.rgba(root.text.r, root.text.g, root.text.b, 0.08)
                        border.width: 1
                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        RowLayout {
                            id: weatherRow; anchors.centerIn: parent; spacing: 8
                            Text { text: screenRoot.weatherIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: root.subtext0 }
                            Text { text: screenRoot.weatherTemp; font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black; color: root.text }
                        }
                        MouseArea { id: weatherMouse; anchors.fill: parent; hoverEnabled: true; enabled: !screenRoot.isPlayingIntro }
                    }

                    // Keyboard layout pill
                    Rectangle {
                        property bool isHovered: kbMouse.containsMouse
                        Layout.preferredHeight: 44
                        Layout.preferredWidth: kbRow.implicitWidth + 32
                        radius: 22
                        color: isHovered ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.6) : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.4)
                        border.color: isHovered ? Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.5) : Qt.rgba(root.text.r, root.text.g, root.text.b, 0.08)
                        border.width: 1
                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        RowLayout {
                            id: kbRow; anchors.centerIn: parent; spacing: 8
                            Text { text: ""; font.family: "Iosevka Nerd Font"; font.pixelSize: 16; color: root.subtext0 }
                            Text { text: screenRoot.kbLayout; font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Black; color: root.text }
                        }
                        MouseArea { id: kbMouse; anchors.fill: parent; hoverEnabled: true; enabled: !screenRoot.isPlayingIntro }
                    }
                }

                // ---------------------------------------------------------
                // POWER MENU (glassmorphic)
                // ---------------------------------------------------------
                Rectangle {
                    id: powerMenu
                    anchors.bottom: powerBtn.top
                    anchors.right: parent.right
                    anchors.bottomMargin: 15
                    anchors.rightMargin: 40
                    width: 280
                    height: screenRoot.powerMenuOpen ? (menuLayout.implicitHeight + 20) : 0
                    radius: 18
                    clip: true
                    opacity: screenRoot.powerMenuOpen ? 1 : 0
                    color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.95)
                    border.color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.25)
                    border.width: 1
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blurMax: 16
                        blur: 0.5
                    }

                    ColumnLayout {
                        id: menuLayout
                        anchors.top: parent.top; anchors.topMargin: 10
                        anchors.left: parent.left; anchors.right: parent.right
                        spacing: 6

                        Text { text: "SETTINGS"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 12; font.letterSpacing: 1.5; color: root.mauve; Layout.leftMargin: 18; Layout.topMargin: 4; Layout.bottomMargin: 4 }
                        // Hide Password Toggle
                        RowLayout {
                            Layout.fillWidth: true; Layout.leftMargin: 18; Layout.rightMargin: 18; Layout.topMargin: 4
                            Text { text: "Hide password"; font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: Font.Medium; color: root.text; Layout.fillWidth: true }
                            Rectangle {
                                width: 40; height: 22; radius: 11
                                color: lockSettings.hidePassword ? root.mauve : root.surface2
                                Rectangle { width: 18; height: 18; radius: 9; x: lockSettings.hidePassword ? 20 : 2; y: 2; color: root.base }
                                MouseArea {
                                    anchors.fill: parent;
                                    onClicked: {
                                        lockSettings.hidePassword = !lockSettings.hidePassword;
                                        if (lockSettings.hidePassword) for(let i = 0; i < passModel.count; i++) passModel.setProperty(i, "isDot", true);
                                    }
                                }
                            }
                        }
                        // Reveal Delay Slider
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.leftMargin: 18; Layout.rightMargin: 18; Layout.topMargin: 8; Layout.bottomMargin: 8; spacing: 8
                            opacity: lockSettings.hidePassword ? 0.3 : 1.0
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Reveal delay"; font.family: "JetBrains Mono"; font.pixelSize: 14; font.weight: Font.Medium; color: root.blue; Layout.fillWidth: true }
                                Text { text: lockSettings.revealDuration >= 1000 ? (lockSettings.revealDuration / 1000).toFixed(1) + " s" : lockSettings.revealDuration + " ms"; font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Bold; color: root.peach }
                            }
                            Item {
                                Layout.fillWidth: true; Layout.preferredHeight: 28
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width; height: 8; radius: 4; color: root.surface2
                                    Rectangle { width: ((lockSettings.revealDuration - 100) / 2900) * parent.width; height: parent.height; radius: 4; color: root.mauve }
                                }
                                Rectangle {
                                    id: sliderThumb
                                    width: 20; height: 20; radius: 10; color: root.peach
                                    border.color: root.crust; border.width: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.max(0, Math.min(((lockSettings.revealDuration - 100) / 2900) * parent.width - 10, parent.width - 20))
                                    scale: sliderMouse.pressed ? 1.3 : (sliderMouse.containsMouse ? 1.15 : 1.0)
                                    MultiEffect { source: sliderThumb; anchors.fill: sliderThumb; shadowEnabled: true; shadowBlur: 0.5; shadowColor: "#000000"; shadowOpacity: 0.4; shadowVerticalOffset: 2 }
                                }
                                MouseArea {
                                    id: sliderMouse; anchors.fill: parent; hoverEnabled: true; enabled: !lockSettings.hidePassword; preventStealing: true
                                    function updateVal(mouseX) {
                                        let pct = Math.max(0, Math.min(1, mouseX / width));
                                        let ms = Math.round(100 + (pct * 2900));
                                        if (ms % 100 < 10) ms -= (ms % 100);
                                        else if (ms % 100 > 90) ms += (100 - (ms % 100));
                                        lockSettings.revealDuration = ms;
                                    }
                                    onPositionChanged: (mouse) => { if (pressed) updateVal(mouse.x); }
                                    onPressed: (mouse) => updateVal(mouse.x)
                                }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.2); Layout.leftMargin: 18; Layout.rightMargin: 18; Layout.topMargin: 4; Layout.bottomMargin: 4 }

                        Text { text: "SYSTEM"; font.family: "JetBrains Mono"; font.weight: Font.Black; font.pixelSize: 12; font.letterSpacing: 1.5; color: root.mauve; Layout.leftMargin: 18; Layout.bottomMargin: 4 }

                        // Reboot
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 48; Layout.leftMargin: 10; Layout.rightMargin: 10; radius: 12
                            color: ma1.containsMouse ? Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.1) : "transparent"
                            scale: ma1.pressed ? 0.95 : (ma1.containsMouse ? 1.02 : 1.0)
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 0
                                Text { text: "󰜉"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: ma1.containsMouse ? root.blue : Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.6) }
                                Item { Layout.fillWidth: true }
                                Text { text: "Reboot"; font.family: "JetBrains Mono"; font.pixelSize: 15; font.weight: Font.Medium; color: ma1.containsMouse ? root.blue : Qt.rgba(root.blue.r, root.blue.g, root.blue.b, 0.6) }
                            }
                            MouseArea { id: ma1; anchors.fill: parent; hoverEnabled: true; onClicked: { screenRoot.powerMenuOpen = false; reloadProcess.running = true; } }
                        }
                        // Suspend
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 48; Layout.leftMargin: 10; Layout.rightMargin: 10; radius: 12
                            color: ma2.containsMouse ? Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.1) : "transparent"
                            scale: ma2.pressed ? 0.95 : (ma2.containsMouse ? 1.02 : 1.0)
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 0
                                Text { text: "󰒲"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: ma2.containsMouse ? root.mauve : Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.6) }
                                Item { Layout.fillWidth: true }
                                Text { text: "Suspend"; font.family: "JetBrains Mono"; font.pixelSize: 15; font.weight: Font.Medium; color: ma2.containsMouse ? root.mauve : Qt.rgba(root.mauve.r, root.mauve.g, root.mauve.b, 0.6) }
                            }
                            MouseArea { id: ma2; anchors.fill: parent; hoverEnabled: true; onClicked: { screenRoot.powerMenuOpen = false; suspendProcess.running = true; } }
                        }
                        // Power Off
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 48; Layout.leftMargin: 10; Layout.rightMargin: 10; Layout.bottomMargin: 8; radius: 12
                            color: ma3.containsMouse ? Qt.rgba(root.red.r, root.red.g, root.red.b, 0.1) : "transparent"
                            scale: ma3.pressed ? 0.95 : (ma3.containsMouse ? 1.02 : 1.0)
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 0
                                Text { text: "󰐥"; font.family: "Iosevka Nerd Font"; font.pixelSize: 18; color: ma3.containsMouse ? root.red : Qt.rgba(root.red.r, root.red.g, root.red.b, 0.6) }
                                Item { Layout.fillWidth: true }
                                Text { text: "Power Off"; font.family: "JetBrains Mono"; font.pixelSize: 15; font.weight: Font.Medium; color: ma3.containsMouse ? root.red : Qt.rgba(root.red.r, root.red.g, root.red.b, 0.6) }
                            }
                            MouseArea { id: ma3; anchors.fill: parent; hoverEnabled: true; onClicked: { screenRoot.powerMenuOpen = false; poweroffProcess.running = true; } }
                        }
                    }
                }

                // Power button (enlarged)
                Rectangle {
                    id: powerBtn
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 40
                    width: 52; height: 52; radius: 26
                    color: screenRoot.powerMenuOpen ? root.surface2 : (powerBtnMa.containsMouse ? Qt.rgba(root.surface1.r, root.surface1.g, root.surface1.b, 0.8) : Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.4))
                    border.color: screenRoot.powerMenuOpen ? root.text : Qt.rgba(root.text.r, root.text.g, root.text.b, 0.15)
                    border.width: 1
                    opacity: screenRoot.introState
                    transform: Translate { y: 20 * (1.0 - screenRoot.introState) }
                    scale: powerBtnMa.pressed ? 0.9 : (powerBtnMa.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Text {
                        anchors.centerIn: parent
                        text: "󰐥"
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: 22
                        color: screenRoot.powerMenuOpen ? root.red : (powerBtnMa.containsMouse ? root.text : root.subtext0)
                    }
                    MouseArea {
                        id: powerBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !screenRoot.isPlayingIntro
                        onClicked: {
                            screenRoot.powerMenuOpen = !screenRoot.powerMenuOpen;
                            if (!screenRoot.powerMenuOpen) inputField.forceActiveFocus();
                        }
                    }
                }

                // ---------------------------------------------------------
                // INTRO ANIMATION OVERLAY (unchanged but uses new colors)
                // ---------------------------------------------------------
                Item {
                    id: introOverlay
                    anchors.fill: parent
                    z: 999
                    visible: screenRoot.isPlayingIntro || opacity > 0
                    Rectangle {
                        id: ring3
                        width: 360; height: 360; radius: 180
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.mauve
                        border.width: 1
                        scale: 0.5; opacity: 0.0
                    }
                    Rectangle {
                        id: ring2
                        width: 300; height: 300; radius: 150
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.text
                        border.width: 1
                        scale: 0.8; opacity: 0.0
                    }
                    Rectangle {
                        id: ring1
                        width: 240; height: 240; radius: 120
                        anchors.centerIn: parent
                        color: "transparent"
                        border.color: root.text
                        border.width: 2
                        scale: 0.8; opacity: 0.0
                    }
                    Item {
                        id: introLockOrb
                        width: 170; height: 170
                        anchors.centerIn: parent
                        scale: 0.0; opacity: 0.0
                        Rectangle {
                            anchors.fill: parent; radius: 85
                            color: Qt.rgba(root.surface0.r, root.surface0.g, root.surface0.b, 0.9)
                            border.color: root.text; border.width: 2
                        }
                        Text {
                            id: introIconUnlocked
                            anchors.centerIn: parent
                            text: "󰌿"; font.family: "Iosevka Nerd Font"; font.pixelSize: 64
                            color: root.text; opacity: 1.0; scale: 1.0
                        }
                        Text {
                            id: introIconLocked
                            anchors.centerIn: parent
                            text: "󰌾"; font.family: "Iosevka Nerd Font"; font.pixelSize: 64
                            color: root.text; opacity: 0.0; scale: 1.6
                        }
                    }
                    SequentialAnimation {
                        id: introSequence
                        ParallelAnimation {
                            NumberAnimation { target: introLockOrb; property: "scale"; from: 0.0; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
                            NumberAnimation { target: introLockOrb; property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring1; property: "scale"; from: 0.8; to: 1.25; duration: 250; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring1; property: "opacity"; from: 0.6; to: 0.0; duration: 250; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring2; property: "scale"; from: 0.8; to: 1.4; duration: 300; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring2; property: "opacity"; from: 0.4; to: 0.0; duration: 300; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring3; property: "scale"; from: 0.5; to: 1.5; duration: 350; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring3; property: "opacity"; from: 0.3; to: 0.0; duration: 350; easing.type: Easing.OutCubic }
                            SequentialAnimation {
                                PauseAnimation { duration: 300 }
                                ParallelAnimation {
                                    NumberAnimation { target: introIconUnlocked; property: "scale"; from: 1.0; to: 0.5; duration: 100; easing.type: Easing.InCubic }
                                    NumberAnimation { target: introIconUnlocked; property: "opacity"; from: 1.0; to: 0.0; duration: 50 }
                                    NumberAnimation { target: introIconLocked; property: "scale"; from: 1.6; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                                    NumberAnimation { target: introIconLocked; property: "opacity"; from: 0.0; to: 1.0; duration: 100 }
                                    SequentialAnimation {
                                        NumberAnimation { target: introLockOrb; property: "anchors.verticalCenterOffset"; from: 0; to: 3; duration: 40; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: introLockOrb; property: "anchors.verticalCenterOffset"; from: 3; to: 0; duration: 120; easing.type: Easing.OutBack }
                                    }
                                }
                            }
                        }
                        PauseAnimation { duration: 50 }
                        SequentialAnimation {
                            ParallelAnimation {
                                NumberAnimation { target: introLockOrb; property: "scale"; to: 1.8; duration: 100; easing.type: Easing.InCubic }
                                NumberAnimation { target: introOverlay; property: "opacity"; to: 0.0; duration: 100; easing.type: Easing.InCubic }
                            }
                            NumberAnimation { target: screenRoot; property: "introState"; from: 0.0; to: 1.0; duration: 100; easing.type: Easing.OutCubic }
                        }
                        PropertyAction { target: screenRoot; property: "isPlayingIntro"; value: false }
                        ScriptAction { script: { inputField.text = ""; inputField.forceActiveFocus(); } }
                    }
                }
            }
        }
    }
}
