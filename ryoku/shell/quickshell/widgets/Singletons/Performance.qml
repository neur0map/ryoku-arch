pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Opt-in performance toggles, shared through ~/.config/ryoku/performance.json
// (the Performance section in Ryoku Settings writes it; components watch it).
// Everything defaults off, so nothing changes until a user opts in. When the
// widget pause is off the singleton does no compositor tracking at all, so it
// costs nothing on a default desktop.
Singleton {
    id: root

    property alias pauseWidgetsWhenCovered: adapter.pauseWidgetsWhenCovered

    // windows on the focused workspace; only tracked while the opt-in is on.
    property int focusedWindows: 0

    // desktop widgets animate unless the user opted into pausing them while a
    // window covers the desktop and the focused workspace actually has one.
    readonly property bool widgetsAwake: !(root.pauseWidgetsWhenCovered && root.focusedWindows > 0)

    function recount() {
        if (!root.pauseWidgetsWhenCovered) {
            root.focusedWindows = 0;
            return;
        }
        var fw = Hyprland.focusedWorkspace;
        if (!fw) {
            root.focusedWindows = 0;
            return;
        }
        var n = 0;
        var tl = Hyprland.toplevels.values;
        for (var i = 0; i < tl.length; i++) {
            var t = tl[i];
            if (t && t.workspace && t.workspace.id === fw.id && (!t.lastIpcObject || t.lastIpcObject.mapped !== false))
                n++;
        }
        root.focusedWindows = n;
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!root.pauseWidgetsWhenCovered)
                return;
            switch (event.name) {
            case "openwindow":
            case "closewindow":
            case "movewindow":
            case "movewindowv2":
            case "workspace":
            case "workspacev2":
            case "focusedmon":
            case "focusedmonv2":
                Hyprland.refreshToplevels();
            }
        }
        function onFocusedWorkspaceChanged() {
            root.recount();
        }
    }

    // recount when the refreshed toplevel data actually lands.
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() {
            root.recount();
        }
    }

    // recount once when the opt-in is flipped on so it takes effect at once.
    onPauseWidgetsWhenCoveredChanged: {
        if (root.pauseWidgetsWhenCovered)
            Hyprland.refreshToplevels();
        root.recount();
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool pauseWidgetsWhenCovered: false
        }
    }
}
