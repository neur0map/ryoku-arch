//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell
import Quickshell.Io
import QtQuick

// Brain_Shell vendored components (MIT, Brainiac/Brainitech).
// See config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md.
import "vendor/brain-shell/src" as BS
import "vendor/brain-shell/src/windows" as BSW
import "vendor/brain-shell/src/popups" as BSP

ShellRoot {
    // CLI entry points: `qs ipc call -c ryoku popups <fn>`. Used by
    // Hyprland keybindings (e.g. SUPER+D toggles the dashboard).
    IpcHandler {
        target: "popups"

        function toggleDashboard(): void {
            BS.Popups.dashboardOpen = !BS.Popups.dashboardOpen
        }

        function toggleLauncher(): void {
            const opening = !BS.Popups.launcherOpen
            BS.Popups.closeAll()
            BS.Popups.launcherOpen = opening
        }

        function toggleWallpaper(): void {
            const opening = !(BS.Popups.wallpaperOpen && BS.Popups.wallpaperMode === "wallpaper")
            BS.Popups.closeAll()
            BS.Popups.wallpaperMode = "wallpaper"
            BS.Popups.wallpaperOpen = opening
        }

        function toggleThemes(): void {
            const opening = !(BS.Popups.wallpaperOpen && BS.Popups.wallpaperMode === "theme")
            BS.Popups.closeAll()
            BS.Popups.wallpaperMode = "theme"
            BS.Popups.wallpaperOpen = opening
        }

        function toggleSystemMenu(): void {
            const opening = !BS.Popups.systemMenuOpen
            BS.Popups.closeAll()
            BS.Popups.systemMenuOpen = opening
        }

        function toggleSettingsMenu(): void {
            const opening = !BS.Popups.settingsMenuOpen
            BS.Popups.closeAll()
            BS.Popups.settingsMenuOpen = opening
        }

        function closeAll(): void {
            BS.Popups.closeAll()
        }
    }

    // Existing decorative Frame, untouched.
    Variants {
        model: Quickshell.screens
        Frame {}
    }

    // Existing exclusion zones, untouched.
    Variants {
        model: Quickshell.screens
        ExclusionZones {}
    }

    // Spec 2 follow-up: rounded physical-display corners overlay.
    Variants {
        model: Quickshell.screens
        CornerOverlay {}
    }

    // Brain_Shell additions (Spec 1: TopBar plus PopupDismiss plus
    // ConfirmDialog plus PopupLayer with Dashboard active).
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                required property var modelData

                BSW.TopBar         { id: bsTopBar; screen: modelData }
                BSW.PopupDismiss   { screen: modelData }
                BSW.ConfirmDialog  { screen: modelData }

                BSP.PopupLayer {
                    topBar: bsTopBar
                    // Border anchors stay null in Spec 1 (Frame is the
                    // border system). PopupLayer Patch 7 softens these
                    // from required to property defaults.
                }

                BSW.DisplayTransitionOverlay { screen: modelData }
            }
        }
    }

    Component.onCompleted: console.log("[ryoku-shell] up with brain-shell components")
}
