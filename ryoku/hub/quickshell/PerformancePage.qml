pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "Singletons"

// Performance: tweaks that trade a little eye-candy for lower CPU, GPU, and
// memory use. Writes ~/.config/ryoku/performance.json, watched live by the shell
// singletons. The blur/shadow switches also strip the COMPOSITOR blur/shadow
// (read by hyprland/modules/decoration.lua), so those toggles fire `hyprctl
// reload` to re-read Hyprland at once; the shell-side effect is live either way.
// lowPowerMode is the master potato switch: it implies every reduce/disable
// switch, so a weak GPU can run the shell without lag from one toggle.
Item {
    id: page

    // Compositor blur/shadow live in decoration.lua, which reads these flags on
    // parse. Re-read it now so a toggle applies without a relogin. Shell-side
    // consumers (Motion, Performance singletons) watch the file and need no reload.
    function reloadCompositor() {
        Quickshell.execDetached(["hyprctl", "reload"]);
    }

    FileView {
        id: cfg
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool lowPowerMode: false
            property bool reduceMotion: false
            property bool disableBlur: false
            property bool disableShadows: false
            property bool freezeVisualizerWhenIdle: true
            property bool freezePillWhenIdle: false
            property bool unloadVisualizerWhenSilent: false
            property bool unloadWidgetsWhenCovered: true
            property bool unloadLauncherWhenIdle: false
            property bool unloadOverviewWhenIdle: false
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
                title: "LOW POWER"

                ToggleRow {
                    width: parent.width
                    label: "Low power mode - strip every heavy effect at once (blur, shadows, animations). The potato switch: implies all four toggles below, so a weak GPU runs the shell lag-free."
                    checked: adapter.lowPowerMode
                    onToggled: c => {
                        adapter.lowPowerMode = c;
                        cfg.writeAdapter();
                        page.reloadCompositor();
                    }
                }

                ToggleRow {
                    width: parent.width
                    label: "Reduce motion - make transitions instant (no per-frame animation repaints)"
                    checked: adapter.reduceMotion
                    onToggled: c => {
                        adapter.reduceMotion = c;
                        cfg.writeAdapter();
                    }
                }

                ToggleRow {
                    width: parent.width
                    label: "Disable blur - shell effects and the compositor backdrop blur (the biggest GPU saving)"
                    checked: adapter.disableBlur
                    onToggled: c => {
                        adapter.disableBlur = c;
                        cfg.writeAdapter();
                        page.reloadCompositor();
                    }
                }

                ToggleRow {
                    width: parent.width
                    label: "Disable shadows - shell drop shadows and the compositor window shadow"
                    checked: adapter.disableShadows
                    onToggled: c => {
                        adapter.disableShadows = c;
                        cfg.writeAdapter();
                        page.reloadCompositor();
                    }
                }
            }

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

            SettingSection {
                width: col.width
                title: "LAUNCHER & OVERVIEW"

                ToggleRow {
                    width: parent.width
                    label: "Unload the launcher to free its memory when idle (brief delay on the next open)"
                    checked: adapter.unloadLauncherWhenIdle
                    onToggled: c => {
                        adapter.unloadLauncherWhenIdle = c;
                        cfg.writeAdapter();
                    }
                }

                ToggleRow {
                    width: parent.width
                    label: "Unload the workspace overview to free its memory when idle (brief delay on the next open)"
                    checked: adapter.unloadOverviewWhenIdle
                    onToggled: c => {
                        adapter.unloadOverviewWhenIdle = c;
                        cfg.writeAdapter();
                    }
                }
            }
        }
    }
}
