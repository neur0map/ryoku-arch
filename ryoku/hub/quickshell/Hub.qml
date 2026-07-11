pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import Quickshell
import "Singletons"

// Ryoku Settings = the nav rail (which owns global search) next to a content
// area. no query -> selected section. with a query -> global results across
// every section. data + persisted state come from the ryoku-hub Go backend.
// most sections edit the live Hyprland (lua) config through that backend;
// Shell tunes the desktop shell; Updates tracks the channel.
Rectangle {
    id: hub

    implicitWidth: 1360
    implicitHeight: 880

    property string section: "displays"
    property var keybindsModel: []
    readonly property bool searching: navRail.query.length > 0

    readonly property var sectionDefs: [
        { "key": "profile",     "name": "Profile",         "icon": "user",     "pinned": "top" },
        { "key": "displays",    "name": "Displays",        "icon": "display",  "group": "System" },
        { "key": "input",       "name": "Input",           "icon": "mouse",    "group": "System" },
        { "key": "keybinds",    "name": "Keybinds",        "icon": "keyboard", "group": "System" },
        { "key": "dictation",   "name": "Dictation",       "icon": "mic",      "group": "System" },
        { "key": "connections", "name": "Connections",     "icon": "wifi",     "group": "System" },
        { "key": "gpu",         "name": "GPU",             "icon": "chip",     "group": "System" },
        { "key": "recording",   "name": "Recording",       "icon": "play",     "group": "System" },
        { "key": "updates",     "name": "Updates",         "icon": "download", "pinned": "bottom" },
        { "key": "credits",     "name": "Credits",         "icon": "heart",    "pinned": "bottom" },
        { "key": "appearance",  "name": "Appearance",      "icon": "palette",  "group": "Desktop" },
        { "key": "animations",  "name": "Animations",      "icon": "motion",   "group": "Desktop" },
        { "key": "lockscreen",  "name": "Lockscreen",      "icon": "lock",     "group": "Desktop" },
        { "key": "widgets",     "name": "Desktop Widgets", "icon": "widgets",  "group": "Desktop" },
        { "key": "shell",       "name": "Shell",           "icon": "gear",     "group": "Desktop" },
        { "key": "launcher",    "name": "App Launcher",    "icon": "search",   "group": "Desktop" },
        { "key": "store",       "name": "Store",           "icon": "sparkles", "group": "Add-ons" },
        { "key": "addons",      "name": "Installed",       "icon": "widgets",  "group": "Add-ons" },
        { "key": "windowrules", "name": "Window Rules",    "icon": "window",   "group": "Advanced" },
        { "key": "appoverrides", "name": "App Overrides",  "icon": "window",   "group": "Advanced" },
        { "key": "layerrules",  "name": "Layer Rules",     "icon": "window",   "group": "Advanced" },
        { "key": "autostart",   "name": "Autostart",       "icon": "rocket",   "group": "Advanced" },
        { "key": "environment", "name": "Environment",     "icon": "variable", "group": "Advanced" },
        { "key": "performance", "name": "Performance",     "icon": "rocket",   "group": "Advanced" },
        { "key": "rashin",      "name": "Rashin",          "icon": "compass",  "group": "Advanced" }
    ]

    readonly property var pageMeta: ({
        "profile":     { "title": "Profile", "subtitle": "Your machine as a collector's specimen, built to share alongside your rice." },
        "displays":    { "title": "Displays", "subtitle": "Detect and arrange your monitors: resolution, scale, rotation, mirroring, and saved layout profiles." },
        "appearance":  { "title": "Appearance", "subtitle": "Window look: gaps, rounding, borders, opacity, blur, shadows, animations, and the cursor theme." },
        "lockscreen":  { "title": "Lockscreen", "subtitle": "Choose the skin your lock screen wears. Ryoku ships the clockwork theme; picking one only swaps the look, never your login." },
        "animations":  { "title": "Animations", "subtitle": "Tune Hyprland's animations and edit bezier curves with a live preview." },
        "input":       { "title": "Input", "subtitle": "Keyboard layout, pointer feel, touchpad behaviour, and key repeat." },
        "keybinds":    { "title": "Keybinds", "subtitle": "Every shortcut in the Ryoku desktop, read live from your Hyprland config, plus your own custom binds." },
        "dictation":   { "title": "Dictation", "subtitle": "Voice typing with Voxtype: pick a speech-to-text engine and model, add a cloud API key if you use one, and dictate into any app with the voice keybind." },
        "windowrules": { "title": "Window Rules", "subtitle": "Float, size, pin, or place windows by class or title." },
        "appoverrides": { "title": "App Overrides", "subtitle": "Give a specific app its own look: opacity, corners, border, blur, shadow, and animations, overriding the global Appearance." },
        "layerrules":  { "title": "Layer Rules", "subtitle": "Tweak layer-shell surfaces (bars, launchers) by namespace: blur, dim, no animation." },
        "autostart":   { "title": "Autostart", "subtitle": "Commands that run when the session starts." },
        "environment": { "title": "Environment", "subtitle": "Environment variables for the Hyprland session." },
        "shell":       { "title": "Shell", "subtitle": "Tune the Ryoku shell: the frame, the bar, notifications, and the desktop visualiser." },
        "widgets":     { "title": "Desktop Widgets", "subtitle": "Clock and weather on the wallpaper: pick a design, size, shape, and placement, with a live preview that follows your palette." },
        "launcher":    { "title": "App Launcher", "subtitle": "Tune the command palette you open with Super+Space: its roundness, the weather units, and the home card's backdrop and greeting." },
        "connections": { "title": "Connections", "subtitle": "Wi-Fi networks, Bluetooth devices, and your hotspot, all in one place." },
        "gpu":         { "title": "GPU", "subtitle": "Choose which GPU Ryoku renders on. GPU passthrough is an optional advanced path that frees the discrete GPU for a VM; run virtual machines from the ryovm app." },
        "recording":   { "title": "Recording", "subtitle": "Screen recording quality: framerate, definition, codec, and the hardware encoder Ryoku uses for your machine. Start and stop from the bar's screen-capture Tools." },
        "updates":     { "title": "Updates", "subtitle": "Updates pending for your Ryoku system." },
        "credits":     { "title": "Credits", "subtitle": "The projects, communities, and people Ryoku is built on, and the alpha and beta testers who keep it honest." },
        "store":       { "title": "Store", "subtitle": "Browse and install shell plugins and extras bundles for the Ryoku desktop." },
        "addons":      { "title": "Add-ons", "subtitle": "Your installed plugins. Open one to change its settings, enable it, or remove it." },
        "performance": { "title": "Performance", "subtitle": "Opt-in tweaks that trade a little eye-candy for lower CPU, GPU, and memory use on modest hardware." },
        "rashin":      { "title": "Rashin", "subtitle": "Rashin, the needle (羅針): an optional local agent OS. A maintained system map plus the Hermes agent point every coding agent straight at your machine's answers." }
    })

    function known(s) {
        for (var i = 0; i < hub.sectionDefs.length; i++)
            if (hub.sectionDefs[i].key === s)
                return true;
        return false;
    }

    // The section's group name, for the page eyebrow ("SYSTEM", "DESKTOP", …).
    // Pinned sections (Profile, Updates) have no group; label them "Settings".
    function groupFor(s) {
        for (var i = 0; i < hub.sectionDefs.length; i++)
            if (hub.sectionDefs[i].key === s)
                return hub.sectionDefs[i].group || "Settings";
        return "Settings";
    }

    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.bgTop }
        GradientStop { position: 1.0; color: Theme.bgBot }
    }

    focus: true
    Keys.onEscapePressed: Qt.quit()
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_K && (e.modifiers & Qt.ControlModifier)) {
            navRail.focusSearch();
            e.accepted = true;
        }
    }

    Process {
        id: kbProc
        command: ["ryoku-hub", "keybinds"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    hub.keybindsModel = JSON.parse(this.text).categories;
                } catch (e) {
                    console.log("hub: keybinds parse failed: " + e);
                }
            }
        }
    }

    Process {
        id: loadSection
        command: ["ryoku-hub", "config", "get", "section"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var s = this.text.trim();
                if (hub.known(s))
                    hub.section = s;
            }
        }
    }

    Process { id: saveSection }
    Process { id: restoreProc }

    function go(s) {
        navRail.query = "";
        if (hub.section === s)
            return;
        // leaving a live-preview page (Appearance, Input) with unsaved edits:
        // reset the desktop to the saved state. the page's own teardown can't
        // run a process reliably, so the persistent hub does it.
        if (pageLoader.item && pageLoader.item.previewDirty === true) {
            restoreProc.command = ["ryoku-hub", "hypr", "restore"];
            restoreProc.running = true;
        }
        hub.section = s;
        saveSection.command = ["ryoku-hub", "config", "set", "section", s];
        saveSection.running = true;
    }

    // The section's config files for the header buttons, split by ownership.
    // edit = the durable file you can hand-edit and keep across updates
    // (hypr/user.lua for the Hyprland sections, monitors_user.lua for Displays,
    // or a Hub-owned JSON); view = Ryoku's shipped defaults, read-only, since an
    // update replaces them. settings.lua is deliberately NOT shown: it is
    // generated from your Hub choices (hypr.json) and rewritten on every Save,
    // so it is never a file to open or edit. GPU is view-only (ryoku-gpu writes
    // it). editTip/viewTip explain each button in a hover tooltip.
    function configFor(s) {
        var base = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config");
        var hypr = base + "/hypr";
        var ryoku = base + "/ryoku";
        var user = hypr + "/user.lua";
        var mod = hypr + "/modules/";
        // shared tooltips for the Hyprland sections, whose edit target is user.lua.
        var userTip = "Your own Hyprland Lua, loaded last so it wins over everything here. For tweaks the settings above don't cover; updates never touch it. What you set above is saved separately and also survives updates, so you rarely need this.";
        var defTip = "Read-only. Ryoku's shipped defaults for this section. An update replaces this file, so make your changes above, in the GUI.";
        function luaSec(view) { return { "edit": [user], "view": view, "editLabel": "Edit user.lua", "editTip": userTip, "viewTip": defTip }; }
        switch (s) {
        case "input":       return luaSec([mod + "input.lua"]);
        case "keybinds":    return luaSec([mod + "binds.lua"]);
        case "appearance":  return luaSec([mod + "decoration.lua"]);
        case "animations":  return luaSec([mod + "animations.lua"]);
        case "windowrules": return luaSec([mod + "window_rules.lua"]);
        case "appoverrides": return luaSec([mod + "window_rules.lua"]);
        case "layerrules":  return luaSec([]);
        case "autostart":   return luaSec([mod + "autostart.lua"]);
        case "environment": return luaSec([mod + "env.lua"]);
        case "displays":    return { "edit": [hypr + "/monitors_user.lua"], "view": [hypr + "/monitors.lua"], "editLabel": "Edit overrides", "editTip": "Hand-written display tweaks (forced modes, a pinned layout), loaded after the auto-detected layout so they win. Survives updates; see monitors_user.lua.example.", "viewTip": "Read-only. The display layout Ryoku detected and wrote; regenerated when your monitors change." };
        case "gpu":         return { "edit": [], "view": [hypr + "/gpu.lua"], "viewTip": "Read-only. GPU config written by ryoku-gpu; regenerated on GPU or driver changes." };
        case "shell":       return { "edit": [ryoku + "/shell.json", ryoku + "/visualizer.json"], "editLabel": "Edit config", "editTip": "Opens this section's config files, where the Hub saves your changes. Yours; survives updates." };
        case "widgets":     return { "edit": [ryoku + "/widgets.json"], "editLabel": "Edit config", "editTip": "Opens this section's config file, where the Hub saves your changes. Yours; survives updates." };
        case "launcher":    return { "edit": [ryoku + "/launcher.json"], "editLabel": "Edit config", "editTip": "Opens this section's config file, where the Hub saves your changes. Yours; survives updates." };
        case "performance": return { "edit": [ryoku + "/performance.json"], "editLabel": "Edit config", "editTip": "Opens this section's config file, where the Hub saves your changes. Yours; survives updates." };
        case "recording":   return { "edit": [ryoku + "/recording.json"], "editLabel": "Edit config", "editTip": "Opens this section's config file, where the Hub saves your changes. Yours; survives updates." };
        default:            return {};
        }
    }

    Row {
        anchors.fill: parent

        NavRail {
            id: navRail
            width: 252
            height: parent.height
            sections: hub.sectionDefs
            current: hub.section
            onNavigate: (s) => hub.go(s)
            onEscaped: Qt.quit()
        }

        Item {
            width: parent.width - 252
            height: parent.height

            PageHeader {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 40
                anchors.rightMargin: 64
                anchors.topMargin: 16
                eyebrow: hub.searching ? "Search" : hub.groupFor(hub.section)
                title: hub.searching ? "Search" : hub.pageMeta[hub.section].title
                subtitle: hub.searching ? "Results across every section" : hub.pageMeta[hub.section].subtitle
                editPaths: hub.searching ? [] : (hub.configFor(hub.section).edit || [])
                viewPaths: hub.searching ? [] : (hub.configFor(hub.section).view || [])
                editLabel: hub.searching ? "Edit user.lua" : (hub.configFor(hub.section).editLabel || "Edit user.lua")
                editTip: hub.searching ? "" : (hub.configFor(hub.section).editTip || "")
                viewTip: hub.searching ? "" : (hub.configFor(hub.section).viewTip || "")
            }

            Loader {
                id: pageLoader
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.leftMargin: 40
                anchors.rightMargin: 30
                anchors.topMargin: 14
                anchors.bottomMargin: 12

                sourceComponent: hub.searching ? searchComp : hub.pageFor(hub.section)

                onLoaded: {
                    if (!item)
                        return;
                    item.opacity = 0;
                    item.y = 10;
                    fadeAnim.target = item;
                    slideAnim.target = item;
                    fadeAnim.restart();
                    slideAnim.restart();
                }
            }

            NumberAnimation {
                id: fadeAnim
                property: "opacity"
                to: 1
                duration: Theme.medium
                easing.type: Theme.ease
            }

            NumberAnimation {
                id: slideAnim
                property: "y"
                to: 0
                duration: Theme.medium
                easing.type: Theme.ease
            }
        }
    }

    function pageFor(s) {
        switch (s) {
        case "profile": return profileComp;
        case "displays": return displaysComp;
        case "appearance": return appearanceComp;
        case "lockscreen": return lockscreenComp;
        case "animations": return animationsComp;
        case "input": return inputComp;
        case "keybinds": return keybindsComp;
        case "dictation": return dictationComp;
        case "windowrules": return windowRulesComp;
        case "appoverrides": return appOverridesComp;
        case "layerrules": return layerRulesComp;
        case "autostart": return autostartComp;
        case "environment": return environmentComp;
        case "widgets": return widgetsComp;
        case "launcher": return launcherComp;
        case "updates": return updatesComp;
        case "credits": return creditsComp;
        case "connections": return connectionsComp;
        case "gpu": return gpuComp;
        case "store": return storeComp;
        case "addons": return addonsComp;
        case "performance": return performanceComp;
        case "recording": return recordingComp;
        case "rashin": return rashinComp;
        default: return shellComp;
        }
    }

    Component { id: searchComp; SearchResults { categories: hub.keybindsModel; sections: hub.sectionDefs; query: navRail.query; onNavigate: (s) => hub.go(s) } }
    Component { id: profileComp; ProfilePage {} }
    Component { id: displaysComp; DisplaysPage {} }
    Component { id: appearanceComp; AppearancePage {} }
    Component { id: lockscreenComp; LockscreenPage {} }
    Component { id: animationsComp; AnimationsPage {} }
    Component { id: inputComp; InputPage {} }
    Component { id: keybindsComp; KeybindsPage { categories: hub.keybindsModel } }
    Component { id: dictationComp; DictationPage {} }
    Component { id: windowRulesComp; WindowRulesPage {} }
    Component { id: appOverridesComp; AppOverridesPage {} }
    Component { id: layerRulesComp; LayerRulesPage {} }
    Component { id: autostartComp; AutostartPage {} }
    Component { id: environmentComp; EnvironmentPage {} }
    Component { id: shellComp; ShellSettingsPage {} }
    Component { id: widgetsComp; WidgetsPage {} }
    Component { id: launcherComp; LauncherPage {} }
    Component { id: updatesComp; UpdatesPage {} }
    Component { id: creditsComp; CreditsPage {} }
    Component { id: storeComp; StorePage {} }
    Component { id: addonsComp; AddonsPage {} }
    Component { id: connectionsComp; ConnectionsPage {} }
    Component { id: gpuComp; GpuPage {} }
    Component { id: performanceComp; PerformancePage {} }
    Component { id: recordingComp; RecordingPage {} }
    Component { id: rashinComp; RashinPage {} }

    Item {
        id: closeBtn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 22
        width: 26
        height: 26

        Icon {
            anchors.centerIn: parent
            name: "close"
            size: 16
            tint: closeHover.hovered ? Theme.ember : Theme.faint
            Behavior on tint { ColorAnimation { duration: Theme.quick } }
        }

        HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Qt.quit() }
    }
}
