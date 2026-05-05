import qs.modules.cheatsheet
import qs.modules.lock
import qs.modules.onScreenKeyboard
import qs.modules.recordingOsd
import qs.modules.overview
import qs.modules.polkit
import qs.modules.regionSelector
import qs.modules.screenCorners
import qs.modules.sessionScreen
import qs.modules.wallpaperSelector
import qs.modules.ii.overlay
import "modules/clipboard" as ClipboardModule

import qs.modules.waffle.actionCenter
import qs.modules.waffle.altSwitcher as WaffleAltSwitcherModule
import qs.modules.waffle.background as WaffleBackgroundModule
import qs.modules.waffle.bar as WaffleBarModule
import qs.modules.waffle.clipboard as WaffleClipboardModule
import qs.modules.waffle.notificationCenter
import qs.modules.waffle.onScreenDisplay as WaffleOSDModule
import qs.modules.waffle.startMenu
import qs.modules.waffle.widgets
import qs.modules.waffle.backdrop as WaffleBackdropModule
import qs.modules.waffle.notificationPopup as WaffleNotificationPopupModule
import qs.modules.waffle.taskview as WaffleTaskViewModule

import QtQuick
import Quickshell
import qs.modules.common
import "."

Item {
    // Immediate panels — visible at first frame or must catch early events
    component PanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // Deferred panels — loaded after first frame to reduce boot contention
    component DeferredPanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready && GlobalStates.deferredPanelsReady && (Config.options?.enabledPanels ?? []).includes(identifier) && extraCondition
    }

    // === Immediate panels (first frame + early event capture) ===
    PanelLoader { identifier: "wBar"; component: WaffleBarModule.WaffleBar {} }
    PanelLoader { identifier: "wBackground"; component: WaffleBackgroundModule.WaffleBackground {} }
    PanelLoader { identifier: "wBackdrop"; extraCondition: Config.options?.waffles?.background?.backdrop?.enable ?? true; component: WaffleBackdropModule.WaffleBackdrop {} }
    PanelLoader { identifier: "wNotificationPopup"; component: WaffleNotificationPopupModule.WaffleNotificationPopup {} }
    PanelLoader { identifier: "wOnScreenDisplay"; component: WaffleOSDModule.WaffleOSD {} }

    // === Deferred panels (user-triggered or non-critical at boot) ===
    DeferredPanelLoader { identifier: "wStartMenu"; component: WaffleStartMenu {} }
    DeferredPanelLoader { identifier: "wActionCenter"; component: WaffleActionCenter {} }
    DeferredPanelLoader { identifier: "wNotificationCenter"; component: WaffleNotificationCenter {} }
    DeferredPanelLoader { identifier: "wWidgets"; extraCondition: Config.options?.waffles?.modules?.widgets ?? true; component: WaffleWidgets {} }
    DeferredPanelLoader { identifier: "wLock"; component: Lock {} }
    DeferredPanelLoader { identifier: "wPolkit"; component: Polkit {} }
    DeferredPanelLoader { identifier: "wSessionScreen"; component: SessionScreen {} }
    DeferredPanelLoader { identifier: "wTaskView"; component: WaffleTaskViewModule.WaffleTaskView {} }

    // Shared modules that work with waffle (all deferred — user-triggered)
    DeferredPanelLoader { identifier: "iiCheatsheet"; component: Cheatsheet {} }
    DeferredPanelLoader { identifier: "iiOnScreenKeyboard"; component: OnScreenKeyboard {} }
    DeferredPanelLoader { identifier: "iiOverlay"; component: Overlay {} }
    DeferredPanelLoader { identifier: "iiOverview"; component: Overview {} }
    DeferredPanelLoader { identifier: "iiRegionSelector"; component: RegionSelector {} }
    DeferredPanelLoader { identifier: "iiScreenCorners"; component: ScreenCorners {} }
    DeferredPanelLoader { identifier: "iiWallpaperSelector"; component: WallpaperSelector {} }
    DeferredPanelLoader { identifier: "iiCoverflowSelector"; component: WallpaperCoverflow {} }
    DeferredPanelLoader { identifier: "iiClipboard"; component: ClipboardModule.ClipboardPanel {} }
    DeferredPanelLoader { identifier: "iiRecordingOsd"; component: RecordingOsd {} }

    // Waffle Clipboard - handles IPC when panelFamily === "waffle"
    LazyLoader { active: Config.ready && GlobalStates.deferredPanelsReady && Config.options?.panelFamily === "waffle"; component: WaffleClipboardModule.WaffleClipboard {} }

    // Waffle AltSwitcher - handles IPC when panelFamily === "waffle"
    LazyLoader { active: Config.ready && GlobalStates.deferredPanelsReady && Config.options?.panelFamily === "waffle"; component: WaffleAltSwitcherModule.WaffleAltSwitcher {} }
}
