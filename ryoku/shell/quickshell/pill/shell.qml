//@ pragma UseQApplication
// threaded render loop: the blob melt is a per-frame spring (plugin/blobrect.cpp)
// plus scene-graph animations; threaded is vsync-locked and frees the GUI thread, so
// the spring gets regular frame deltas and never stutters behind layout/JS. (basic
// idled ~5% cheaper on NVIDIA with the island's live MultiEffects in the scene, but
// smoothness wins and blobs snap to rest when idle.)
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QS_DROP_EXPENSIVE_FONTS=1
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Ryoku.Blobs
import "Singletons"
import "popouts"

// the ryoku shell surface. per monitor, the layer-shell windows are:
//   reserve      = zero-content top strip, mapped only for a TOP bar, claiming
//                  its exclusive zone so tiled windows sit below the band.
//   sideReserve  = the same for a bottom/left/right bar's own edge.
//   overlay      = full-screen transparent Overlay layer: the rounded frame,
//                  the bar riding one edge, and every summoned surface as an
//                  edge popout growing from the bar (see popouts/). never moves
//                  windows; grows in place.
//   OsdWindow    = the volume/brightness OSD, bottom-centre above the bar.
//
// input routing = the overlay window mask: the bar strip and open popout bodies
// catch clicks, the rest of the screen clicks through. a modal (keyboard) popout
// clears the mask so a backdrop press dismisses; keyboard focus is taken on
// demand so Escape closes it.
ShellRoot {
    id: root

    property string peekMon: ""

    // which edge popout (mixer/power) is pinned by IPC, and on which
    // monitor. hover is the usual trigger; this is the keybind path.
    property string popout: ""
    property string popoutMon: ""
    // voiceShow with the dictation service off: the popout says so instead of
    // drawing a wave that would record nothing.
    property bool voiceOff: false
    // along-axis centre of the bar icon that opened the current popout (window
    // coords), so the popout blob grows from that icon on whatever edge the bar
    // sits. set by togglePopoutAt from the bar's click.
    property real popoutCenter: 0

    // media hover popout: the now-playing module drives this while hovered,
    // feeding its centre. distinct from the clicked `popout` above so hover
    // and click never clobber each other.
    property string hoverPopout: ""
    property string hoverPopoutMon: ""
    property real hoverPopoutCenter: 0
    // which pane each sidebar shows. tab taps set it; the stash IPC jumps the
    // left sidebar straight to its stash pane. "" = the sidebar's first pane.
    property string sidebarLeftPane: ""
    property string sidebarRightPane: ""

    // popouts that need the keyboard (search / password fields). while one of
    // these is the pinned popout, the overlay grabs the keyboard the way an open
    // surface does and hands it back on close; the pointer-only popouts and
    // voice stay keyboardFocus None.
    readonly property var kbPopouts: ["clipboard", "link", "keyring", "sidebarLeft", "sidebarRight", "calendar"]
    property string prevPopout: ""
    onPopoutChanged: {
        if (kbPopouts.indexOf(prevPopout) >= 0 && kbPopouts.indexOf(popout) < 0)
            restoreFocus();
        // dismissing the keyring popout cancels the pending prompt (a no-op if the
        // daemon already cleared it via keyringHide).
        if (prevPopout === "keyring" && popout !== "keyring")
            Keyring.dismiss();
        prevPopout = popout;
    }

    function refresh() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: {
        refresh();
        Devices.restore();
        // re-arm the durable idle inhibitor for the persisted flag. on a
        // shell reload the external inhibitor is usually still up (lives
        // outside this process), so "start" = idempotent confirm; "stop"
        // clears a stray when Keep-Awake is off.
        root.syncCaffeine(Flags.keepAwake ? "start" : "stop");
        // re-assert Game Mode if it persisted on. relogin brings Hyprland
        // up fresh from the lua config, so the compositor tuning has to be
        // re-applied (start is idempotent and preserves the saved WiFi
        // value). only "start", never "stop": a reload is expensive and the
        // desktop already sits in its normal config when game mode is off.
        if (Flags.gameMode)
            root.syncGameMode("start");
    }

    Binding {
        target: Notifs
        property: "dnd"
        value: Flags.dnd
    }

    PanelWindow {
        id: inhibitWin
        visible: Flags.keepAwake
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "pill-inhibit"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { top: true; left: true }
        IdleInhibitor { window: inhibitWin; enabled: Flags.keepAwake }
    }

    // keyboard-return bounce. the pill overlay never unmaps, and dropping an
    // Exclusive grab on a mapped layer strands the keyboard (the window looks
    // active but can't type; focus dispatches don't recover it). this 1x1 helper
    // takes the grab and unmaps, which makes Hyprland hand the keyboard back.
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
        WlrLayershell.namespace: "pill-kbbounce"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        anchors { top: true; left: true }
    }

    // Keep-Awake's durable inhibitor lives outside the shell so it survives
    // a reload/restart. ryoku-cmd-caffeine runs systemd-inhibit via
    // systemd-run (setsid fallback), independent of our lifetime. the
    // Wayland IdleInhibitor above only gives compositor-level effect and
    // dies with the pill on every respawn; this bridge keeps Keep-Awake
    // unbroken across the swap. every surface toggle just flips
    // Flags.keepAwake.
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

    // game mode's compositor + WiFi tuning lives outside the shell, same
    // shape as Keep-Awake. ryoku-cmd-game-mode drives hyprctl and
    // NetworkManager so the tuning survives a shell reload and re-applies
    // after a relogin. DND is the shell's own (handled in Flags); deck
    // toggle just flips Flags.gameMode.
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

    // only these raw events change what the pill renders (per-monitor
    // active workspace, minimized toplevels, monitor hotplug). everything
    // else (window drags, resizes, title spam) MUST NOT trigger the triple
    // model refresh: three Hyprland IPC round-trips a pop.
    readonly property var refreshEvents: ({
        workspace: true, workspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true,
        moveworkspace: true, moveworkspacev2: true,
        renameworkspace: true, activespecial: true,
        focusedmon: true, focusedmonv2: true,
        openwindow: true, closewindow: true,
        movewindow: true, movewindowv2: true,
        fullscreen: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            // a workspace switch fires several whitelisted events at once;
            // Qt.callLater dedups them to one refresh (three IPC calls) per turn.
            if (root.refreshEvents[event.name])
                Qt.callLater(root.refresh);
        }
    }

    // pulse the kbBounce helper so a dismissed keyboard popout hands the keyboard back.
    function restoreFocus() {
        root.kbBounce = true;
        kbBounceTimer.restart();
    }

    function peek(mon) {
        root.peekMon = root.peekMon === mon ? "" : mon;
    }

    // a stash install hitting a sudo/polkit prompt asks the deck to step
    // aside so the prompt (a window beneath our keyboard grab) takes focus
    // instead of landing behind the open deck.
    Connections {
        target: Stash
        function onAuthStepAside() { root.popout = ""; }
    }

    // pin/unpin an edge popout (mixer/power) on a monitor. re-issuing the
    // same one clears it. hover opens them on its own; this is the
    // IPC/keybind path.
    function togglePopout(mon, name) {
        if (root.popout === name && root.popoutMon === mon) {
            root.popout = "";
            return;
        }
        // unpin the old popout before moving the anchor: a pinned popout tracks
        // popoutCenter live, so writing the new centre first teleports the old
        // body along the bar instead of letting it melt where it opened.
        root.popout = "";
        root.popoutMon = mon;
        root.popoutCenter = -1;   // keybind/IPC: no owning icon, so centre on the bar
        root.popout = name;
    }

    // open a popout at a bar icon: record the icon's along-axis centre so the
    // blob grows from the icon on any bar edge.
    function togglePopoutAt(mon, name, center) {
        if (root.popout === name && root.popoutMon === mon) {
            root.popout = "";
            return;
        }
        root.popout = "";         // same unpin-first order as togglePopout
        root.popoutMon = mon;
        root.popoutCenter = center;
        root.popout = name;
    }

    // media hover popout: open at the module's centre; on unhover a short grace
    // lets the pointer cross the bar edge to the body, whose own hover latch
    // then holds the popout open for the transport buttons.
    Timer {
        id: hoverPopoutClose
        interval: 160
        onTriggered: { root.hoverPopout = ""; root.hoverPopoutMon = ""; }
    }
    function setHoverPopout(mon, name, center, hovered) {
        if (hovered) {
            hoverPopoutClose.stop();
            root.hoverPopoutCenter = center;
            root.hoverPopoutMon = mon;
            root.hoverPopout = name;
        } else if (root.hoverPopout === name && root.hoverPopoutMon === mon) {
            hoverPopoutClose.restart();
        }
    }

    // open the Hub on its Updates section. the update island is an entry
    // point to the surface Super+, opens; binds.lua holds the canonical
    // launcher, so we mirror its flock guard to avoid spawning a second
    // Hub instance.
    function openUpdates() {
        Quickshell.execDetached(["sh", "-c",
            "ryoku-hub config set section updates; flock -n -o /tmp/ryoku-hub.lock qs -c hub"]);
    }

    IpcHandler {
        target: "pill"
        function mixer(mon: string): void { root.togglePopout(mon, "mixer"); }
        function calendar(mon: string): void { root.togglePopout(mon, "calendar"); }
        function power(mon: string): void { root.togglePopout(mon, "power"); }
        function link(mon: string): void { root.togglePopout(mon, "link"); }
        function inbox(mon: string): void { root.togglePopout(mon, "inbox"); }
        function battery(mon: string): void { root.togglePopout(mon, "battery"); }
        // status-cluster quick popouts (the compact hover panels; a keybind can
        // also pin one). distinct from the deep surfaces above; side bar only.
        function network(mon: string): void { root.togglePopout(mon, "network"); }
        function bluetooth(mon: string): void { root.togglePopout(mon, "bluetooth"); }
        function batteryPopout(mon: string): void { root.togglePopout(mon, "battery"); }
        function clipboard(mon: string): void { root.togglePopout(mon, "clipboard"); }
        function stash(mon: string): void { root.sidebarLeftPane = "stash"; root.popoutMon = mon; root.popout = "sidebarLeft"; }
        // stash-send <file>: open the left sidebar's stash pane and jump straight
        // to its LocalSend picker, so the file manager can hand a file to the send
        // flow. sets the popout directly (not toggle) so it never closes it.
        function stashSend(mon: string, file: string): void {
            root.sidebarLeftPane = "stash";
            root.popoutMon = mon;
            root.popout = "sidebarLeft";
            Stash.openSendPicker(file);
        }
        // deck-era names, repointed to the left features sidebar (Super+D binds
        // and the file manager still call these).
        function toolkit(mon: string): void { root.togglePopout(mon, "sidebarLeft"); }
        function utilities(mon: string): void { root.togglePopout(mon, "sidebarLeft"); }
        function workspaces(mon: string): void { root.togglePopout(mon, "workspaces"); }
        function sidebarLeft(mon: string): void { root.togglePopout(mon, "sidebarLeft"); }
        function sidebarRight(mon: string): void { root.togglePopout(mon, "sidebarRight"); }
        function keyringPrompt(payload: string): void {
            Keyring.apply(payload);
            var m = Keyring.mon !== "" ? Keyring.mon
                : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
            root.popout = "";
            root.popoutMon = m;
            root.popoutCenter = -1;
            root.popout = "keyring";
        }
        function keyringHide(): void {
            // daemon-driven teardown (unlock resolved). clear() first so the
            // popout's dismiss (onPopoutChanged) can't cancel the resolved prompt.
            Keyring.clear();
            if (root.popout === "keyring")
                root.popout = "";
        }
        function voiceShow(mon: string): void { root.voiceOff = false; root.popout = ""; root.popoutMon = mon; root.popoutCenter = -1; root.popout = "voice"; }
        function voiceOff(mon: string): void { root.voiceOff = true; root.popout = ""; root.popoutMon = mon; root.popoutCenter = -1; root.popout = "voice"; }
        function voiceHide(): void { if (root.popout === "voice") root.popout = ""; }
        function peek(mon: string): void { root.peek(mon); }
        function hide(): void { root.popout = ""; }
        // toggle an enabled plugin's frame popout by id (leader menu / keybind).
        function pluginPopout(mon: string, id: string): void { root.togglePopout(mon, "plugin:" + id); }
    }

    // The daemon writes surface commands to this socket to toggle pill surfaces
    // without spawning a `qs ipc call` client on the keybind hot path. The pill
    // is a persistent component, so the socket is up whenever the daemon needs
    // it; a miss makes the daemon fall back to the qs client.
    readonly property string pillSockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-pill.sock"

    // runPillCommand mirrors the IpcHandler above for the socket fast path:
    // "<fn> <mon> [arg]" runs the same surface toggle. Returns false on an
    // unknown command so the daemon falls back to the qs client.
    function runPillCommand(line) {
        var parts = line.trim().split(" ");
        var fn = parts[0];
        var mon = parts.length > 1 ? parts[1] : "";
        switch (fn) {
        case "battery": case "mixer": case "power":
            root.togglePopout(mon, fn); return true;
        case "network": case "bluetooth": case "calendar": case "clipboard": case "link": case "inbox": case "workspaces": case "sidebarLeft": case "sidebarRight":
            root.togglePopout(mon, fn); return true;
        case "toolkit": case "utilities":
            root.togglePopout(mon, "sidebarLeft"); return true;
        case "stash":
            root.sidebarLeftPane = "stash"; root.popoutMon = mon; root.popout = "sidebarLeft"; return true;
        case "batteryPopout":
            root.togglePopout(mon, "battery"); return true;
        case "pluginPopout":
            root.togglePopout(mon, "plugin:" + (parts.length > 2 ? parts[2] : ""));
            return true;
        case "voiceShow":
            root.voiceOff = false; root.popout = ""; root.popoutMon = mon; root.popoutCenter = -1; root.popout = "voice"; return true;
        case "voiceOff":
            root.voiceOff = true; root.popout = ""; root.popoutMon = mon; root.popoutCenter = -1; root.popout = "voice"; return true;
        case "voiceHide":
            if (root.popout === "voice") root.popout = "";
            return true;
        case "peek":
            root.peek(mon); return true;
        case "hide":
            root.popout = ""; return true;
        default:
            return false;
        }
    }

    SocketServer {
        active: true
        path: root.pillSockPath
        handler: Socket {
            id: cmdSock
            parser: SplitParser {
                onRead: line => cmdSock.write((root.runPillCommand(line) ? "ok" : "err") + "\n")
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: reserve
            required property var modelData
            readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))
            readonly property string barPos: Config.barEnabled ? (Config.barPosition === "bottom" ? "bottom" : "top") : ""
            readonly property bool barTop: barPos === "top"
            readonly property bool delos: Config.barStyle === "delos"
            readonly property string rEdge: delos ? IslandDock.edge : barPos
            // a TOP bar reserves the visible bar strip (frame edge + band, the
            // same numbers as the overlay's barVisibleH) so tiles tuck right
            // against it. bottom/left/right bars reserve their own edge in
            // sideReserve; with no island there is nothing else to reserve at
            // the top, so this window only maps for a top bar.
            readonly property real barBand: Config.barHeight * s
            readonly property real barVisibleH: Math.max(0, Config.frameBorder - 50) + barBand
            readonly property real zone: delos ? Math.max(0, IslandDock.thickness) : barVisibleH

            screen: modelData
            visible: rEdge === "top"
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: zone
            aboveWindows: true

            anchors { top: true; left: true; right: true }
            implicitHeight: zone

            mask: emptyReserve
            Region { id: emptyReserve }
        }
    }

    // a bottom/left/right bar claims its own edge strip, independent of the
    // island reserve above (which keeps owning the top).
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: sideReserve
            required property var modelData
            readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))
            readonly property string barPos: Config.barEnabled ? (Config.barPosition === "bottom" ? "bottom" : "top") : ""
            readonly property bool delos: Config.barStyle === "delos"
            readonly property string rEdge: delos ? IslandDock.edge : barPos
            readonly property bool active: rEdge === "bottom" || rEdge === "left" || rEdge === "right"
            // a vertical band needs room for stacked content; floor it at 30.
            readonly property real minBand: rEdge === "left" || rEdge === "right" ? 30 : 0
            readonly property real zone: delos ? Math.max(0, IslandDock.thickness) : (Math.max(0, Config.frameBorder - 50) + Math.max(Config.barHeight, minBand) * s)

            screen: modelData
            visible: active
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: active ? zone : 0
            aboveWindows: true

            anchors {
                top: rEdge === "left" || rEdge === "right"
                bottom: rEdge !== "top"
                left: rEdge !== "right"
                right: rEdge !== "left"
            }
            implicitHeight: rEdge === "bottom" ? zone : 100
            implicitWidth: zone

            mask: emptySideReserve
            Region { id: emptySideReserve }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))

            // bar mode: the frame's chosen edge swells into a band carrying
            // the options (Bar.qml). inverted rect is oversized 50px (its
            // anchors.margins), so the on-screen edge is border - 50; the
            // bar adds `barBand` inside that.
            readonly property string barPos: !Config.barEnabled ? "" : (delos ? IslandDock.edge : (Config.barPosition === "bottom" ? "bottom" : "top"))
            readonly property bool barTop: barPos === "top"
            readonly property bool barBottom: barPos === "bottom"
            readonly property bool barLeft: barPos === "left"
            readonly property bool barRight: barPos === "right"
            readonly property bool barVertical: barLeft || barRight
            readonly property bool triptych: Config.barStyle === "triptych"
            readonly property bool delos: Config.barStyle === "delos"
            // triptych: the top edge stays a hairline and three lobes fuse
            // under the module clusters, so the bar dips between them (top only).
            readonly property bool triptychLobes: barTop && triptych && !monFullscreen
            readonly property real frameTopVisible: Math.max(0, Config.frameBorder - 50)
            // a vertical band needs room for stacked content; floor it at 30.
            readonly property real barBand: Math.max(Config.barHeight, barVertical ? 30 : 0) * s
            readonly property real barVisibleH: frameTopVisible + barBand

            // the two sidebars: full-height panels that melt out of the left and
            // right frame edges (fullSpan), each fusing into the top and bottom
            // frame so a whole side swells open with no gap. the top/bottom gaps
            // become the content inset, so it clears a bar and the bottom frame.
            readonly property bool sidebarLeftOn: Config.sidebarLeftEnabled
            readonly property bool sidebarRightOn: Config.sidebarRightEnabled
            readonly property real sidebarW: Config.sidebarWidth * s
            readonly property real sidebarTopGap: (barTop ? barVisibleH : frameTopVisible) + 14 * s
            readonly property real sidebarBotGap: (barBottom ? barVisibleH : frameTopVisible) + 14 * s
            readonly property real sidebarCornerW: Config.sidebarCornerSize * s
            readonly property real sidebarCornerH: Config.sidebarCornerSize * s

            // drag-to-stash trigger: a thin masked band down the left frame edge
            // that opens the sidebar when a file is flung at the edge (a
            // HoverHandler is dead while a drag grabs the pointer, so this DropArea
            // catches it); the board's own DropArea takes the actual drop. Kept a
            // thin sliver inside Hyprland's gaps_out ring (18px) so it never reaches
            // window content: a corner-width band swallowed every click down the
            // whole left edge.
            readonly property real leftEdgeStripW: 12
            readonly property bool leftDragActive: overlay.sidebarLeftOn && !overlay.monFullscreen &&
                (leftEdgeDrop.containsDrag || sidebarLeftContent.dragActive)
            onLeftDragActiveChanged: if (overlay.leftDragActive) root.sidebarLeftPane = "stash"

            // a keyboard-needing popout (clipboard/link/keyring/deck/workspaces)
            // pinned on this monitor: grabs the keyboard for text entry.
            readonly property bool kbPopout: root.popoutMon === modelData.name
                && root.kbPopouts.indexOf(root.popout) >= 0
            readonly property bool modal: kbPopout

            // true if this monitor's active workspace has a fullscreen window.
            readonly property bool monFullscreen: {
                var mons = Hyprland.monitors.values;
                for (var i = 0; i < mons.length; i++)
                    if (mons[i].name === modelData.name)
                        return mons[i].activeWorkspace ? mons[i].activeWorkspace.hasFullscreen : false;
                return false;
            }

            onMonFullscreenChanged: if (monFullscreen) {
                if (root.popoutMon === modelData.name) root.popout = "";
                if (root.peekMon === modelData.name) root.peekMon = "";
            }

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            // None, not OnDemand: this layer is always mapped, so OnDemand would
            // hold the keyboard after a popout closes and a launched window can't type.
            WlrLayershell.keyboardFocus: kbPopout ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "pill"

            anchors { top: true; left: true; right: true; bottom: true }

            // recHud.dragging widens the mask to the whole surface: the island
            // clamps at the frame lips, so the pointer can slide off its rect
            // mid-drag; losing the region there kills the grab and the island
            // snaps home while the button is still held.
            mask: monFullscreen ? hiddenRegion
                : ((modal || recHud.dragging || delosIsland.dragging) ? fullRegion : barRegion)

            // the bar band's input strip, per edge.
            readonly property real barMaskX: barRight ? width - barVisibleH : 0
            readonly property real barMaskY: barBottom ? height - barVisibleH : 0
            readonly property real barMaskW: barVertical ? barVisibleH : width
            readonly property real barMaskH: barVertical ? height : barVisibleH
            // true when (x, y) (overlay-window coords) falls on the bar's input
            // strip. the dismiss backdrop leaves every press here to the bar, so
            // the bar stays fully usable under a popout -- the way caelestia's
            // drawer region starts past the bar (x: bar.clampedWidth) and never
            // overlaps the taskbar with the dismiss surface.
            function inBarStrip(x, y) {
                return Config.barEnabled
                    && x >= barMaskX && x < barMaskX + barMaskW
                    && y >= barMaskY && y < barMaskY + barMaskH;
            }
            Region { id: hiddenRegion }
            Region {
                id: fullRegion
                width: overlay.width
                height: overlay.height
            }
            Region {
                id: barRegion
                // bar strip catches input for its options; the edge popouts
                // keep their hover triggers and bodies so mixer/power still open.
                // with a top bar the island drops out of the band, so the grab
                // extends over the panel (toast actions stay clickable); other
                // edges keep the island's own regions.
                x: overlay.barMaskX
                y: overlay.barMaskY
                width: (Config.barEnabled && !overlay.delos) ? overlay.barMaskW : 0
                height: (Config.barEnabled && !overlay.delos) ? overlay.barMaskH : 0
                Region { x: mixerPop.triggerX; y: mixerPop.triggerY; width: mixerPop.triggerW; height: mixerPop.triggerH }
                Region { x: mixerPop.maskX; y: mixerPop.maskY; width: mixerPop.maskW; height: mixerPop.maskH }
                Region { x: powerPop.triggerX; y: powerPop.triggerY; width: powerPop.triggerW; height: powerPop.triggerH }
                Region { x: powerPop.maskX; y: powerPop.maskY; width: powerPop.maskW; height: powerPop.maskH }
                Region { x: networkPop.maskX; y: networkPop.maskY; width: networkPop.maskW; height: networkPop.maskH }
                Region { x: batteryPop.maskX; y: batteryPop.maskY; width: batteryPop.maskW; height: batteryPop.maskH }
                Region { x: bluetoothPop.maskX; y: bluetoothPop.maskY; width: bluetoothPop.maskW; height: bluetoothPop.maskH }
                Region { x: calendarPop.maskX; y: calendarPop.maskY; width: calendarPop.maskW; height: calendarPop.maskH }
                Region { x: clipboardPop.maskX; y: clipboardPop.maskY; width: clipboardPop.maskW; height: clipboardPop.maskH }
                Region { x: linkPop.maskX; y: linkPop.maskY; width: linkPop.maskW; height: linkPop.maskH }
                Region { x: inboxPop.maskX; y: inboxPop.maskY; width: inboxPop.maskW; height: inboxPop.maskH }
                Region { x: voicePop.maskX; y: voicePop.maskY; width: voicePop.maskW; height: voicePop.maskH }
                Region { x: keyringPop.maskX; y: keyringPop.maskY; width: keyringPop.maskW; height: keyringPop.maskH }
                Region { x: workspacesPop.maskX; y: workspacesPop.maskY; width: workspacesPop.maskW; height: workspacesPop.maskH }
                Region { x: mediaPop.maskX; y: mediaPop.maskY; width: mediaPop.maskW; height: mediaPop.maskH }
                Region { x: toastPop.maskX; y: toastPop.maskY; width: toastPop.maskW; height: toastPop.maskH }
                Region { x: pluginPops.maskTrigX; y: pluginPops.maskTrigY; width: pluginPops.maskTrigW; height: pluginPops.maskTrigH }
                Region { x: pluginPops.maskBodyX; y: pluginPops.maskBodyY; width: pluginPops.maskBodyW; height: pluginPops.maskBodyH }
                Region { x: recHud.hudX; y: recHud.hudY; width: ((Recorder.active || Recorder.chooserOpen) && recHud.prog > 0.25) ? recHud.hudW : 0; height: ((Recorder.active || Recorder.chooserOpen) && recHud.prog > 0.25) ? recHud.hudH : 0 }
                Region { x: recHud.trigX; y: recHud.trigY; width: Recorder.active ? recHud.trigW : 0; height: Recorder.active ? recHud.trigH : 0 }
                Region { x: delosIsland.hudX; y: delosIsland.hudY; width: (overlay.delos && delosIsland.prog > 0.25) ? delosIsland.hudW : 0; height: (overlay.delos && delosIsland.prog > 0.25) ? delosIsland.hudH : 0 }
                Region { x: delosIsland.trigX; y: delosIsland.trigY; width: overlay.delos ? delosIsland.trigW : 0; height: overlay.delos ? delosIsland.trigH : 0 }
                Region { x: 0; y: 0; width: (overlay.sidebarLeftOn && !overlay.monFullscreen) ? overlay.sidebarCornerW : 0; height: (overlay.sidebarLeftOn && !overlay.monFullscreen) ? overlay.sidebarCornerH : 0 }
                Region { x: 0; y: 0; width: (overlay.sidebarLeftOn && !overlay.monFullscreen) ? overlay.leftEdgeStripW : 0; height: (overlay.sidebarLeftOn && !overlay.monFullscreen) ? overlay.height : 0 }
                Region { x: sidebarLeftPop.maskX; y: sidebarLeftPop.maskY; width: sidebarLeftPop.maskW; height: sidebarLeftPop.maskH }
                Region { x: (overlay.width - overlay.sidebarCornerW); y: 0; width: (overlay.sidebarRightOn && !overlay.monFullscreen) ? overlay.sidebarCornerW : 0; height: (overlay.sidebarRightOn && !overlay.monFullscreen) ? overlay.sidebarCornerH : 0 }
                Region { x: sidebarRightPop.maskX; y: sidebarRightPop.maskY; width: sidebarRightPop.maskW; height: sidebarRightPop.maskH }
            }

            MouseArea {
                anchors.fill: parent
                enabled: overlay.modal
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => {
                    // a press on the bar strip belongs to the bar (its icons take
                    // their own clicks, the band is inert), so it never dismisses.
                    // only a true backdrop press dismisses the modal popout.
                    if (overlay.inBarStrip(mouse.x, mouse.y)) return;
                    if (overlay.kbPopout) root.popout = "";
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: overlay.kbPopout
                // whole shell hides while a window is fullscreen.
                visible: !overlay.monFullscreen

                Keys.onEscapePressed: if (overlay.kbPopout) root.popout = "";

                // frame and pill share one blob field, so the pill reads
                // as the frame swelling open at top-centre, not a bar on top.
                BlobGroup {
                    id: blobGroup
                    color: Config.matchWallpaper ? Wallust.surface : Config.surfaceColor
                    borderColor: Wallust.border
                    borderWidth: 1.5
                    smoothing: Config.frameSmoothing
                    shadowStrength: Config.shadowStrength
                    shadowSize: Config.shadowSize
                }

                BlobInvertedRect {
                    // rounded screen border, sits in Hyprland's gaps_out
                    // ring. oversized 50px so the outer edge clips
                    // off-screen and only the inner (window) edge shows;
                    // borders grow to keep the hole at gaps_out.
                    anchors.fill: parent
                    anchors.margins: -50
                    group: blobGroup
                    radius: Config.frameRadius
                    borderTop: (overlay.barTop && !overlay.triptych && !overlay.delos) ? (Config.frameBorder + overlay.barBand) : Config.frameBorder
                    borderBottom: (overlay.barBottom && !overlay.delos) ? (Config.frameBorder + overlay.barBand) : Config.frameBorder
                    borderLeft: (overlay.barLeft && !overlay.delos) ? (Config.frameBorder + overlay.barBand) : Config.frameBorder
                    borderRight: (overlay.barRight && !overlay.delos) ? (Config.frameBorder + overlay.barBand) : Config.frameBorder
                    opacity: Config.frameOpacity
                    visible: !overlay.monFullscreen
                }

                // triptych lobes: fused into the hairline top edge under each
                // module cluster (the Bar exposes their rects), so the frame
                // dips between the three instead of one straight band.
                BlobRect {
                    group: blobGroup
                    visible: overlay.triptychLobes
                    x: topBar.x
                    y: topBar.y
                    implicitWidth: overlay.triptychLobes ? (topBar.leftX + topBar.leftW) : 0
                    implicitHeight: overlay.triptychLobes ? overlay.barVisibleH : 0
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: 0
                    bottomRightRadius: Math.min(16 * overlay.s, overlay.barBand / 2)
                    deformScale: 0.000015
                    sinks: false
                }
                BlobRect {
                    group: blobGroup
                    visible: overlay.triptychLobes
                    x: topBar.x + topBar.centreX
                    y: topBar.y
                    implicitWidth: overlay.triptychLobes ? topBar.centreW : 0
                    implicitHeight: overlay.triptychLobes ? overlay.barVisibleH : 0
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: Math.min(16 * overlay.s, overlay.barBand / 2)
                    bottomRightRadius: Math.min(16 * overlay.s, overlay.barBand / 2)
                    deformScale: 0.000015
                    sinks: false
                }
                BlobRect {
                    group: blobGroup
                    visible: overlay.triptychLobes
                    x: topBar.x + topBar.rightX
                    y: topBar.y
                    implicitWidth: overlay.triptychLobes ? (topBar.width - topBar.rightX) : 0
                    implicitHeight: overlay.triptychLobes ? overlay.barVisibleH : 0
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: Math.min(16 * overlay.s, overlay.barBand / 2)
                    bottomRightRadius: 0
                    deformScale: 0.000015
                    sinks: false
                }

                // options ride the thickened frame top, drawn in the
                // frame's own scene so there's no separate program, no seam.
                Bar {
                    id: topBar
                    // the bar rides ABOVE the popouts: a popout blob fuses to the
                    // frame edge and grows inward through the band (Popout.qml),
                    // so the band strip must paint on top or the neck would hide
                    // the bar modules it grows from. content insets above the band,
                    // so the bar only ever covers a popout's neck, never its body.
                    z: 1
                    visible: Config.barEnabled && !overlay.monFullscreen && !overlay.delos
                    x: overlay.barMaskX
                    y: overlay.barMaskY
                    width: overlay.barMaskW
                    height: overlay.barMaskH
                    s: overlay.s
                    position: overlay.barPos
                    band: overlay.barBand
                    trayWindow: overlay
                    onPopoutRequested: (name, center) => root.togglePopoutAt(overlay.modelData.name, name, center)
                    onHoverPopoutRequested: (name, center, hovered) => root.setHoverPopout(overlay.modelData.name, name, center, hovered)
                }

                // mixer popout: on a side bar the volume status icon owns it --
                // hovering that icon opens the mixer at its centre; on a
                // top/bottom or absent bar it stays the left-centre frame
                // feature on the thin lip.
                Popout {
                    id: mixerPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "mixer" && root.popoutMon === overlay.modelData.name
                    openW: mixerContent.implicitWidth
                    openH: mixerContent.implicitHeight

                    Mixer {
                        id: mixerContent
                        s: overlay.s
                        open: mixerPop.prog > 0.5
                    }
                }

                // power popout: on a side bar it grows from the bar's inner
                // edge right at the power button; else the right-centre frame
                // feature.
                Popout {
                    id: powerPop
                    group: blobGroup
                    frameThickness: overlay.delos ? overlay.frameTopVisible : overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.delos ? "top" : overlay.barPos
                    align: overlay.delos ? "end" : "center"
                    alongCenter: overlay.delos ? -1 : root.popoutCenter
                    hoverOpen: false
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "power" && root.popoutMon === overlay.modelData.name
                    openW: 74 * overlay.s
                    openH: 312 * overlay.s

                    Power {
                        s: overlay.s
                    }
                }

                // status-icon popouts (side bar only): each owned by its status
                // cluster icon -- hovering the icon opens it at the icon's centre,
                // fused to the bar like the mixer. the deep surfaces (Link,
                // battery) stay the click target for the full view.
                Popout {
                    id: networkPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "network" && root.popoutMon === overlay.modelData.name
                    openW: netContent.implicitWidth
                    openH: netContent.implicitHeight

                    NetworkPopout {
                        id: netContent
                        s: overlay.s
                        open: networkPop.prog > 0.5
                    }
                }

                Popout {
                    id: batteryPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "battery" && root.popoutMon === overlay.modelData.name
                    openW: batContent.implicitWidth
                    openH: batContent.implicitHeight

                    BatteryPopout {
                        id: batContent
                        s: overlay.s
                        open: batteryPop.prog > 0.5
                    }
                }

                Popout {
                    id: bluetoothPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "bluetooth" && root.popoutMon === overlay.modelData.name
                    openW: btContent.implicitWidth
                    openH: btContent.implicitHeight

                    BluetoothPopout {
                        id: btContent
                        s: overlay.s
                        open: bluetoothPop.prog > 0.5
                    }
                }

                // calendar popout: opened from the clock module on the bar, the
                // month calendar grows from the bar edge at the clock.
                Popout {
                    id: calendarPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "calendar" && root.popoutMon === overlay.modelData.name
                    openW: calContent.implicitWidth
                    openH: calContent.implicitHeight

                    CalendarPopout {
                        id: calContent
                        s: overlay.s
                        open: calendarPop.prog > 0.5
                    }
                }

                // media hover popout: hovering the now-playing module grows a
                // compact transport (elapsed line + prev/play/next) from the bar
                // edge at the module; the body's hover latch keeps it open for
                // the buttons. gated off while a clicked popout is up.
                Popout {
                    id: mediaPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    closeDelay: 140  // hover-intent: crossing the border rim never flickers it shut
                    alongCenter: root.hoverPopoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen && root.popout === ""
                    triggerHovered: root.hoverPopout === "media" && root.hoverPopoutMon === overlay.modelData.name
                    openW: mediaContent.implicitWidth
                    openH: mediaContent.implicitHeight

                    MediaPopout {
                        id: mediaContent
                        s: overlay.s
                        open: mediaPop.prog > 0.5
                    }
                }

                // clipboard popout: Super+V grows the clipboard search/history
                // from the bar edge. a keyboard popout (see kbPopouts).
                Popout {
                    id: clipboardPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "clipboard" && root.popoutMon === overlay.modelData.name
                    openW: clipContent.implicitWidth
                    openH: clipContent.implicitHeight

                    ClipboardPopout {
                        id: clipContent
                        s: overlay.s
                        open: clipboardPop.prog > 0.5
                        onCloseRequested: root.popout = ""
                    }
                }

                // link popout: the deep wifi/bluetooth surface, from the bar
                // edge. a keyboard popout (wifi password).
                Popout {
                    id: linkPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "link" && root.popoutMon === overlay.modelData.name
                    openW: linkContent.implicitWidth
                    openH: linkContent.implicitHeight

                    LinkPopout {
                        id: linkContent
                        s: overlay.s
                        open: linkPop.prog > 0.5
                        onCloseRequested: root.popout = ""
                    }
                }

                // inbox popout: the notification centre (the bell), from the bar
                // edge. pointer-only, dismisses via the focus grab.
                Popout {
                    id: inboxPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "inbox" && root.popoutMon === overlay.modelData.name
                    openW: inboxContent.implicitWidth
                    openH: inboxContent.implicitHeight

                    InboxPopout {
                        id: inboxContent
                        s: overlay.s
                        open: inboxPop.prog > 0.5
                        onCloseRequested: root.popout = ""
                    }
                }

                // notification toasts: grow from the bar edge at the bell (like
                // the inbox), auto-open while a popup is live and melt shut when
                // it expires. clicking opens the full inbox at the bell. defers
                // to any clicked popout so it never fights the inbox; hidden on
                // fullscreen and when the bar is off (no bell to grow from).
                Popout {
                    id: toastPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    align: "end"
                    hoverOpen: false
                    s: overlay.s
                    active: Config.barEnabled && !overlay.monFullscreen && root.popout === ""
                    pinned: Notifs.popups.length > 0
                    openW: toastContent.implicitWidth
                    openH: toastContent.implicitHeight

                    ToastPopout {
                        id: toastContent
                        s: overlay.s
                        open: toastPop.prog > 0.5
                        onOpenCenter: root.togglePopoutAt(overlay.modelData.name, "inbox", topBar.bellCenter)
                    }
                }


                // voice popout: the dictation overlay. grabs nothing (excluded
                // from the focus grab below) so dictation lands in the focused app.
                Popout {
                    id: voicePop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "voice" && root.popoutMon === overlay.modelData.name
                    openW: voiceContent.implicitWidth
                    openH: voiceContent.implicitHeight

                    VoicePopout {
                        id: voiceContent
                        s: overlay.s
                        off: root.voiceOff
                        open: voicePop.prog > 0.5
                        onCloseRequested: root.popout = ""
                    }
                }

                // keyring popout: the secret-service password prompt. a keyboard
                // popout; dismissing it cancels the prompt (onPopoutChanged).
                Popout {
                    id: keyringPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "keyring" && root.popoutMon === overlay.modelData.name
                    openW: keyringContent.implicitWidth
                    openH: keyringContent.implicitHeight

                    KeyringPopout {
                        id: keyringContent
                        s: overlay.s
                        open: keyringPop.prog > 0.5
                        onCloseRequested: root.popout = ""
                    }
                }

                // workspaces popout (Super+Tab): the switcher, from the bar edge.
                // pointer-only (drag is hand-tracked inside the surface).
                Popout {
                    id: workspacesPop
                    group: blobGroup
                    frameThickness: overlay.barVisibleH
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: overlay.barPos
                    hoverOpen: false
                    alongCenter: root.popoutCenter
                    s: overlay.s
                    active: !overlay.monFullscreen
                    pinned: root.popout === "workspaces" && root.popoutMon === overlay.modelData.name
                    openW: workspacesContent.implicitWidth
                    openH: workspacesContent.implicitHeight

                    WorkspacesPopout {
                        id: workspacesContent
                        s: overlay.s
                        screenName: overlay.modelData.name
                        open: workspacesPop.prog > 0.5
                        onCloseRequested: root.popout = ""
                    }
                }

                // LEFT sidebar (Features): a corner hotspot at the top-left plus
                // the panel that melts out of the left edge. the corner carries
                // only a HoverHandler (clickless) so a bar click falls through; a
                // deliberate hover arms it, or a click when clickless is off.
                Item {
                    id: sidebarLeftCorner
                    z: 3
                    visible: overlay.sidebarLeftOn && !overlay.monFullscreen
                    x: 0
                    y: 0
                    width: overlay.sidebarCornerW
                    height: overlay.sidebarCornerH
                    property bool armed: false
                    onVisibleChanged: if (!visible) armed = false
                    // the pointer must reach the very corner (where it clamps when
                    // flung there), not just enter the region, so grazing the top
                    // frame near the corner never arms the sidebar.
                    readonly property real reach: 6 * overlay.s
                    readonly property bool atCorner: leftHov.hovered &&
                        leftHov.point.position.x <= sidebarLeftCorner.reach &&
                        leftHov.point.position.y <= sidebarLeftCorner.reach
                    onAtCornerChanged: {
                        if (atCorner) sidebarLeftIntent.restart();
                        else { sidebarLeftIntent.stop(); sidebarLeftCorner.armed = false; }
                    }
                    Timer { id: sidebarLeftIntent; interval: 150; onTriggered: sidebarLeftCorner.armed = true }
                    HoverHandler { id: leftHov; enabled: Config.sidebarClickless }
                    TapHandler {
                        enabled: !Config.sidebarClickless
                        onTapped: root.togglePopout(overlay.modelData.name, "sidebarLeft")
                    }
                }
                // drag intake down the whole left frame edge + corner: a file
                // dragged here opens the sidebar so the stash board is there to
                // drop onto (a HoverHandler is dead during a grab). the board's
                // own DropArea takes drops over it; this catches the edge itself.
                DropArea {
                    id: leftEdgeDrop
                    x: 0
                    y: 0
                    width: (overlay.sidebarLeftOn && !overlay.monFullscreen) ? overlay.leftEdgeStripW : 0
                    height: (overlay.sidebarLeftOn && !overlay.monFullscreen) ? overlay.height : 0
                    onDropped: (drop) => { for (var i = 0; i < drop.urls.length; i++) Stash.addUrl(drop.urls[i]); drop.accept(); }
                }
                Popout {
                    id: sidebarLeftPop
                    group: blobGroup
                    frameThickness: overlay.frameTopVisible
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: "left"
                    hoverOpen: false
                    closeDelay: 300
                    s: overlay.s
                    active: overlay.sidebarLeftOn && !overlay.monFullscreen && (root.popout === "" || root.popout === "sidebarLeft")
                    triggerHovered: (Config.sidebarClickless && sidebarLeftCorner.armed) || overlay.leftDragActive
                    pinned: root.popout === "sidebarLeft" && root.popoutMon === overlay.modelData.name
                    fullSpan: true
                    openW: overlay.sidebarW
                    openH: overlay.height

                    SidebarFeatures {
                        id: sidebarLeftContent
                        s: overlay.s
                        topInset: overlay.sidebarTopGap
                        botInset: overlay.sidebarBotGap
                        open: sidebarLeftPop.prog > 0.5
                        panes: Config.sidebarLeftPanes
                        pane: root.sidebarLeftPane
                        onPaneSelected: (k) => root.sidebarLeftPane = k
                    }
                }

                // RIGHT sidebar (System): mirror on the top-right corner + edge.
                Item {
                    id: sidebarRightCorner
                    z: 3
                    visible: overlay.sidebarRightOn && !overlay.monFullscreen
                    x: overlay.width - overlay.sidebarCornerW
                    y: 0
                    width: overlay.sidebarCornerW
                    height: overlay.sidebarCornerH
                    property bool armed: false
                    onVisibleChanged: if (!visible) armed = false
                    // mirror of the left: only the extreme top-right corner arms it.
                    readonly property real reach: 6 * overlay.s
                    readonly property bool atCorner: rightHov.hovered &&
                        rightHov.point.position.x >= (sidebarRightCorner.width - sidebarRightCorner.reach) &&
                        rightHov.point.position.y <= sidebarRightCorner.reach
                    onAtCornerChanged: {
                        if (atCorner) sidebarRightIntent.restart();
                        else { sidebarRightIntent.stop(); sidebarRightCorner.armed = false; }
                    }
                    Timer { id: sidebarRightIntent; interval: 150; onTriggered: sidebarRightCorner.armed = true }
                    HoverHandler { id: rightHov; enabled: Config.sidebarClickless }
                    TapHandler {
                        enabled: !Config.sidebarClickless
                        onTapped: root.togglePopout(overlay.modelData.name, "sidebarRight")
                    }
                }
                Popout {
                    id: sidebarRightPop
                    group: blobGroup
                    frameThickness: overlay.frameTopVisible
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: "right"
                    hoverOpen: false
                    closeDelay: 300
                    s: overlay.s
                    active: overlay.sidebarRightOn && !overlay.monFullscreen && (root.popout === "" || root.popout === "sidebarRight")
                    triggerHovered: Config.sidebarClickless && sidebarRightCorner.armed
                    pinned: root.popout === "sidebarRight" && root.popoutMon === overlay.modelData.name
                    fullSpan: true
                    openW: overlay.sidebarW
                    openH: overlay.height

                    SidebarSystem {
                        s: overlay.s
                        topInset: overlay.sidebarTopGap
                        botInset: overlay.sidebarBotGap
                        open: sidebarRightPop.prog > 0.5
                        panes: Config.sidebarRightPanes
                        pane: root.sidebarRightPane
                        onPaneSelected: (k) => root.sidebarRightPane = k
                        onDismiss: { if (root.popout === "sidebarRight" && root.popoutMon === overlay.modelData.name) root.popout = ""; }
                        onClipboardRequested: root.togglePopout(overlay.modelData.name, "clipboard")
                    }
                }

                HyprlandFocusGrab {
                    active: root.popout !== "" && root.popoutMon === overlay.modelData.name && !overlay.kbPopout && root.popout !== "voice"
                    windows: [overlay]
                    onCleared: if (root.popoutMon === overlay.modelData.name) root.popout = ""
                }

                // plugin frame popouts: every enabled plugin whose host is
                // a frame popout, fused into the same blob field as Mixer/Power.
                PluginPopouts {
                    id: pluginPops
                    group: blobGroup
                    s: overlay.s
                    active: !overlay.monFullscreen
                    frameThickness: 16
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    pinnedId: (root.popoutMon === overlay.modelData.name && root.popout.indexOf("plugin:") === 0)
                              ? root.popout.substring(7) : ""
                    onUnpinRequested: {
                        if (root.popout.indexOf("plugin:") === 0 && root.popoutMon === overlay.modelData.name)
                            root.popout = "";
                    }
                }

                RecordHud {
                    id: recHud
                    group: blobGroup
                    s: overlay.s
                    smoothing: Config.frameSmoothing
                    barEdge: (Config.barEnabled && !overlay.monFullscreen) ? overlay.barPos : ""
                    barBand: overlay.barBand
                }

                DelosIsland {
                    id: delosIsland
                    group: blobGroup
                    s: overlay.s
                    smoothing: Config.frameSmoothing
                    active: overlay.delos && Config.barEnabled && !overlay.monFullscreen
                    trayWindow: overlay
                    onPopoutRequested: (name) => root.togglePopoutAt(overlay.modelData.name, name, delosIsland.alongCentre)
                    onHoverPopoutRequested: (name, hovered) => root.setHoverPopout(overlay.modelData.name, name, delosIsland.alongCentre, hovered)
                }

            }
        }
    }

    // volume / brightness OSD, re-homed from the floating pill into its own
    // small bottom-centre layer window, just above the bar.
    Variants {
        model: Quickshell.screens
        OsdWindow {}
    }

}
