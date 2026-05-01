//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell
import Quickshell.Io
import QtQuick

// Brain_Shell vendored components (MIT, Brainiac/Brainitech).
// See config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md.
import "vendor/brain-shell/src" as BS
import "vendor/brain-shell/src/windows" as BSW
import "vendor/brain-shell/src/popups" as BSP
import qs.Noctalia.Modules.Panels.Settings as NoctaliaSettings
import qs.Noctalia.Services.UI as NoctaliaUI

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

        function toggleToolbox(): void {
            const opening = !BS.Popups.toolboxOpen
            BS.Popups.closeAll()
            BS.Popups.toolboxOpen = opening
        }

        function openToolbox(): void {
            BS.Popups.closeAll()
            BS.Popups.toolboxOpen = true
        }

        function toolboxPrevious(): void {
            BS.Popups.requestToolboxAction("previous")
        }

        function toolboxNext(): void {
            BS.Popups.requestToolboxAction("next")
        }

        function toolboxActivate(): void {
            BS.Popups.requestToolboxAction("activate")
        }

        function toolboxClose(): void {
            BS.Popups.requestToolboxAction("close")
        }

        function toggleScreenshot(): void {
            const opening = !BS.Popups.screenshotToolOpen
            if (!opening) {
                BS.ScreenshotService.cancelCapture()
                BS.Popups.screenshotToolOpen = false
                return
            }

            BS.Popups.toolboxOpen = false
            BS.Popups.screenRecordToolOpen = false
            if (opening) {
                BS.ScreenshotService.startCapture("normal")
                BS.Popups.screenshotToolOpen = true
            }
        }

        function toggleScreenRecorder(): void {
            if (BS.ScreenRecService.recording) {
                BS.ScreenRecService.stopRecording()
                return
            }

            const opening = !BS.Popups.screenRecordToolOpen
            if (!opening) {
                BS.Popups.screenRecordToolOpen = false
                return
            }

            BS.Popups.toolboxOpen = false
            BS.Popups.screenshotToolOpen = false
            BS.ScreenRecService.initialize()
            BS.Popups.screenRecordToolOpen = true
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

        function toggleFonts(): void {
            const opening = !(BS.Popups.wallpaperOpen && BS.Popups.wallpaperMode === "font")
            BS.Popups.closeAll()
            BS.Popups.wallpaperMode = "font"
            BS.Popups.wallpaperOpen = opening
        }

        function toggleCursors(): void {
            const opening = !(BS.Popups.wallpaperOpen && BS.Popups.wallpaperMode === "cursor")
            BS.Popups.closeAll()
            BS.Popups.wallpaperMode = "cursor"
            BS.Popups.wallpaperOpen = opening
        }

        function toggleSystemMenu(): void {
            const opening = !BS.Popups.systemMenuOpen
            BS.Popups.closeAll()
            BS.Popups.systemMenuOpen = opening
        }

        function toggleSettingsMenu(): void {
            if (NoctaliaUI.RyokuSettingsPanelService.isWindowOpen) {
                NoctaliaUI.RyokuSettingsPanelService.close()
                return
            }

            BS.Popups.closeAll()
            NoctaliaUI.RyokuSettingsPanelService.openRoute("general")
        }

        function openSettingsMenu(): void {
            BS.Popups.closeAll()
            NoctaliaUI.RyokuSettingsPanelService.openRoute("general")
        }

        function openSettingsRoute(route: string): void {
            BS.Popups.closeAll()
            NoctaliaUI.RyokuSettingsPanelService.openRoute(route)
        }

        function closeSettingsMenu(): void {
            NoctaliaUI.RyokuSettingsPanelService.close()
        }

        function toggleLegacySettingsMenu(): void {
            const opening = !BS.Popups.legacySettingsMenuOpen
            BS.Popups.closeAll()
            if (opening) {
                BS.Popups.requestLegacySettingsMenuPage("home", "")
            }
            BS.Popups.legacySettingsMenuOpen = opening
        }

        function closeLegacySettingsMenu(): void {
            BS.Popups.legacySettingsMenuOpen = false
        }

        function openSettingsMenuHome(): void {
            BS.Popups.closeAll()
            BS.Popups.requestLegacySettingsMenuPage("home", "")
            BS.Popups.legacySettingsMenuOpen = true
        }

        function openSettingsMenuShare(): void {
            BS.Popups.closeAll()
            BS.Popups.requestLegacySettingsMenuPage("share", "")
            BS.Popups.legacySettingsMenuOpen = true
        }

        function openSettingsMenuHardware(): void {
            BS.Popups.closeAll()
            BS.Popups.requestLegacySettingsMenuPage("setup", "hardware")
            BS.Popups.legacySettingsMenuOpen = true
        }

        function toggleDotfiles(): void {
            const opening = !BS.Popups.dotfilesOpen
            BS.Popups.closeAll()
            BS.Popups.dotfilesOpen = opening
        }

        function previewBatteryWarning(): void {
            BS.Popups.requestBatteryWarning(10)
        }

        function closeAll(): void {
            BS.Popups.closeAll()
        }
    }

    IpcHandler {
        target: "volume"

        function flash(): void {
            BS.VolumeFeedback.show()
        }
    }

    NoctaliaSettings.SettingsPanelWindow {
        id: noctaliaSettingsPanel
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
                    screen: modelData
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
