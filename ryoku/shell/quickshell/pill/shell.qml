//@ pragma UseQApplication
// basic (render-on-demand) loop, not threaded: the bar is static between
// interactions, but the threaded loop spins the render thread every vsync on
// NVIDIA whenever a live MultiEffect (the bead glow, card shadows, art blur) is
// in the scene (measured ~5% idle here). on-demand rendering idles properly;
// the morph is a short scripted timeline and stays smooth on the GUI thread.
//@ pragma DefaultEnv QSG_RENDER_LOOP = basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Ryoku.Blobs
import "Singletons"
import "popouts"

// washi pill. per monitor, two layer-shell windows:
//   reserve = zero-content strip claiming an exclusive zone the height of
//             the rest pill, so tiled windows sit below the pill even
//             while it's expanded or a surface is open.
//   overlay = full-screen transparent Overlay layer hosting the one
//             morphing pill, anchored at top-centre. never moves windows,
//             never re-parented; grows in place, so every surface grows
//             out of the rest pill instead of popping as a separate panel.
//
// input routing = the window mask. collapsed -> mask is the pill rect, rest
// of the screen clicks through. expanded (hover/pin) or surface open ->
// mask cleared, whole layer catches clicks. backdrop press dismisses;
// keyboard focus taken on demand so Escape closes the open surface.
ShellRoot {
    id: root

    property string openMon: ""
    property string openSurface: ""
    property string peekMon: ""

    // which edge popout (mixer/power) is pinned by IPC, and on which
    // monitor. hover is the usual trigger; this is the keybind path.
    property string popout: ""
    property string popoutMon: ""

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

    function toggleSurface(mon, surface) {
        if (root.openMon === mon && root.openSurface === surface) {
            root.close();
            return;
        }
        root.captureReturn(surface);
        root.openMon = mon;
        root.openSurface = surface;
    }

    // the window that held keyboard focus before a focus surface grabbed it.
    // closing the surface drops the layer's Exclusive grab to None, but Hyprland
    // leaves the keyboard on the released layer -- the window stays "active" yet
    // can't type until a real focus change. captured on open, restored on close.
    property string returnAddr: ""

    // address of the currently keyboard-focused window (focusHistoryID 0).
    function focusedWindowAddr() {
        var tl = Hyprland.toplevels.values;
        for (var i = 0; i < tl.length; i++) {
            var o = tl[i] ? tl[i].lastIpcObject : null;
            if (o && o.focusHistoryID === 0)
                return o.address || "";
        }
        return "";
    }

    // remember the focused window when the first focus surface opens (voice never
    // grabs the keyboard, so it needs no handback).
    function captureReturn(surface) {
        if (surface !== "voice" && root.openSurface === "")
            root.returnAddr = root.focusedWindowAddr();
    }

    // hand keyboard focus back to the window the surface stole it from. a plain
    // refocus is a no-op (Hyprland still considers it active), so bounce off the
    // next window to force the keyboard off the released layer, then focus back.
    // the brief sleep lets the intermediate focus change register before the
    // focus-back -- the sequence verified to actually recover keyboard input.
    function restoreFocus(addr) {
        Quickshell.execDetached(["sh", "-c",
            "hyprctl dispatch 'hl.dsp.window.cycle_next()'; sleep 0.05; "
            + "hyprctl dispatch 'hl.dsp.focus({ window = \"address:" + addr + "\" })'"]);
    }

    function close() {
        // user-driven dismissal of the keyring island (Escape, backdrop,
        // Cancel) has to tell the daemon to cancel the prompt. a
        // daemon-driven hide clears Keyring first, so dismiss() is a no-op.
        if (root.openSurface === "keyring")
            Keyring.dismiss();
        var ret = root.returnAddr;
        root.returnAddr = "";
        root.openMon = "";
        root.openSurface = "";
        if (ret !== "")
            root.restoreFocus(ret);
    }

    function show(mon, surface) {
        root.captureReturn(surface);
        root.openMon = mon;
        root.openSurface = surface;
    }

    function peek(mon) {
        root.peekMon = root.peekMon === mon ? "" : mon;
    }

    // a stash install hitting a sudo/polkit prompt asks the deck to step
    // aside so the prompt (a window beneath our keyboard grab) takes focus
    // instead of landing behind the open deck.
    Connections {
        target: Stash
        function onAuthStepAside() { root.close(); }
    }

    // pin/unpin an edge popout (mixer/power) on a monitor. re-issuing the
    // same one clears it. hover opens them on its own; this is the
    // IPC/keybind path.
    function togglePopout(mon, name) {
        if (root.popout === name && root.popoutMon === mon) {
            root.popout = "";
            return;
        }
        root.popout = name;
        root.popoutMon = mon;
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
        function calendar(mon: string): void { root.toggleSurface(mon, "calendar"); }
        function power(mon: string): void { root.togglePopout(mon, "power"); }
        function link(mon: string): void { root.toggleSurface(mon, "link"); }
        function inbox(mon: string): void { root.toggleSurface(mon, "inbox"); }
        function battery(mon: string): void { root.toggleSurface(mon, "battery"); }
        function clipboard(mon: string): void { root.toggleSurface(mon, "clipboard"); }
        function wallpaper(mon: string): void { root.toggleSurface(mon, "wallpaper"); }
        function sysinfo(mon: string): void { root.toggleSurface(mon, "sysinfo"); }
        function stash(mon: string): void { root.toggleSurface(mon, "stash"); }
        // stash-send <file>: open the stash and jump straight to its LocalSend
        // picker for the given file, so the file manager can hand a file to the
        // deck's send flow. show() (not toggle) so it never closes an open deck.
        function stashSend(mon: string, file: string): void {
            root.show(mon, "stash");
            Stash.openSendPicker(file);
        }
        function toolkit(mon: string): void { root.toggleSurface(mon, "toolkit"); }
        function utilities(mon: string): void { root.toggleSurface(mon, "utilities"); }
        function workspaces(mon: string): void { root.toggleSurface(mon, "workspaces"); }
        function keyringPrompt(payload: string): void {
            Keyring.apply(payload);
            var m = Keyring.mon !== "" ? Keyring.mon
                : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
            root.show(m, "keyring");
        }
        function keyringHide(): void {
            Keyring.clear();
            if (root.openSurface === "keyring") { root.openMon = ""; root.openSurface = ""; }
        }
        function voiceShow(mon: string): void { root.show(mon, "voice"); }
        function voiceHide(): void { if (root.openSurface === "voice") root.close(); }
        function peek(mon: string): void { root.peek(mon); }
        function hide(): void { root.close(); }
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
        case "calendar": case "clipboard": case "wallpaper":
        case "link": case "inbox": case "battery": case "sysinfo":
        case "stash": case "toolkit": case "utilities": case "workspaces":
            root.toggleSurface(mon, fn); return true;
        case "mixer": case "power":
            root.togglePopout(mon, fn); return true;
        case "pluginPopout":
            root.togglePopout(mon, "plugin:" + (parts.length > 2 ? parts[2] : ""));
            return true;
        case "voiceShow":
            root.show(mon, "voice"); return true;
        case "voiceHide":
            if (root.openSurface === "voice") root.close();
            return true;
        case "peek":
            root.peek(mon); return true;
        case "hide":
            root.close(); return true;
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
            readonly property real topGap: Config.islandGap * s
            readonly property real restHeight: Config.islandHeight * s
            // only the classic fused island reserves its own strip so tiles
            // sit below it. floating/none/auto-hidden float over content,
            // so the reserved top collapses to a small even gap matching
            // the other three edges.
            readonly property bool reservesIsland: Config.islandStyle === "island" && !Config.islandAutohide && !Config.barEnabled
            readonly property real evenTop: 22 * s
            // bar swells the frame's top into a band; reserve exactly the
            // visible bar (frame top + band, the same numbers as the
            // overlay's barVisibleH) so tiles tuck right under it with only
            // gaps_out between. anything else opens a dead strip that grows
            // with fontScale / monitor height.
            readonly property real barBand: Config.barHeight * s
            readonly property real barVisibleH: Math.max(0, Config.frameBorder - 50) + barBand
            readonly property real zone: Config.barEnabled ? barVisibleH : (reservesIsland ? (restHeight + topGap) : evenTop)

            screen: modelData
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlay
            required property var modelData
            readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))
            readonly property real topGap: Config.islandGap * s

            // bar mode: the frame's top border swells into a band carrying
            // the options (Bar.qml). inverted rect is oversized 50px (its
            // anchors.margins), so the on-screen top is borderTop - 50; the
            // bar adds `barBand` below that.
            readonly property real frameTopVisible: Math.max(0, Config.frameBorder - 50)
            readonly property real barBand: Config.barHeight * s
            readonly property real barVisibleH: frameTopVisible + barBand

            // island appearance, read from the live config. the frame is
            // the same across styles; only the centre island changes.
            //   fused    = classic pill, neck melted into the top frame.
            //   floating = detached pill, hangs below the frame, floats
            //              over content.
            //   none     = no resting island at all.
            // bar mode always fuses: a summoned surface is the bar swelling
            // open downward, never a detached pill colliding with the band.
            readonly property bool fused: Config.islandStyle === "island" || Config.barEnabled
            readonly property bool styleNone: Config.islandStyle === "none" || Config.barEnabled
            readonly property bool autohide: Config.islandAutohide && !styleNone
            // where the pill sits below the screen top. fused rides the
            // frame neck; floating/none hang lower so they read as detached;
            // bar mode clears the band so content drops out of the bar.
            readonly property real floatTopGap: (18 + Config.islandGap) * s
            readonly property real pillTop: Config.barEnabled ? (barVisibleH + topGap)
                : (fused ? topGap : floatTopGap)
            // rest visibility. fused/floating show at rest unless
            // auto-hidden; none never shows at rest. an explicit summon
            // brings a hidden island in: open surface (a keybind), peek or
            // pin, or (auto-hidden) a hover of the top centre. a passing
            // toast or OSD does NOT pop a hidden island, so none and the
            // auto-hidden styles stay clean. notifications and the volume
            // OSD still surface in the always-on island and floating
            // styles, where the island is present anyway.
            readonly property bool idleShown: styleNone ? false : !autohide
            readonly property bool islandShown: !monFullscreen
                && (Config.barEnabled
                    ? pill.surfaceOpen
                    : (idleShown || pill.surfaceOpen || pill.held || (autohide && pill.hoverLatch)))
            // auto-hide reveal trigger: thin strip under the top frame,
            // hover brings the hidden island down.
            readonly property real revealTrigger: pillTop + 14 * s
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0
            // voice is excluded: it must not grab the keyboard, so Handy's
            // dictation lands in the focused app, not the pill.
            readonly property bool focusSurface: surfaceOpen && surface !== "voice"
            readonly property bool modal: focusSurface || pill.held

            // true if this monitor's active workspace has a fullscreen window.
            readonly property bool monFullscreen: {
                var mons = Hyprland.monitors.values;
                for (var i = 0; i < mons.length; i++)
                    if (mons[i].name === modelData.name)
                        return mons[i].activeWorkspace ? mons[i].activeWorkspace.hasFullscreen : false;
                return false;
            }

            onMonFullscreenChanged: if (monFullscreen) {
                if (root.openMon === modelData.name) root.close();
                if (root.peekMon === modelData.name) root.peekMon = "";
                pill.pinned = false;
            }

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            // None, not OnDemand: this layer is always mapped, so OnDemand would
            // hold the keyboard after a surface closes and a launched window can't type.
            WlrLayershell.keyboardFocus: focusSurface ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "pill"

            anchors { top: true; left: true; right: true; bottom: true }

            mask: monFullscreen ? hiddenRegion
                : (modal ? fullRegion
                : (Config.barEnabled ? barRegion
                : (islandShown ? pillRegion : idleRegion)))
            Region { id: hiddenRegion }
            Region {
                id: pillRegion
                readonly property real baseW: Math.max(pill.width, pill.targetW)
                readonly property real baseX: pill.x + (pill.width - baseW) / 2
                readonly property real musicPad: 0
                x: baseX
                y: 0
                width: baseW + musicPad
                height: pill.y + Math.max(pill.height, pill.targetH) + 6 * pill.s
                // edge popouts grab input at their frame-edge trigger and
                // over the open body, so hovering the centre-left/right
                // border opens them while the rest stays click-through.
                Region { x: mixerPop.triggerX; y: mixerPop.triggerY; width: mixerPop.triggerW; height: mixerPop.triggerH }
                Region { x: mixerPop.bodyX; y: mixerPop.bodyY; width: mixerPop.bodyW; height: mixerPop.bodyH }
                Region { x: powerPop.triggerX; y: powerPop.triggerY; width: powerPop.triggerW; height: powerPop.triggerH }
                Region { x: powerPop.bodyX; y: powerPop.bodyY; width: powerPop.bodyW; height: powerPop.bodyH }
                // plugin frame popouts: aggregate trigger+body input grab.
                Region { x: pluginPops.maskTrigX; y: pluginPops.maskTrigY; width: pluginPops.maskTrigW; height: pluginPops.maskTrigH }
                Region { x: pluginPops.maskBodyX; y: pluginPops.maskBodyY; width: pluginPops.maskBodyW; height: pluginPops.maskBodyH }
                // activity strip rides left of the pill, outside the body:
                // grab input over it so its chips (REC stop, stash) get
                // hover/clicks instead of passing through.
                Region { x: activityStrip.x; y: activityStrip.y; width: activityStrip.width; height: activityStrip.height }
                // update island rides top-right, outside the body: grab
                // input for its hover and the click that opens the Hub,
                // instead of passing through to a window.
                Region { x: updateIsland.x; y: updateIsland.y; width: updateIsland.width; height: updateIsland.height }
            }
            Region {
                id: idleRegion
                // reveal trigger: thin strip under the top frame, sized to
                // the rest pill, catches the hover bringing an auto-hidden
                // island down. zero for 'none', which never reveals, so
                // the top centre stays click-through.
                x: overlay.autohide ? pill.x : 0
                y: 0
                width: overlay.autohide ? pill.width : 0
                height: overlay.autohide ? overlay.revealTrigger : 0
                // edge popouts stay part of the frame in every island
                // style, so their hover triggers + open bodies always catch.
                Region { x: mixerPop.triggerX; y: mixerPop.triggerY; width: mixerPop.triggerW; height: mixerPop.triggerH }
                Region { x: mixerPop.bodyX; y: mixerPop.bodyY; width: mixerPop.bodyW; height: mixerPop.bodyH }
                Region { x: powerPop.triggerX; y: powerPop.triggerY; width: powerPop.triggerW; height: powerPop.triggerH }
                Region { x: powerPop.bodyX; y: powerPop.bodyY; width: powerPop.bodyW; height: powerPop.bodyH }
                Region { x: pluginPops.maskTrigX; y: pluginPops.maskTrigY; width: pluginPops.maskTrigW; height: pluginPops.maskTrigH }
                Region { x: pluginPops.maskBodyX; y: pluginPops.maskBodyY; width: pluginPops.maskBodyW; height: pluginPops.maskBodyH }
            }
            Region {
                id: fullRegion
                width: overlay.width
                height: overlay.height
            }
            Region {
                id: barRegion
                // bar strip catches input for its options; the edge popouts
                // keep their hover triggers and bodies so mixer/power still open.
                x: 0
                y: 0
                width: overlay.width
                height: overlay.barVisibleH
                Region { x: mixerPop.triggerX; y: mixerPop.triggerY; width: mixerPop.triggerW; height: mixerPop.triggerH }
                Region { x: mixerPop.bodyX; y: mixerPop.bodyY; width: mixerPop.bodyW; height: mixerPop.bodyH }
                Region { x: powerPop.triggerX; y: powerPop.triggerY; width: powerPop.triggerW; height: powerPop.triggerH }
                Region { x: powerPop.bodyX; y: powerPop.bodyY; width: powerPop.bodyW; height: powerPop.bodyH }
            }

            MouseArea {
                anchors.fill: parent
                enabled: overlay.modal
                acceptedButtons: Qt.AllButtons
                onPressed: (mouse) => {
                    if (mouse.x >= pill.x && mouse.x <= pill.x + pill.width
                            && mouse.y >= pill.y && mouse.y <= pill.y + pill.height)
                        return;
                    if (overlay.surfaceOpen) root.close();
                    else {
                        pill.pinned = false;
                        root.peekMon = "";
                    }
                }
            }

            FocusScope {
                id: focusScope
                anchors.fill: parent
                focus: overlay.focusSurface
                // whole shell hides while a window is fullscreen.
                visible: !overlay.monFullscreen

                Keys.onEscapePressed: if (!pill.linkBack()) root.close()
                Keys.onLeftPressed: (e) => { if (pill.wallpaperOpen) { pill.wallpaperMove(-1); e.accepted = true; } }
                Keys.onRightPressed: (e) => { if (pill.wallpaperOpen) { pill.wallpaperMove(1); e.accepted = true; } }
                Keys.onReturnPressed: (e) => { if (pill.wallpaperOpen) { pill.wallpaperActivate(); e.accepted = true; } }
                Keys.onEnterPressed: (e) => { if (pill.wallpaperOpen) { pill.wallpaperActivate(); e.accepted = true; } }
                Keys.onSpacePressed: (e) => { if (pill.wallpaperOpen) { pill.wallpaperActivate(); e.accepted = true; } }

                // frame and pill share one blob field, so the pill reads
                // as the frame swelling open at top-centre, not a bar on top.
                BlobGroup {
                    id: blobGroup
                    color: Config.matchWallpaper ? Wallust.surface : Config.surfaceColor
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
                    borderTop: Config.barEnabled ? (Config.frameBorder + overlay.barBand) : Config.frameBorder
                    borderBottom: Config.frameBorder
                    borderLeft: Config.frameBorder
                    borderRight: Config.frameBorder
                    opacity: Config.frameOpacity
                    visible: !overlay.monFullscreen
                }

                // options ride the thickened frame top, drawn in the
                // frame's own scene so there's no separate program, no seam.
                Bar {
                    id: topBar
                    visible: Config.barEnabled && !overlay.monFullscreen
                    x: 0
                    y: 0
                    width: overlay.width
                    height: overlay.barVisibleH
                    s: overlay.s
                    contentTop: 0
                    // hold the clock away until the drop panel has fully
                    // melted back into the band, not just until the surface
                    // state clears -- otherwise it overprints the retract.
                    surfaceOpen: overlay.surfaceOpen || pillBlob.visible
                    trayWindow: overlay
                    onCalendarRequested: root.toggleSurface(overlay.modelData.name, "calendar")
                    onPowerRequested: root.togglePopout(overlay.modelData.name, "power")
                }

                BlobRect {
                    // fused pill body, in the frame's field: neck melts
                    // into the top border (or the bar band). blobs only
                    // leave the SDF field by collapsing to zero (field
                    // ignores `visible`, do not "fix" that), so presence
                    // rides geometry. bar and island share one morph: the
                    // blob tracks the LIVE pill geometry, so panel and
                    // content grow and shrink in lockstep. (an earlier bar
                    // close held the panel at full size while the pill
                    // melted to rest inside it -- content visibly collapsed
                    // in a dead slab, then the slab blinked away. never
                    // desync the two geometries.)
                    id: pillBlob
                    group: blobGroup
                    property real reveal: 0
                    x: pill.x
                    y: 0
                    readonly property bool present: overlay.fused && overlay.islandShown
                    visible: height > 0
                    width: pill.width
                    // reveal curtain, floored at the border's inner edge. a
                    // blob whose bottom edge retreats INSIDE the band makes
                    // the field carve its melt pocket (the shader's border
                    // sink) across the blob's full width, and a nearly-flat
                    // blob can't fill that pocket -- the band opens a
                    // trapezoid hole to the desktop until the rect finally
                    // leaves the field at zero. a band-flush blob is
                    // pixel-identical to the band itself, so snapping
                    // straight to zero at the inner edge is invisible and
                    // the pocket regime is never entered.
                    readonly property real bandInnerY: Math.max(0, (Config.barEnabled ? overlay.barBand : 0) + Config.frameBorder - 50)
                    height: {
                        const h = (pill.y + pill.height) * reveal;
                        return h > bandInnerY ? h : 0;
                    }
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: pill.morphRadius
                    bottomRightRadius: pill.morphRadius
                    deformScale: 0
                    opacity: Config.islandOpacity
                    states: State {
                        name: "shown"
                        when: pillBlob.present
                        PropertyChanges { pillBlob.reveal: 1 }
                    }
                    transitions: [
                        Transition {
                            to: "shown"
                            NumberAnimation { property: "reveal"; duration: Motion.morph; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.morphCurve }
                        },
                        Transition {
                            from: "shown"
                            NumberAnimation { property: "reveal"; to: 0; duration: Motion.morph; easing.type: Easing.OutCubic }
                        }
                    ]
                }

                // mixer popout: grows out of the centre-left frame edge on
                // hover, melting into the border through the shared blob field.
                Popout {
                    id: mixerPop
                    group: blobGroup
                    frameThickness: 16
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: "left"
                    s: overlay.s
                    active: !overlay.surfaceOpen && !overlay.monFullscreen
                    pinned: root.popout === "mixer" && root.popoutMon === overlay.modelData.name
                    openW: mixerContent.implicitWidth
                    openH: mixerContent.implicitHeight

                    Mixer {
                        id: mixerContent
                        s: overlay.s
                        open: mixerPop.prog > 0.5
                    }
                }

                // power popout: grows out of the centre-right frame edge on hover.
                Popout {
                    id: powerPop
                    group: blobGroup
                    frameThickness: 16
                    radius: Config.frameRadius
                    smoothing: Config.frameSmoothing
                    edge: "right"
                    s: overlay.s
                    active: !overlay.surfaceOpen && !overlay.monFullscreen
                    pinned: root.popout === "power" && root.popoutMon === overlay.modelData.name
                    openW: 74 * overlay.s
                    openH: 312 * overlay.s

                    Power {
                        s: overlay.s
                    }
                }

                // plugin frame popouts: every enabled plugin whose host is
                // a frame popout, fused into the same blob field as Mixer/Power.
                PluginPopouts {
                    id: pluginPops
                    group: blobGroup
                    s: overlay.s
                    active: !overlay.surfaceOpen && !overlay.monFullscreen
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

                // the island field: a second blob field (not the frame's) that
                // carries the detached floating-pill island style, kept out of
                // the frame field so it never fuses the border.
                BlobGroup {
                    id: islandGroup
                    color: Config.matchWallpaper ? Wallust.surface : Config.surfaceColor
                    smoothing: Config.islandSmoothing
                }

                BlobRect {
                    // island body, in the island field (never the frame
                    // field, so it can't fuse the border).
                    //   fused                = unused (collapsed to nothing).
                    //   detached (float/none)= IS the visible floating
                    //                          pill, rounded rect below the
                    //                          frame.
                    // height carries the same reveal curtain as pillBlob.
                    id: islandBlob
                    group: islandGroup
                    x: pill.x
                    y: overlay.fused ? 0 : pill.y
                    readonly property bool present: overlay.fused ? false
                                                                  : overlay.islandShown
                    property real reveal: present ? 1 : 0
                    visible: reveal > 0
                    width: pill.width
                    height: (overlay.fused ? (pill.y + pill.height) : pill.height) * reveal
                    topLeftRadius: overlay.fused ? 0 : pill.morphRadius
                    topRightRadius: overlay.fused ? 0 : pill.morphRadius
                    bottomLeftRadius: pill.morphRadius
                    bottomRightRadius: pill.morphRadius
                    deformScale: 0
                    opacity: Config.islandOpacity
                    Behavior on reveal {
                        NumberAnimation {
                            duration: Motion.morph
                            easing.type: Motion.easeMorph
                            easing.bezierCurve: Motion.morphCurve
                        }
                    }
                }

                DropArea {
                    // drag a file on the island = stash opens for the drop.
                    // ...except while the workspace switcher is open, where
                    // its own card drags move windows between workspaces.
                    enabled: !pill.workspacesOpen
                    x: pill.x
                    y: pill.y
                    width: pill.width
                    height: pill.height
                    onEntered: (drag) => root.show(overlay.modelData.name, "stash")
                }

                Pill {
                    id: pill
                    anchors.top: parent.top
                    anchors.topMargin: overlay.pillTop
                    anchors.horizontalCenter: parent.horizontalCenter
                    s: overlay.s
                    screenName: overlay.modelData.name
                    barWindow: overlay
                    surface: overlay.surface
                    forcePinned: root.peekMon === overlay.modelData.name
                    satelliteHover: updateIsland.hovered || activityStrip.hovered

                    opacity: overlay.islandShown ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.morph
                            easing.type: Motion.easeMorph
                            easing.bezierCurve: Motion.morphCurve
                        }
                    }
                    transform: Translate {
                        y: overlay.monFullscreen ? -(pill.height + overlay.pillTop + 10 * overlay.s) : 0
                        Behavior on y {
                            NumberAnimation {
                                duration: Motion.morph
                                easing.type: Motion.easeMorph
                                easing.bezierCurve: Motion.morphCurve
                            }
                        }
                    }

                    onRequestSurface: (name) => root.toggleSurface(overlay.modelData.name, name)
                    onRequestClose: root.close()
                }

                Item {
                    // neck/reveal hover zone: covers only the strip ABOVE
                    // the pill body (blob neck up into the frame), plus
                    // the thin reveal trigger while auto-hidden. MUST NOT
                    // overlap the body. the body's own hover is read by a
                    // HoverHandler on the pill, and a covering sibling
                    // here would swallow hover from the surfaces and tray
                    // icons beneath.
                    enabled: !overlay.styleNone
                    x: pill.x
                    y: 0
                    width: pill.width
                    height: overlay.islandShown ? Math.max(0, pill.y) : overlay.revealTrigger
                    HoverHandler { onHoveredChanged: pill.externalHover = hovered }
                }

                ActivityStrip {
                    id: activityStrip
                    s: overlay.s
                    visible: overlay.islandShown && !overlay.surfaceOpen && !pill.toastActive && !pill.osdActive && width > 1
                    x: pill.x - width - 18 * overlay.s
                    y: Math.max(pill.y + pill.height / 2 - height / 2, 22)
                    onRequestSurface: (name) => root.toggleSurface(overlay.modelData.name, name)
                }

                UpdateIsland {
                    id: updateIsland
                    s: overlay.s
                    active: overlay.islandShown && !overlay.surfaceOpen && !pill.toastActive && !pill.osdActive
                    anchors.right: parent.right
                    anchors.rightMargin: 20 * overlay.s
                    y: overlay.pillTop + (pill.restH - height) / 2
                    onActivated: root.openUpdates()
                }
            }

            onSurfaceOpenChanged: if (focusSurface) focusScope.forceActiveFocus()
        }
    }
}
