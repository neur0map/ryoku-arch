pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "Singletons"

// The first-run walkthrough: a five-step guided tour over the Greek-noir threshold
// art. Left half is the constant chrome (brand lockup, progress) laid over the art;
// the right half carries the current step (header + body) and the tour navigation.
// Shown once on first login (autostart guards a state flag), and dismissible any
// time (Escape / Skip / close) -- the daemon marks it seen after this window exits.
Rectangle {
    id: root

    color: Theme.bgBot
    focus: true
    implicitWidth: 1180
    implicitHeight: 760
    function ink(a) { return Qt.rgba(15 / 255, 12 / 255, 7 / 255, a); }

    readonly property var steps: [
        { "eyebrow": "Welcome",          "title": "Welcome to Ryoku",     "subtitle": "\u529b \u00b7 a hand-built Greek-noir desktop on Arch and Hyprland.", "next": "Take the tour" },
        { "eyebrow": "Getting around",   "title": "The keys that matter", "subtitle": "Six shortcuts open almost everything.",                              "next": "Next" },
        { "eyebrow": "Where things live","title": "Know your desktop",    "subtitle": "Four surfaces, and how to summon each one.",                          "next": "Next" },
        { "eyebrow": "Make it yours",    "title": "A few quick choices",  "subtitle": "Set the essentials now; the rest waits in Settings.",                 "next": "Next" },
        { "eyebrow": "Ready",            "title": "You're all set",       "subtitle": "Everything from here is yours to change.",                            "next": "Enter Ryoku" }
    ]
    readonly property int lastStep: steps.length - 1
    property int step: 0

    function advance() { if (step < lastStep) step += 1; else finish(); }
    function back() { if (step > 0) step -= 1; }
    function goTo(i) { if (i >= 0 && i <= lastStep) step = i; }
    function finish() { Qt.quit(); }

    // Open Ryoku Settings, then close the tour. setsid forks the Hub into its own
    // session so it survives this process exiting; flock mirrors the Super+, launch
    // guard so a second instance no-ops instead of stacking.
    function openHubAndFinish() { hubProc.running = true; quitFallback.restart(); }

    Process {
        id: hubProc
        command: ["setsid", "-f", "flock", "-n", "-o", "/tmp/ryoku-hub.lock", "qs", "-c", "hub"]
        onExited: Qt.quit()
    }
    Timer { id: quitFallback; interval: 1500; onTriggered: Qt.quit() }

    Keys.onEscapePressed: root.finish()
    Keys.onReturnPressed: root.advance()
    Keys.onEnterPressed: root.advance()
    Keys.onRightPressed: root.advance()
    Keys.onLeftPressed: root.back()

    Backdrop { anchors.fill: parent }

    // content scrim: darken the right half where the step content sits, leaving the
    // left (statue + red sun) clear. Horizontal so the art dissolves into legibility.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0;  color: root.ink(0) }
            GradientStop { position: 0.42; color: root.ink(0) }
            GradientStop { position: 0.62; color: root.ink(0.74) }
            GradientStop { position: 1.0;  color: root.ink(0.92) }
        }
    }

    // bottom + top scrims (full width) for the chrome laid over the art.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0;  color: root.ink(0.34) }
            GradientStop { position: 0.16; color: root.ink(0) }
            GradientStop { position: 0.74; color: root.ink(0) }
            GradientStop { position: 1.0;  color: root.ink(0.72) }
        }
    }

    // --- left chrome: brand lockup ----------------------------------------
    Row {
        id: brand
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 40
        anchors.topMargin: 34
        spacing: 13

        Item {
            width: 42
            height: 42
            anchors.verticalCenter: parent.verticalCenter

            Rectangle { x: 4; y: 4; width: 42; height: 42; color: Theme.shadow; antialiasing: false }
            Rectangle {
                anchors.fill: parent
                color: Theme.brand
                Text {
                    anchors.centerIn: parent
                    text: "\u529b"
                    color: Theme.onAccent
                    font.family: Theme.fontJp
                    font.pixelSize: 24
                    font.weight: Font.Bold
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                text: "RYOKU"
                color: Theme.bright
                font.family: Theme.mono
                font.pixelSize: 17
                font.weight: Font.Bold
                font.letterSpacing: 3.5
            }
            Text {
                text: "FIRST LIGHT"
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 2.6
            }
        }
    }

    // --- left chrome: progress -------------------------------------------
    Column {
        id: progress
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 42
        anchors.bottomMargin: 40
        spacing: 14

        Row {
            spacing: 9
            Repeater {
                model: root.steps.length
                delegate: Rectangle {
                    id: dot
                    required property int index
                    readonly property bool active: root.step === index
                    readonly property bool done: index < root.step
                    width: active ? 26 : 9
                    height: 9
                    radius: 4.5
                    color: active ? Theme.brand : (done ? Theme.emberDeep : Theme.faint)
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on width { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
                    Behavior on color { ColorAnimation { duration: Theme.medium } }

                    HoverHandler { id: dh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.goTo(dot.index) }
                }
            }
        }

        Text {
            text: ("0" + (root.step + 1)).slice(-2) + "  /  0" + root.steps.length
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 11
            font.letterSpacing: 2
        }
    }

    // --- right column: the step ------------------------------------------
    Item {
        id: rightCol
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: 52
        anchors.topMargin: 104
        anchors.bottomMargin: 40
        width: Math.min(520, root.width * 0.46)

        // header + body, revealed together on each step change.
        Item {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: nav.top
            anchors.bottomMargin: 24
            opacity: 0
            transform: Translate { id: slide; y: 16 }

            Column {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 14

                Eyebrow { text: root.steps[root.step].eyebrow }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: root.steps[root.step].title
                    color: Theme.bright
                    font.family: Theme.display
                    font.pixelSize: root.step === 0 ? 42 : 31
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    lineHeight: 0.98
                }

                Text {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    text: root.steps[root.step].subtitle
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 15
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                }
            }

            Loader {
                id: bodyLoader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.topMargin: 30
                anchors.bottom: parent.bottom
                clip: true
                sourceComponent: root.bodyFor(root.step)
            }

            Connections {
                target: bodyLoader.item
                ignoreUnknownSignals: true
                function onOpenSettings() { root.openHubAndFinish(); }
            }
        }

        // navigation: stable across steps for easy orientation.
        Item {
            id: nav
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 40

            WelcomeButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                kind: "ghost"
                label: "Skip the tour"
                visible: root.step < root.lastStep
                onClicked: root.finish()
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                WelcomeButton {
                    kind: "ghost"
                    label: "Back"
                    visible: root.step > 0
                    onClicked: root.back()
                }
                WelcomeButton {
                    kind: "solid"
                    label: root.steps[root.step].next
                    onClicked: root.advance()
                }
            }
        }
    }

    function bodyFor(i) {
        switch (i) {
        case 0: return cWelcome;
        case 1: return cBasics;
        case 2: return cDesktop;
        case 3: return cCustomize;
        default: return cReady;
        }
    }

    Component { id: cWelcome;   StepWelcome {} }
    Component { id: cBasics;    StepBasics {} }
    Component { id: cDesktop;   StepDesktop {} }
    Component { id: cCustomize; StepCustomize {} }
    Component { id: cReady;     StepReady {} }

    // reveal the step content on every change.
    SequentialAnimation {
        id: reveal
        PropertyAction { target: content; property: "opacity"; value: 0 }
        PropertyAction { target: slide; property: "y"; value: 16 }
        ParallelAnimation {
            NumberAnimation { target: content; property: "opacity"; to: 1; duration: Theme.medium; easing.type: Theme.ease }
            NumberAnimation { target: slide; property: "y"; to: 0; duration: Theme.slow; easing.type: Theme.ease }
        }
    }
    onStepChanged: reveal.restart()
    Component.onCompleted: reveal.restart()
}
