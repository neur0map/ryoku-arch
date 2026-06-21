pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"
// Appearance: the system look and feel. Look/Borders/Cursor edit the Hyprland
// config live through the ryoku-hub hypr backend (settings.lua, applied via
// hyprctl eval; Save persists, Revert and leaving restore). Wallpaper retheme the
// desktop (the wallust palette follows the wallpaper) via ryoku-shell, and Comfort
// (backlight, night light) act at once through the shipped tools.
Item {
    id: page

    HyprStore { id: store }

    // Read by the hub to drop an unsaved live preview when this page is left.
    readonly property bool previewDirty: store.dirty

    property string group: "look"
    property var cursorThemes: []

    Process {
        id: cursorsProc
        command: ["ryoku-hub", "hypr", "cursors"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { page.cursorThemes = JSON.parse(this.text); } catch (e) {}
            }
        }
    }

    readonly property bool storeTab: page.group === "look" || page.group === "borders" || page.group === "cursor"

    // --- Wallpaper (the theme): pick one to retheme via the wallust palette. Routes
    // through ryoku-shell wallpaper, the same path the shell's quick strip uses. ---
    readonly property string wpDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    readonly property string wpState: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku-wallpaper"
    property var wallpapers: []
    property string currentWall: ""

    function refreshWalls() { wallListProc.running = true; wallStateProc.running = true; }
    function applyWall(p) {
        page.currentWall = p;
        wallApplyProc.command = ["ryoku-shell", "wallpaper", "set", p];
        wallApplyProc.running = true;
    }

    Process {
        id: wallListProc
        command: ["sh", "-c", "find \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -printf '%T@\\t%p\\n' | sort -rn", "_", page.wpDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n"), out = [];
                for (var i = 0; i < lines.length; i++) {
                    var tab = lines[i].indexOf("\t");
                    if (tab < 1)
                        continue;
                    var p = lines[i].substring(tab + 1);
                    out.push({ "path": p, "name": p.substring(p.lastIndexOf("/") + 1) });
                }
                page.wallpapers = out;
            }
        }
    }
    Process {
        id: wallStateProc
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "_", page.wpState]
        stdout: StdioCollector { onStreamFinished: page.currentWall = this.text.trim() }
    }
    Process { id: wallApplyProc; stdout: StdioCollector { onStreamFinished: wallStateProc.running = true } }
    Process {
        id: wallNextProc
        command: ["ryoku-shell", "wallpaper", "next"]
        stdout: StdioCollector { onStreamFinished: wallStateProc.running = true }
    }

    // --- Comfort: backlight and night light, applied at once via the shipped tools. ---
    readonly property string scriptsDir: Quickshell.env("HOME") + "/.config/hypr/scripts/"
    property int brightness: -1
    property bool nightOn: false
    property int nightTemp: 4000

    function refreshComfort() { brightGetProc.running = true; nightStatusProc.running = true; }
    function setBrightness(v) {
        page.brightness = v;
        brightSetProc.command = ["brightnessctl", "set", v + "%"];
        brightSetProc.running = true;
    }
    function setNight(on) {
        page.nightOn = on;
        nightProc.command = on ? [page.scriptsDir + "ryoku-cmd-nightlight", "on", String(page.nightTemp)]
                               : [page.scriptsDir + "ryoku-cmd-nightlight", "off"];
        nightProc.running = true;
    }
    function setNightTemp(t) { page.nightTemp = t; if (page.nightOn) nightDebounce.restart(); }

    Process {
        id: brightGetProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                var first = this.text.trim().split("\n")[0];
                var pct = parseInt((first.split(",")[3] || "").replace("%", ""), 10);
                if (!isNaN(pct))
                    page.brightness = pct;
            }
        }
    }
    Process { id: brightSetProc }
    Process {
        id: nightStatusProc
        command: [page.scriptsDir + "ryoku-cmd-nightlight", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim().split(" ");
                page.nightOn = t[0] === "on";
                if (t.length > 1) {
                    var k = parseInt(t[1], 10);
                    if (!isNaN(k))
                        page.nightTemp = k;
                }
            }
        }
    }
    Process { id: nightProc }
    Timer { id: nightDebounce; interval: 300; onTriggered: if (page.nightOn) page.setNight(true) }

    onGroupChanged: {
        if (page.group === "wallpaper")
            page.refreshWalls();
        else if (page.group === "comfort")
            page.refreshComfort();
    }
    Component.onCompleted: { page.refreshWalls(); page.refreshComfort(); }

    Segmented {
        id: tabs
        anchors.left: parent.left
        anchors.top: parent.top
        model: [
            { "key": "look", "label": "Look" },
            { "key": "borders", "label": "Borders" },
            { "key": "cursor", "label": "Cursor" },
            { "key": "wallpaper", "label": "Wallpaper" },
            { "key": "comfort", "label": "Comfort" }
        ]
        current: page.group
        onSelected: (k) => page.group = k
    }

    Text {
        anchors.left: tabs.right
        anchors.leftMargin: 18
        anchors.verticalCenter: tabs.verticalCenter
        text: "Edits show on your desktop as you make them"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 12
        font.weight: Font.Medium
    }

    Flickable {
        id: flick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: tabs.bottom
        anchors.topMargin: 26
        anchors.bottom: page.storeTab ? bar.top : parent.bottom
        anchors.bottomMargin: 18
        contentWidth: width
        contentHeight: Math.max(loader.height, height)
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

        Loader {
            id: loader
            width: flick.width - 12
            height: item ? item.implicitHeight : 0
            y: 0
            sourceComponent: page.group === "look" ? lookComp
                : page.group === "borders" ? bordersComp
                : page.group === "cursor" ? cursorComp
                : page.group === "wallpaper" ? wallpaperComp
                : comfortComp
            onLoaded: {
                if (!item)
                    return;
                item.opacity = 0;
                fade.restart();
            }
        }

        NumberAnimation { id: fade; target: loader.item; property: "opacity"; to: 1; duration: Theme.medium; easing.type: Theme.ease }
    }

    Component {
        id: lookComp
        Row {
            id: lookRow
            spacing: 56
            readonly property real colW: (width - spacing) / 2

            Column {
                width: lookRow.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "SHAPE"
                    NumberField {
                        width: parent.width; label: "Corner radius"; unit: "px"
                        from: 0; to: 30; value: store.rounding
                        onModified: (v) => store.edit("rounding", v)
                    }
                    NumberField {
                        width: parent.width; label: "Border thickness"; unit: "px"
                        from: 0; to: 12; value: store.borderSize
                        onModified: (v) => store.edit("borderSize", v)
                    }
                    ChoiceRow {
                        width: parent.width; label: "Tiling layout"
                        options: [{ "key": "dwindle", "label": "Dwindle" }, { "key": "master", "label": "Master" }]
                        current: store.layout
                        onChosen: (k) => store.edit("layout", k)
                    }
                }

                SettingSection {
                    width: parent.width
                    title: "GAPS"
                    NumberField {
                        width: parent.width; label: "Inner (between windows)"; unit: "px"
                        from: 0; to: 40; value: store.gapsIn
                        onModified: (v) => store.edit("gapsIn", v)
                    }
                    NumberField {
                        width: parent.width; label: "Outer (screen edge)"; unit: "px"
                        from: 0; to: 60; value: store.gapsOut
                        onModified: (v) => store.edit("gapsOut", v)
                    }
                }
            }

            Column {
                width: lookRow.colW
                spacing: 30

                SettingSection {
                    width: parent.width
                    title: "OPACITY"
                    SliderRow {
                        width: parent.width; label: "Active"; percent: true
                        from: 0.4; to: 1; step: 0.01; value: store.activeOpacity
                        onModified: (v) => store.edit("activeOpacity", v)
                    }
                    SliderRow {
                        width: parent.width; label: "Inactive"; percent: true
                        from: 0.4; to: 1; step: 0.01; value: store.inactiveOpacity
                        onModified: (v) => store.edit("inactiveOpacity", v)
                    }
                }

                SettingSection {
                    width: parent.width
                    title: "BLUR"
                    ToggleRow {
                        width: parent.width; label: "Enabled"
                        checked: store.blurEnabled
                        onToggled: (v) => store.edit("blurEnabled", v)
                    }
                    NumberField {
                        width: parent.width; label: "Size"; unit: "px"
                        from: 0; to: 20; value: store.blurSize
                        onModified: (v) => store.edit("blurSize", v)
                    }
                    NumberField {
                        width: parent.width; label: "Passes"
                        from: 1; to: 6; value: store.blurPasses
                        onModified: (v) => store.edit("blurPasses", v)
                    }
                }

                SettingSection {
                    width: parent.width
                    title: "DEPTH & MOTION"
                    ToggleRow {
                        width: parent.width; label: "Window shadows"
                        checked: store.shadowEnabled
                        onToggled: (v) => store.edit("shadowEnabled", v)
                    }
                    NumberField {
                        width: parent.width; label: "Shadow range"; unit: "px"
                        from: 0; to: 60; value: store.shadowRange
                        onModified: (v) => store.edit("shadowRange", v)
                    }
                    ToggleRow {
                        width: parent.width; label: "Animations"
                        checked: store.animations
                        onToggled: (v) => store.edit("animations", v)
                    }
                }
            }
        }
    }

    Component {
        id: bordersComp
        Column {
            spacing: 30

            SettingSection {
                width: parent.width
                title: "WINDOW BORDERS"
                ToggleRow {
                    width: Math.min(parent.width, 460); label: "Follow wallpaper palette"
                    checked: store.followWallpaper
                    onToggled: (v) => store.edit("followWallpaper", v)
                }
                Text {
                    width: Math.min(parent.width, 620)
                    wrapMode: Text.WordWrap
                    text: store.followWallpaper
                        ? "Border colours track the wallust palette derived from your wallpaper."
                        : "Borders use the fixed colours below, ignoring the wallpaper palette."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            SettingSection {
                width: parent.width
                visible: !store.followWallpaper
                title: "FIXED COLOURS"
                ColorField {
                    width: parent.width; label: "Active window"
                    value: store.activeBorder
                    onModified: (v) => store.edit("activeBorder", v)
                }
                ColorField {
                    width: parent.width; label: "Inactive window"
                    value: store.inactiveBorder
                    onModified: (v) => store.edit("inactiveBorder", v)
                }
            }
        }
    }

    Component {
        id: cursorComp
        Column {
            spacing: 30

            SettingSection {
                width: parent.width
                title: "CURSOR"
                Dropdown {
                    width: Math.min(parent.width, 460); label: "Theme"
                    fieldWidth: 240
                    options: page.cursorThemes
                    current: store.cursorTheme
                    placeholder: store.cursorTheme
                    onChosen: (k) => store.edit("cursorTheme", k)
                }
                NumberField {
                    width: Math.min(parent.width, 460); label: "Size"; unit: "px"
                    from: 12; to: 64; step: 4; value: store.cursorSize
                    onModified: (v) => store.edit("cursorSize", v)
                }
                Text {
                    width: Math.min(parent.width, 620)
                    wrapMode: Text.WordWrap
                    text: "Themes are read from your installed icon sets. The change applies to the running session at once and to apps you open next."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }
    }

    Component {
        id: wallpaperComp
        Column {
            spacing: 22
            SettingSection {
                width: parent.width
                title: "WALLPAPER"
                Row {
                    width: parent.width
                    spacing: 12
                    Text {
                        width: parent.width - shuffleBtn.width - 12
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.WordWrap
                        text: "Pick a wallpaper to retheme the desktop. The palette (borders, accents) follows it."
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                    HubButton {
                        id: shuffleBtn
                        anchors.verticalCenter: parent.verticalCenter
                        label: "Shuffle"
                        icon: "refresh"
                        onClicked: wallNextProc.running = true
                    }
                }
                Flow {
                    width: parent.width
                    spacing: 12
                    Repeater {
                        model: page.wallpapers
                        delegate: Rectangle {
                            id: wp
                            required property var modelData
                            readonly property bool active: page.currentWall === wp.modelData.path
                            width: 172
                            height: 104
                            radius: 10
                            color: Theme.surfaceLo
                            border.width: wp.active ? 2 : 1
                            border.color: wp.active ? Theme.ember : (wpHov.hovered ? Theme.cream : Theme.line)
                            clip: true
                            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                            Image {
                                anchors.fill: parent
                                anchors.margins: 2
                                source: "file://" + wp.modelData.path
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: 360
                                sourceSize.height: 220
                                asynchronous: true
                                cache: false
                            }

                            HoverHandler { id: wpHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: page.applyWall(wp.modelData.path) }
                            scale: wpHov.hovered ? 1.03 : 1
                            Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
                        }
                    }
                }
                Text {
                    visible: page.wallpapers.length === 0
                    text: "No wallpapers in ~/Pictures/Wallpapers."
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }
        }
    }

    Component {
        id: comfortComp
        Column {
            spacing: 30
            SettingSection {
                width: parent.width
                title: "BACKLIGHT"
                SliderRow {
                    width: Math.min(parent.width, 460); label: "Brightness"; percent: true
                    from: 0.05; to: 1; step: 0.01
                    value: page.brightness < 0 ? 1 : page.brightness / 100
                    onModified: (v) => page.setBrightness(Math.round(v * 100))
                }
            }
            SettingSection {
                width: parent.width
                title: "NIGHT LIGHT"
                ToggleRow {
                    width: Math.min(parent.width, 460); label: "Warm the screen"
                    checked: page.nightOn
                    onToggled: (v) => page.setNight(v)
                }
                SliderRow {
                    width: Math.min(parent.width, 460); label: "Temperature"
                    from: 2500; to: 6500; step: 100; decimals: 0
                    value: page.nightTemp
                    onModified: (v) => page.setNightTemp(Math.round(v))
                }
                Text {
                    width: Math.min(parent.width, 620)
                    wrapMode: Text.WordWrap
                    text: "Lowers blue light for evening use. Stays on until you turn it off, across sessions."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
        }
    }

    // --- action bar (mirrors Shell Settings) --------------------------------
    Rectangle {
        id: bar
        visible: page.storeTab
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
                onClicked: store.resetAppearance()
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
