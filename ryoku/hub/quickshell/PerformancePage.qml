pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"

// Performance: tweaks that trade a little eye-candy for lower CPU, GPU, and
// memory use. Writes ~/.config/ryoku/performance.json, watched live (no reload).
// Two default on because leaving them off leaks memory: the visualiser freeze
// and hiding widgets while windows cover them (they render and leak 24/7 else).
Item {
    id: page

    FileView {
        id: cfg
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool freezeVisualizerWhenIdle: true
            property bool freezePillWhenIdle: false
            property bool unloadVisualizerWhenSilent: false
            property bool unloadWidgetsWhenCovered: true
        }

        Component.onCompleted: if (!cfg.text()) cfg.writeAdapter()
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: 4
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: col
            width: parent.width
            spacing: 26

            SettingSection {
                width: col.width
                title: "DESKTOP WIDGETS"

                ToggleRow {
                    width: parent.width
                    label: "Hide desktop widgets while windows cover the desktop (frees their memory; they reappear on an empty desktop)"
                    checked: adapter.unloadWidgetsWhenCovered
                    onToggled: c => {
                        adapter.unloadWidgetsWhenCovered = c;
                        cfg.writeAdapter();
                    }
                }
            }

            SettingSection {
                width: col.width
                title: "VISUALISER"

                ToggleRow {
                    width: parent.width
                    label: "Freeze the visualiser when no audio is playing"
                    checked: adapter.freezeVisualizerWhenIdle
                    onToggled: c => {
                        adapter.freezeVisualizerWhenIdle = c;
                        cfg.writeAdapter();
                    }
                }

                ToggleRow {
                    width: parent.width
                    label: "Unload the visualiser to free memory when silent (brief delay when audio resumes)"
                    checked: adapter.unloadVisualizerWhenSilent
                    onToggled: c => {
                        adapter.unloadVisualizerWhenSilent = c;
                        cfg.writeAdapter();
                    }
                }
            }

            SettingSection {
                width: col.width
                title: "BAR"

                ToggleRow {
                    width: parent.width
                    label: "Freeze the glowing bead animation while the bar is idle"
                    checked: adapter.freezePillWhenIdle
                    onToggled: c => {
                        adapter.freezePillWhenIdle = c;
                        cfg.writeAdapter();
                    }
                }
            }
        }
    }
}
