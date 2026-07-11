pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

// Step 4 body: a few genuinely-wired quick choices, each through the same path the
// full Hub uses, so the change is live and real. Wallpaper shuffles via
// `ryoku-shell`; bar position, bar skin, and the frame corner are merged into
// ~/.config/ryoku/shell.json with a key-preserving write (the shell watches the
// file and retunes, no reload); window corner rounding round-trips the Hub's
// appearance overrides through `ryoku-hub hypr get`/`save`. Scrolls if the window
// is short.
Flickable {
    id: step

    contentHeight: col.implicitHeight
    contentWidth: width
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick

    readonly property string cfgPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"

    property string barPosition: "top"
    property string barStyle: "noctalia"
    property real frameRadius: 9
    property real windowRounding: 8

    // read the current shell values so the controls open on the live state.
    function syncFromDisk() {
        try {
            var o = JSON.parse(shellFile.text() || "{}");
            if (o.barPosition) step.barPosition = o.barPosition;
            if (o.barStyle) step.barStyle = o.barStyle;
            if (typeof o.frameRadius === "number") step.frameRadius = o.frameRadius;
        } catch (e) {}
    }

    // merge one key into shell.json without dropping the rest. JsonAdapter would
    // serialise only its declared keys and clobber the others, so write the whole
    // parsed object back with setText (atomic by default).
    function setKey(k, v) {
        var o = {};
        try { o = JSON.parse(shellFile.text() || "{}"); } catch (e) { o = {}; }
        o[k] = v;
        shellFile.setText(JSON.stringify(o, null, 2) + "\n");
    }

    // window rounding lives in the Hub's appearance overrides. Round-trip the whole
    // document through `hypr get`/`save` so only rounding changes; save persists to
    // settings.lua and reloads Hyprland to apply it.
    function commitWindowRounding() { roundGet.running = true; }

    FileView {
        id: shellFile
        path: step.cfgPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    Process { id: wallProc; command: ["ryoku-shell", "wallpaper", "next"] }

    Process {
        id: roundInit
        command: ["ryoku-hub", "hypr", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    if (o.appearance && typeof o.appearance.rounding === "number")
                        step.windowRounding = o.appearance.rounding;
                } catch (e) {}
            }
        }
    }

    Process {
        id: roundGet
        command: ["ryoku-hub", "hypr", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    if (!o.appearance)
                        return;
                    o.appearance.rounding = Math.round(step.windowRounding);
                    roundSave.command = ["ryoku-hub", "hypr", "save", JSON.stringify(o)];
                    roundSave.running = true;
                } catch (e) {}
            }
        }
    }
    Process { id: roundSave }

    Component.onCompleted: {
        step.syncFromDisk();
        roundInit.running = true;
    }

    Column {
        id: col
        width: step.width
        spacing: 22

        // --- Wallpaper ----------------------------------------------------
        Column {
            width: parent.width
            spacing: 12

            Text {
                text: "Wallpaper"
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11
                font.letterSpacing: 2.4
                font.capitalization: Font.AllUppercase
            }
            Row {
                width: parent.width
                spacing: 16
                WelcomeButton {
                    kind: "solid"
                    label: "Shuffle"
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: wallProc.running = true
                }
                Text {
                    width: parent.width - 150
                    anchors.verticalCenter: parent.verticalCenter
                    wrapMode: Text.WordWrap
                    text: "Roll a new wallpaper \u2014 the whole desktop rethemes. Your palette follows it."
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 13
                    lineHeight: 1.25
                }
            }
        }

        // --- Bar position -------------------------------------------------
        Column {
            width: parent.width
            spacing: 12
            Text {
                text: "Bar position"
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11
                font.letterSpacing: 2.4
                font.capitalization: Font.AllUppercase
            }
            ChipRow {
                width: parent.width
                model: [{ "key": "top", "label": "Top" }, { "key": "bottom", "label": "Bottom" }]
                current: step.barPosition
                onSelected: (k) => { step.barPosition = k; step.setKey("barPosition", k); }
            }
        }

        // --- Bar skin -----------------------------------------------------
        Column {
            width: parent.width
            spacing: 12
            Text {
                text: "Bar skin"
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11
                font.letterSpacing: 2.4
                font.capitalization: Font.AllUppercase
            }
            ChipRow {
                width: parent.width
                model: [
                    { "key": "noctalia",  "label": "Noctalia" },
                    { "key": "caelestia", "label": "Caelestia" },
                    { "key": "aegis",     "label": "Aegis" },
                    { "key": "stele",     "label": "Stele" },
                    { "key": "triptych",  "label": "Triptych" },
                    { "key": "delos",     "label": "Delos" }
                ]
                current: step.barStyle
                onSelected: (k) => { step.barStyle = k; step.setKey("barStyle", k); }
            }
        }

        // --- Roundness ----------------------------------------------------
        Column {
            width: parent.width
            spacing: 14
            Text {
                text: "Roundness"
                color: Theme.dim
                font.family: Theme.mono
                font.pixelSize: 11
                font.letterSpacing: 2.4
                font.capitalization: Font.AllUppercase
            }
            SliderRow {
                width: parent.width
                label: "Shell frame"
                unit: "px"
                from: 0; to: 60; step: 1
                value: step.frameRadius
                onMoved: (v) => step.frameRadius = v
                onReleased: (v) => step.setKey("frameRadius", Math.round(v))
            }
            SliderRow {
                width: parent.width
                label: "Windows"
                unit: "px"
                from: 0; to: 30; step: 1
                value: step.windowRounding
                onMoved: (v) => step.windowRounding = v
                onReleased: (v) => step.commitWindowRounding()
            }
        }

        Row {
            width: parent.width
            spacing: 10
            Rectangle { width: 14; height: 1.5; color: Theme.gold; anchors.verticalCenter: hint.verticalCenter }
            Text {
                id: hint
                width: col.width - 24
                wrapMode: Text.WordWrap
                text: "Every other knob \u2014 sidebars, widgets, colours \u2014 waits for you in Settings \u2192 Shell."
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: 13
            }
        }
    }
}
