pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import "Singletons"

// Ryoku Settings: the navigation rail (which owns the global search) beside a
// content area. With no query the content shows the selected section; with a query
// it shows global results across every section. Data and persisted state come from
// the ryoku-hub Go backend. Most sections edit the live Hyprland (Lua) config
// through that backend; Shell tunes the desktop shell; Updates tracks the channel.
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
        { "key": "connections", "name": "Connections",     "icon": "wifi",     "group": "System" },
        { "key": "updates",     "name": "Updates",         "icon": "download", "pinned": "bottom" },
        { "key": "appearance",  "name": "Appearance",      "icon": "palette",  "group": "Desktop" },
        { "key": "animations",  "name": "Animations",      "icon": "motion",   "group": "Desktop" },
        { "key": "lockscreen",  "name": "Lockscreen",      "icon": "lock",     "group": "Desktop" },
        { "key": "widgets",     "name": "Desktop Widgets", "icon": "widgets",  "group": "Desktop" },
        { "key": "shell",       "name": "Shell",           "icon": "gear",     "group": "Desktop" },
        { "key": "plugins",     "name": "Plugins",         "icon": "widgets",  "group": "Add-ons" },
        { "key": "extras",      "name": "Extras",          "icon": "sparkles", "group": "Add-ons" },
        { "key": "addons",      "name": "Installed",       "icon": "widgets",  "group": "Add-ons" },
        { "key": "windowrules", "name": "Window Rules",    "icon": "window",   "group": "Advanced" },
        { "key": "layerrules",  "name": "Layer Rules",     "icon": "window",   "group": "Advanced" },
        { "key": "autostart",   "name": "Autostart",       "icon": "rocket",   "group": "Advanced" },
        { "key": "environment", "name": "Environment",     "icon": "variable", "group": "Advanced" }
    ]

    readonly property var pageMeta: ({
        "profile":     { "title": "Profile", "subtitle": "Your machine as a collector's specimen, built to share alongside your rice." },
        "displays":    { "title": "Displays", "subtitle": "Detect and arrange your monitors: resolution, scale, rotation, mirroring, and saved layout profiles." },
        "appearance":  { "title": "Appearance", "subtitle": "Window look: gaps, rounding, borders, opacity, blur, shadows, animations, and the cursor theme." },
        "lockscreen":  { "title": "Lockscreen", "subtitle": "Choose the skin your lock screen wears. Ryoku ships the clockwork theme; picking one only swaps the look, never your login." },
        "animations":  { "title": "Animations", "subtitle": "Tune Hyprland's animations and edit bezier curves with a live preview." },
        "input":       { "title": "Input", "subtitle": "Keyboard layout, pointer feel, touchpad behaviour, and key repeat." },
        "keybinds":    { "title": "Keybinds", "subtitle": "Every shortcut in the Ryoku desktop, read live from your Hyprland config, plus your own custom binds." },
        "windowrules": { "title": "Window Rules", "subtitle": "Float, size, pin, or place windows by class or title." },
        "layerrules":  { "title": "Layer Rules", "subtitle": "Tweak layer-shell surfaces (bars, launchers) by namespace: blur, dim, no animation." },
        "autostart":   { "title": "Autostart", "subtitle": "Commands that run when the session starts." },
        "environment": { "title": "Environment", "subtitle": "Environment variables for the Hyprland session." },
        "shell":       { "title": "Shell", "subtitle": "Tune the Ryoku shell: the frame, the island, the bar, and the desktop visualiser." },
        "widgets":     { "title": "Desktop Widgets", "subtitle": "Clock and weather on the wallpaper: pick a design, size, shape, and placement, with a live preview that follows your palette." },
        "connections": { "title": "Connections", "subtitle": "Wi-Fi networks, Bluetooth devices, and your hotspot, all in one place." },
        "updates":     { "title": "Updates", "subtitle": "Updates pending for your Ryoku system." },
        "extras":      { "title": "Extras", "subtitle": "Curated bundles of extra tools, installed and removed with one click." },
        "plugins":     { "title": "Plugins", "subtitle": "Shell plugins you can place where you like: a frame popout, a desktop widget, or a topbar glyph. Each runs in the Ryoku look." },
        "addons":      { "title": "Add-ons", "subtitle": "Your installed plugins. Open one to change its settings, enable it, or remove it." }
    })

    function known(s) {
        for (var i = 0; i < hub.sectionDefs.length; i++)
            if (hub.sectionDefs[i].key === s)
                return true;
        return false;
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
        // Leaving a live-preview page (Appearance, Input) with unsaved edits:
        // reset the desktop to the saved state. The page's own teardown cannot run
        // a process reliably, so the persistent hub does it.
        if (pageLoader.item && pageLoader.item.previewDirty === true) {
            restoreProc.command = ["ryoku-hub", "hypr", "restore"];
            restoreProc.running = true;
        }
        hub.section = s;
        saveSection.command = ["ryoku-hub", "config", "set", "section", s];
        saveSection.running = true;
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
                title: hub.searching ? "Search" : hub.pageMeta[hub.section].title
                subtitle: hub.searching ? "Results across every section" : hub.pageMeta[hub.section].subtitle
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
        case "windowrules": return windowRulesComp;
        case "layerrules": return layerRulesComp;
        case "autostart": return autostartComp;
        case "environment": return environmentComp;
        case "widgets": return widgetsComp;
        case "updates": return updatesComp;
        case "connections": return connectionsComp;
        case "extras": return extrasComp;
        case "plugins": return pluginsComp;
        case "addons": return addonsComp;
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
    Component { id: windowRulesComp; WindowRulesPage {} }
    Component { id: layerRulesComp; LayerRulesPage {} }
    Component { id: autostartComp; AutostartPage {} }
    Component { id: environmentComp; EnvironmentPage {} }
    Component { id: shellComp; ShellSettingsPage {} }
    Component { id: widgetsComp; WidgetsPage {} }
    Component { id: updatesComp; UpdatesPage {} }
    Component { id: extrasComp; ExtrasPage {} }
    Component { id: pluginsComp; PluginsPage {} }
    Component { id: addonsComp; AddonsPage {} }
    Component { id: connectionsComp; ConnectionsPage {} }

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
