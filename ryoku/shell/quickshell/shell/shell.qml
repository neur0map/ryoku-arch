//@ pragma UseQApplication
// Threaded render loop: the frame's blob melt is a per-frame spring plus live
// scene-graph MultiEffects (menu glass blur, blobs); threaded is vsync-locked and
// frees the GUI thread so those effects get regular frame deltas and never ghost
// or stutter. `basic` idled a touch cheaper on NVIDIA but smeared the live effects
// when switching menu pages, so this matches the pill's proven render setup.
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
pragma ComponentBehavior: Bound

import Quickshell
import shell.services
import "components"
import "modules/wallpaper"
import "modules/wallpaper/switcher"
import "modules/desktop"
import "modules/visualizer"
import "modules/bar"
import "modules/launcher"
import "modules/overview"
import QtQuick
import Quickshell.Io
import Quickshell.Wayland
import "modules/osd"
import "modules/notifications"
import "modules/capture"
import "modules/confirm"

/**
 * The single resident Ryoku shell instance.
 *
 * One ShellRoot for the whole desktop. It brings the shared service singletons
 * online, holds the per-monitor ShellState every surface binds its visibility
 * to, and registers the shell's in-QML Hyprland global shortcuts. Each monitor
 * gets one Scope carrying that screen's ShellState slice (st); every migrated
 * surface is instantiated once inside it and binds its screen and its visibility
 * to the slice, so a keybind that flips a flag on the active monitor reveals or
 * hides exactly this monitor's copy in-process, where the old shell spawned a
 * ryoku-shell client per press across separate surface processes.
 *
 * The ryoku-shell daemon launches this instance as `qs -c shell`, the live
 * desktop, and the compositor binds dispatch global:ryoku:<name> straight to the
 * shortcuts registered here.
 *
 * UseQApplication is declared once for the whole shell (the tray needs Qt
 * Widgets), replacing the six per-surface copies the old multi-process shell paid.
 */
ShellRoot {
    id: root

    // Construct the shared services (ShellState's per-monitor state now, heavier
    // providers as surfaces migrate) at load rather than on the first keybind.
    ServiceLoader {
        services: [ShellState, ScreenTime]
    }

    // One per-monitor surface stack. Each screen gets a Scope carrying its
    // ShellState slice (st); every resident surface binds its screen and its
    // visibility to that slice, so flipping a flag on the active monitor reveals
    // or hides this monitor's copy. The order here reads top-to-bottom only; the
    // Wayland layer each surface maps on decides the real stacking.
    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property var modelData
            readonly property var st: ShellState.forScreen(modelData)

            // Always-on backdrop and desktop widget layer.
            Wallpaper {
                id: wallpaper
                screen: perScreen.modelData
            }
            Desktop {
                screen: perScreen.modelData
                active: true
                wallpaperUrl: wallpaper.wallpaperUrl
                wallpaperFit: wallpaper.fit
            }
            Visualizer {
                screen: perScreen.modelData
                mode: perScreen.st ? perScreen.st.visualizerMode : "off"
            }

            // The frame bar (Phase 2): reads its own reveal from this slice.
            Frame {
                modelData: perScreen.modelData
            }

            // Toggle-driven overlays, each bound to a ShellState flag.
            Launcher {
                screen: perScreen.modelData
                active: perScreen.st ? perScreen.st.launcherOpen : false
                onRequestClose: if (perScreen.st) perScreen.st.launcherOpen = false
            }
            OverviewSurface {
                screen: perScreen.modelData
                active: perScreen.st ? perScreen.st.overviewOpen : false
                onRequestClose: if (perScreen.st) perScreen.st.overviewOpen = false
            }
            Switcher {
                screen: perScreen.modelData
                active: perScreen.st ? perScreen.st.wallpaperSwitcherOpen : false
                onRequestClose: if (perScreen.st) perScreen.st.wallpaperSwitcherOpen = false
            }

            // Shell-wide per-monitor surfaces: the three OSDs, the notification
            // popup column, the capture/region/camera overlays, and the
            // session-confirm dialog. Each binds this screen's modelData; the
            // Wayland layer each maps on decides the real stacking.
            OsdWindow {
                modelData: perScreen.modelData
                kind: "volume"
            }
            OsdWindow {
                modelData: perScreen.modelData
                kind: "mic"
            }
            OsdWindow {
                modelData: perScreen.modelData
                kind: "brightness"
            }
            NotificationPopups {
                modelData: perScreen.modelData
            }
            RegionOverlay {
                modelData: perScreen.modelData
            }
            CaptureOverlay {
                modelData: perScreen.modelData
            }
            CameraOverlay {
                modelData: perScreen.modelData
            }
            // Shown only on the monitor whose frame bar raised it; the positive
            // button runs the power action through the daemon, then clears.
            RyokuConfirmationDialog {
                modelData: perScreen.modelData
                action: ShellState.sessionActionMonitor === perScreen.modelData.name ? ShellState.sessionAction : ""
                message: ShellState.sessionMessage
                positiveLabel: ShellState.sessionPositive
                negativeLabel: "Cancel"
                onConfirmed: a => { SessionActions.run(a); ShellState.clearSessionAction(); }
                onCancelled: ShellState.clearSessionAction()
            }
        }
    }

    // In-process global shortcuts. Each flips the focused monitor's ShellState
    // flag that the per-screen surfaces above bind their visibility to, so a
    // keybind is a property write, not the old ryoku-shell client spawn. Names
    // match the compositor binds (rewired to global:ryoku:<name> in Phase 10) so
    // `hyprctl dispatch global ryoku:<name>` lands here.
    CustomShortcut {
        name: "barToggle"
        description: "Toggle the Ryoku frame bar on the active monitor"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.barRevealed = !st.barRevealed;
        }
    }
    CustomShortcut {
        name: "launcher"
        description: "Toggle the app launcher on the active monitor"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.launcherOpen = !st.launcherOpen;
        }
    }
    CustomShortcut {
        name: "overview"
        description: "Toggle the workspace overview on the active monitor"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.overviewOpen = !st.overviewOpen;
        }
    }
    CustomShortcut {
        name: "wallpaper-switcher"
        description: "Toggle the wallpaper switcher on the active monitor"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.wallpaperSwitcherOpen = !st.wallpaperSwitcherOpen;
        }
    }
    CustomShortcut {
        name: "visualizer"
        description: "Cycle the desktop audio visualiser off and on"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.visualizerMode = st.visualizerMode === "off" ? "desktop" : "off";
        }
    }
    CustomShortcut {
        name: "visualizer-overlay"
        description: "Toggle the audio visualiser overlay over windows"
        onPressed: {
            const st = ShellState.forActive();
            if (st)
                st.visualizerMode = st.visualizerMode === "overlay" ? "desktop" : "overlay";
        }
    }

    // --- Root machinery (ported from the reference pill root) --------------

    // Bring the durable services online and prewarm the slow scans so the first
    // open of each surface is instant. Ported from pill/shell.qml 170-194:
    // device restore + ddc prewarm, wallpaper index warm, and re-arming the
    // persisted Keep-Awake / Game Mode external inhibitors.
    Component.onCompleted: {
        Devices.restore();
        root.syncCaffeine(Flags.keepAwake ? "start" : "stop");
        if (Flags.gameMode)
            root.syncGameMode("start");
        WallIndex.refresh();
        Devices.prewarmDisplays();
    }

    // Keep-Awake's durable inhibitor lives outside the shell so it survives a
    // reload/restart: ryoku-cmd-caffeine runs systemd-inhibit independent of our
    // lifetime, while the Wayland IdleInhibitor below only gives compositor-level
    // effect. Every surface toggle just flips Flags.keepAwake. (pill 246-257)
    readonly property string caffeineScript: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-caffeine"
    function syncCaffeine(action) {
        Quickshell.execDetached([root.caffeineScript, action]);
    }
    Connections {
        target: Flags
        function onKeepAwakeChanged() {
            root.syncCaffeine(Flags.keepAwake ? "start" : "stop");
        }
    }

    // Game mode's compositor + WiFi tuning lives outside the shell, same shape as
    // Keep-Awake: ryoku-cmd-game-mode drives hyprctl and NetworkManager so the
    // tuning survives a reload. The deck toggle just flips Flags.gameMode.
    // (pill 264-275)
    readonly property string gameModeScript: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-game-mode"
    function syncGameMode(action) {
        Quickshell.execDetached([root.gameModeScript, action]);
    }
    Connections {
        target: Flags
        function onGameModeChanged() {
            root.syncGameMode(Flags.gameMode ? "start" : "stop");
        }
    }

    // Do-not-disturb: the notification server suppresses popups while the flag is
    // set (the deck toggle owns the flag). (pill 196-200)
    Binding {
        target: Notifs
        property: "dnd"
        value: Flags.dnd
    }

    // Compositor-level idle inhibitor, mapped only while Keep-Awake is on. It
    // dies with the shell; the external caffeine bridge above keeps the durable
    // one. (pill 202-214)
    PanelWindow {
        id: inhibitWin
        visible: Flags.keepAwake
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "ryoku-frame-inhibit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        IdleInhibitor { window: inhibitWin; enabled: Flags.keepAwake }
    }

    // keyboard-return bounce. The frame overlay never unmaps, and dropping an
    // Exclusive grab on a mapped layer strands the keyboard (the window looks
    // active but cannot type). This 1x1 helper takes the grab and unmaps, which
    // makes Hyprland hand the keyboard back. A per-monitor FrameSurfaceLifecycle
    // pulses it through ShellState.focusRestoreRequested when a keyboard surface
    // is dismissed, since the lifecycle is per-monitor but this window is single.
    // (pill 216-237, 304-308)
    property bool kbBounce: false
    Timer {
        id: kbBounceTimer
        interval: 90
        onTriggered: root.kbBounce = false
    }
    PanelWindow {
        id: kbBounceWin
        visible: root.kbBounce
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ryoku-frame-kbfocus"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; left: true }
    }
    Connections {
        target: ShellState
        function onFocusRestoreRequested() {
            root.kbBounce = true;
            kbBounceTimer.restart();
        }
    }

    // the self-view is a recording companion: when the last capture stops, clear
    // it so it does not linger. (pill 872-878)
    Connections {
        target: Recorder
        function onAnyActiveChanged() {
            if (!Recorder.anyActive)
                Camera.active = false;
        }
    }

    // The polkit agent streams its prompt on a topic rather than pushing a
    // surface, so raise and drop the island from the state itself. (pill 321-329)
    Connections {
        target: Polkit
        function onActiveChanged() {
            if (Polkit.active)
                ShellState.requestSurface("polkit", "", undefined);
            else
                ShellState.closeSurface("polkit", "");
        }
    }

    // Stash steps a running task's own surface aside when it needs the auth
    // island. (pill 332-335)
    Connections {
        target: Stash
        function onAuthStepAside(mon, id) { ShellState.closeSurface(id, mon); }
    }

    // Daemon-facing surface channel (Phase 10 points the daemon here). Target
    // "shell" avoids the live pill's "pill" target; each call maps onto the
    // ShellState surface bus. Ported from pill/shell.qml 341-364; the SocketServer
    // fast path (pill 402-411) is deliberately omitted so this instance owns no
    // runtime socket and produces zero live side effects alongside the daemon.
    IpcHandler {
        target: "shell"
        function openSurface(mon: string, id: string): void { ShellState.requestSurface(id, mon, undefined); }
        function closeSurface(mon: string, id: string): void { ShellState.closeSurface(id, mon); }
        function keyringPrompt(payload: string): void {
            Keyring.apply(payload);
            ShellState.keyringPromptChanged(Keyring.promptId);
            ShellState.requestSurface("keyring", Keyring.mon !== "" ? Keyring.mon
                : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""),
                { promptId: Keyring.promptId });
        }
        function keyringHide(): void {
            Keyring.clear();
            ShellState.closeSurface("keyring", "");
        }
        function voiceShow(mon: string): void { ShellState.requestSurface("voice", mon, undefined); }
        function voiceOff(mon: string): void { ShellState.requestSurface("voice-off", mon, undefined); }
        function voiceHide(): void { ShellState.closeSurface("voice", ""); }
        function pluginPopout(mon: string, id: string): void { ShellState.requestSurface("plugin:" + id, mon, undefined); }
        function bar(mon: string, id: string): void { ShellState.requestSurface(id, mon, undefined); }
        function closeAllMenus(mon: string): void { ShellState.closeSurface("", mon); }
        function sessionConfirm(mon: string, action: string): void { ShellState.askSessionAction(action, mon); }
    }
    // Menu global shortcuts (Phase 10): open a bar menu/surface on the focused
    // monitor via the ShellState bus, replacing the old `ryoku-shell menu <id>`
    // spawn. binds.lua dispatches global:ryoku:<name> straight here.
    CustomShortcut {
        name: "quicksettings"
        description: "Open quick settings on the active monitor"
        onPressed: ShellState.requestSurfaceActive("quick-settings", undefined)
    }
    CustomShortcut {
        name: "wallpaper-menu"
        description: "Open the wallpaper and theme menu on the active monitor"
        onPressed: ShellState.requestSurfaceActive("wallpaper", undefined)
    }
    CustomShortcut {
        name: "clipboard"
        description: "Open the clipboard history on the active monitor"
        onPressed: ShellState.requestSurfaceActive("quick-settings#clipboard", undefined)
    }
    CustomShortcut {
        name: "stash"
        description: "Open the feature sidebar on the active monitor"
        onPressed: ShellState.requestSurfaceActive("stash", undefined)
    }
    CustomShortcut {
        name: "screenshot"
        description: "Open the capture tab in quick settings on the active monitor"
        onPressed: ShellState.requestSurfaceActive("quick-settings#capture", undefined)
    }
    CustomShortcut {
        name: "compress"
        description: "Open the feature sidebar's file picker to compress media"
        onPressed: ShellState.requestSurfaceActive("stash#compress", undefined)
    }
    CustomShortcut {
        name: "install"
        description: "Open the feature sidebar's file picker to install a package"
        onPressed: ShellState.requestSurfaceActive("stash#install", undefined)
    }
}
