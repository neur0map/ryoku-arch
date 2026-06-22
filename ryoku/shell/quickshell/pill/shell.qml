//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Ryoku.Blobs
import "Singletons"
import "popouts"

/**
 * Washi pill top shell. Each monitor carries two layer-shell windows:
 *
 *  - `reserve` is a zero-content strip that only claims an exclusive zone the
 *    height of the rest pill, so tiled windows always sit below the pill even
 *    while it is expanded or a surface is open.
 *  - `overlay` is a full-screen transparent Overlay layer hosting the single
 *    morphing pill anchored at top-centre. The pill never moves windows and is
 *    never re-parented; it just grows in place, so every surface grows out of
 *    the rest pill instead of popping up as a separate panel.
 *
 * Input is routed by the window mask. While the pill is collapsed the mask is
 * the pill rect only, so the rest of the screen clicks through to windows.
 * While the pill is expanded (hovered/pinned) or a surface is open the mask is
 * cleared so the whole layer catches clicks. A backdrop press dismisses, and
 * keyboard focus is taken on demand so Escape closes the open surface.
 */
ShellRoot {
    id: root

    property string openMon: ""
    property string openSurface: ""
    property string peekMon: ""

    // Which edge popout (mixer/power) is pinned open by IPC, and on which
    // monitor. Hover is the primary trigger; this just lets a keybind force one.
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
        // Re-establish the durable idle inhibitor to match the persisted flag.
        // On a shell reload the external inhibitor is usually still up (it lives
        // outside this process), so "start" is an idempotent confirm; "stop"
        // clears any stray inhibitor when Keep-Awake is off.
        root.syncCaffeine(Flags.keepAwake ? "start" : "stop");
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

    // Keep-Awake's durable inhibitor lives outside the shell so it survives a
    // reload/restart: ryoku-cmd-caffeine runs systemd-inhibit via systemd-run
    // (setsid fallback), independent of this process's lifetime. The Wayland
    // IdleInhibitor above only gives immediate compositor-level effect and dies
    // with the pill on every respawn; this bridge keeps Keep-Awake unbroken
    // across the swap. Every surface toggle still just flips Flags.keepAwake.
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

    /**
     * Only these raw events can change what the pill renders (per-monitor
     * active workspace, minimized toplevels, monitor hotplug). Everything
     * else (window drags, resizes, title spam) must not trigger the triple
     * model refresh, which costs three Hyprland IPC round-trips.
     */
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
            if (root.refreshEvents[event.name])
                root.refresh();
        }
    }

    function toggleSurface(mon, surface) {
        if (root.openMon === mon && root.openSurface === surface) {
            root.close();
            return;
        }
        root.openMon = mon;
        root.openSurface = surface;
    }

    function close() {
        root.openMon = "";
        root.openSurface = "";
    }

    function show(mon, surface) {
        root.openMon = mon;
        root.openSurface = surface;
    }

    function peek(mon) {
        root.peekMon = root.peekMon === mon ? "" : mon;
    }

    // Pin/unpin an edge popout (mixer/power) on a monitor; re-issuing the same
    // one clears it. Hover opens them on its own, so this is the IPC/keybind path.
    function togglePopout(mon, name) {
        if (root.popout === name && root.popoutMon === mon) {
            root.popout = "";
            return;
        }
        root.popout = name;
        root.popoutMon = mon;
    }

    // Open the Hub on its Updates section. The update island is an entry point to
    // the surface Super+, opens; binds.lua holds the canonical launcher, so this
    // mirrors its flock guard to avoid spawning a second Hub instance.
    function openUpdates() {
        Quickshell.execDetached(["sh", "-c",
            "ryoku-hub config set section updates; flock -n -o /tmp/ryoku-hub.lock qs -c hub"]);
    }

    IpcHandler {
        target: "pill"
        function mixer(mon: string): void { root.togglePopout(mon, "mixer"); }
        function calendar(mon: string): void { root.toggleSurface(mon, "calendar"); }
        function launcher(mon: string): void { root.toggleSurface(mon, "launcher"); }
        function power(mon: string): void { root.togglePopout(mon, "power"); }
        function link(mon: string): void { root.toggleSurface(mon, "link"); }
        function inbox(mon: string): void { root.toggleSurface(mon, "inbox"); }
        function battery(mon: string): void { root.toggleSurface(mon, "battery"); }
        function clipboard(mon: string): void { root.toggleSurface(mon, "clipboard"); }
        function wallpaper(mon: string): void { root.toggleSurface(mon, "wallpaper"); }
        function media(mon: string): void {
            if (Mpris.players.values.length > 0)
                root.toggleSurface(mon, "media");
        }
        function sysinfo(mon: string): void { root.toggleSurface(mon, "sysinfo"); }
        function stash(mon: string): void { root.toggleSurface(mon, "stash"); }
        function toolkit(mon: string): void { root.toggleSurface(mon, "toolkit"); }
        function utilities(mon: string): void { root.toggleSurface(mon, "utilities"); }
        function workspaces(mon: string): void { root.toggleSurface(mon, "workspaces"); }
        function voiceShow(mon: string): void { root.show(mon, "voice"); }
        function voiceHide(): void { if (root.openSurface === "voice") root.close(); }
        function peek(mon: string): void { root.peek(mon); }
        function hide(): void { root.close(); }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: reserve
            required property var modelData
            readonly property real s: modelData ? modelData.height / 1080 : 1
            readonly property real topGap: Config.islandGap * s
            readonly property real restHeight: Config.islandHeight * s
            // Only the classic fused island, shown at rest, reserves its own strip
            // so tiles sit below it. Floating, none, and any auto-hidden island
            // float over the content instead, so the reserved top collapses to a
            // small even gap that matches the other three frame edges.
            readonly property bool reservesIsland: Config.islandStyle === "island" && !Config.islandAutohide
            readonly property real evenTop: 22 * s
            readonly property real zone: reservesIsland ? (restHeight + topGap) : evenTop

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
            readonly property real s: modelData ? modelData.height / 1080 : 1
            readonly property real topGap: Config.islandGap * s

            // Island appearance, read from the live config. The frame is identical
            // across styles; only the centre island changes.
            //  - fused: the classic pill, its neck melted into the top frame.
            //  - floating: a detached pill that hangs below the frame and floats
            //    over the content.
            //  - none: no resting island at all.
            readonly property bool fused: Config.islandStyle === "island"
            readonly property bool styleNone: Config.islandStyle === "none"
            readonly property bool autohide: Config.islandAutohide && !styleNone
            // Where the pill sits below the screen top: fused rides the frame neck,
            // floating/none hang a little lower so they read as detached.
            readonly property real floatTopGap: (18 + Config.islandGap) * s
            readonly property real pillTop: fused ? topGap : floatTopGap
            // Rest visibility: fused/floating show at rest unless auto-hidden; none
            // never shows at rest. An open surface, a peek/pin, a notification toast
            // or an OSD, or (when auto-hidden) a hover of the top centre still bring
            // the island in, so notifications, surfaces, and keybinds stay fully
            // functional in every style: a hidden island drops in to show a toast or
            // a volume change, then retracts.
            readonly property bool idleShown: styleNone ? false : !autohide
            readonly property bool islandShown: !monFullscreen
                && (idleShown || pill.surfaceOpen || pill.held || pill.toastActive
                    || pill.osdActive || (autohide && pill.hoverLatch))
            // The auto-hide reveal trigger: a thin strip under the top frame that
            // brings the hidden island down on hover.
            readonly property real revealTrigger: pillTop + 14 * s
            readonly property string surface: root.openMon === modelData.name ? root.openSurface : ""
            readonly property bool surfaceOpen: surface.length > 0
            // Voice dictation must not steal keyboard focus or block the pointer:
            // Handy types the transcription into whatever app the user is dictating
            // into, so the voice surface stays non-modal and OnDemand-focus.
            readonly property bool focusSurface: surfaceOpen && surface !== "voice"
            readonly property bool modal: focusSurface || pill.held

            // True when this monitor's active workspace has a fullscreen window.
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
            WlrLayershell.keyboardFocus: focusSurface ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
            WlrLayershell.namespace: "pill"

            anchors { top: true; left: true; right: true; bottom: true }

            mask: monFullscreen ? hiddenRegion
                : (modal ? fullRegion : (islandShown ? pillRegion : idleRegion))
            Region { id: hiddenRegion }
            Region {
                id: pillRegion
                readonly property real baseW: Math.max(pill.width, pill.targetW)
                readonly property real baseX: pill.x + (pill.width - baseW) / 2
                readonly property real musicPad: musicIsland.visible ? Math.max(0, musicIsland.x + musicIsland.width - (baseX + baseW)) : 0
                x: baseX
                y: 0
                width: baseW + musicPad
                height: pill.y + Math.max(pill.height, pill.targetH) + 6 * pill.s
                // Edge popouts grab input at the frame edges (their trigger) and
                // over the open body, so hovering the centre-left/right border
                // opens them while the rest of the screen stays click-through.
                Region { x: mixerPop.triggerX; y: mixerPop.triggerY; width: mixerPop.triggerW; height: mixerPop.triggerH }
                Region { x: mixerPop.bodyX; y: mixerPop.bodyY; width: mixerPop.bodyW; height: mixerPop.bodyH }
                Region { x: powerPop.triggerX; y: powerPop.triggerY; width: powerPop.triggerW; height: powerPop.triggerH }
                Region { x: powerPop.bodyX; y: powerPop.bodyY; width: powerPop.bodyW; height: powerPop.bodyH }
                // The activity strip rides left of the pill, outside the pill body,
                // so input must be grabbed over it for its chips (REC stop, stash) to
                // receive hover and clicks instead of passing through to the window.
                Region { x: activityStrip.x; y: activityStrip.y; width: activityStrip.width; height: activityStrip.height }
                // The update island rides the top-right corner, outside the pill
                // body, so input must be grabbed over it for its hover and the
                // click that opens the Hub instead of passing through to a window.
                Region { x: updateIsland.x; y: updateIsland.y; width: updateIsland.width; height: updateIsland.height }
            }
            Region {
                id: idleRegion
                // The reveal trigger: a thin strip under the top frame, sized to the
                // rest pill, that catches the hover bringing an auto-hidden island
                // down. Zero for 'none', which never reveals, so the top centre stays
                // click-through and fully functional.
                x: overlay.autohide ? pill.x : 0
                y: 0
                width: overlay.autohide ? pill.width : 0
                height: overlay.autohide ? overlay.revealTrigger : 0
                // Edge popouts stay part of the frame in every island style, so their
                // hover triggers and open bodies always catch input.
                Region { x: mixerPop.triggerX; y: mixerPop.triggerY; width: mixerPop.triggerW; height: mixerPop.triggerH }
                Region { x: mixerPop.bodyX; y: mixerPop.bodyY; width: mixerPop.bodyW; height: mixerPop.bodyH }
                Region { x: powerPop.triggerX; y: powerPop.triggerY; width: powerPop.triggerW; height: powerPop.triggerH }
                Region { x: powerPop.bodyX; y: powerPop.bodyY; width: powerPop.bodyW; height: powerPop.bodyH }
            }
            Region {
                id: fullRegion
                width: overlay.width
                height: overlay.height
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
                // The whole shell hides while a window is fullscreen.
                visible: !overlay.monFullscreen

                Keys.onEscapePressed: if (!pill.linkBack()) root.close()
                Keys.onLeftPressed: (e) => { if (pill.wallpaperOpen) { pill.wallpaperMove(-1); e.accepted = true; } }
                Keys.onRightPressed: (e) => { if (pill.wallpaperOpen) { pill.wallpaperMove(1); e.accepted = true; } }
                Keys.onReturnPressed: (e) => { if (pill.wallpaperOpen) { pill.wallpaperActivate(); e.accepted = true; } }
                Keys.onEnterPressed: (e) => { if (pill.wallpaperOpen) { pill.wallpaperActivate(); e.accepted = true; } }
                Keys.onSpacePressed: (e) => { if (pill.wallpaperOpen) { pill.wallpaperActivate(); e.accepted = true; } }

                // The screen frame and the pill share one blob field, so the pill
                // reads as the frame swelling open at top-centre, not a bar on top.
                BlobGroup {
                    id: blobGroup
                    color: Config.surfaceColor
                    smoothing: Config.frameSmoothing
                    shadowStrength: Config.shadowStrength
                    shadowSize: Config.shadowSize
                }

                BlobInvertedRect {
                    // The rounded screen border, sitting in Hyprland's gaps_out ring.
                    // Oversized by 50px so the outer edge clips off-screen and only the
                    // inner (window) edge shows; borders grow to keep the hole at gaps_out.
                    anchors.fill: parent
                    anchors.margins: -50
                    group: blobGroup
                    radius: Config.frameRadius
                    borderTop: Config.frameBorder
                    borderBottom: Config.frameBorder
                    borderLeft: Config.frameBorder
                    borderRight: Config.frameBorder
                    opacity: Config.frameOpacity
                    visible: !overlay.monFullscreen
                }

                BlobRect {
                    // The fused pill body, in the frame's field: it runs from the
                    // screen top through the pill so its neck melts into the top
                    // border. A blob leaves the SDF field only by collapsing to zero
                    // size (the field ignores `visible`), so presence rides `height`:
                    // `reveal` eases 0..1 to curtain it down out of the frame on show
                    // and retract it on hide. Present only in the fused style.
                    id: pillBlob
                    group: blobGroup
                    x: pill.x
                    y: 0
                    readonly property bool present: overlay.fused && overlay.islandShown
                    property real reveal: present ? 1 : 0
                    visible: reveal > 0
                    width: pill.width
                    height: (pill.y + pill.height) * reveal
                    topLeftRadius: 0
                    topRightRadius: 0
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

                // Mixer popout: grows out of the centre-left frame edge on hover,
                // melting into the border through the frame's shared blob field.
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
                    openW: (mixerContent.faderCount * 64 + 36) * overlay.s
                    openH: 214 * overlay.s

                    Mixer {
                        id: mixerContent
                        s: overlay.s
                    }
                }

                // Power popout: grows out of the centre-right frame edge on hover.
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

                // The music island buds off the centre island through its own blob
                // field: a pill-shaped anchor it warps out of and melts back into. A
                // second field (not the frame's) so the music never fuses the border.
                BlobGroup {
                    id: islandGroup
                    color: Config.surfaceColor
                    smoothing: Config.islandSmoothing
                }

                BlobRect {
                    // The island body, in the island field (never the frame field, so
                    // it cannot fuse the border). Fused: it mirrors the pillBlob as the
                    // anchor the music bud melts into, present only while music shows.
                    // Detached (floating/none): it IS the visible floating pill, a fully
                    // rounded rect below the frame that the music buds off. Height
                    // carries the same reveal curtain as the pillBlob.
                    id: islandBlob
                    group: islandGroup
                    x: pill.x
                    y: overlay.fused ? 0 : pill.y
                    readonly property bool present: overlay.fused ? musicIsland.visible
                                                                  : (overlay.islandShown || musicIsland.visible)
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

                BlobRect {
                    // Tracks the music island; the smooth-min neck to islandBlob
                    // stretches and breaks as it slides out (the warp), and reforms
                    // as it melts back in on close.
                    id: musicBlob
                    group: islandGroup
                    x: musicIsland.x
                    y: musicIsland.y
                    // Collapse to nothing when hidden: the SDF field ignores `visible`,
                    // so a sized-but-invisible bud still shows wherever another shape in
                    // the group paints. Zero size removes it from the field entirely.
                    width: musicIsland.visible ? musicIsland.width : 0
                    height: musicIsland.visible ? musicIsland.height : 0
                    radius: musicIsland.height / 2
                    deformScale: 0
                    opacity: Config.islandOpacity
                    visible: musicIsland.visible
                }

                DropArea {
                    // Drag a file onto the island and the stash opens for the drop.
                    // ...except while the workspace switcher is open, where its
                    // own card drags move windows between workspaces.
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
                    // Hover zone that opens the island: the whole blob -- the neck up
                    // into the frame and a margin below the clock -- not just the clock.
                    // Sits in front of the pill so its passive HoverHandler always
                    // sees the pointer; the tray icons' own hoverEnabled MouseAreas
                    // would otherwise swallow the hover and collapse the island when
                    // crossed. Being handler-only it never blocks their clicks/hover.
                    enabled: !overlay.styleNone
                    x: pill.x
                    y: 0
                    width: pill.width
                    height: overlay.islandShown ? (pill.y + pill.height + 6 * overlay.s) : overlay.revealTrigger
                    HoverHandler { onHoveredChanged: pill.hovered = hovered }
                }

                MusicIsland {
                    id: musicIsland
                    s: overlay.s
                    live: !overlay.surfaceOpen
                    open: overlay.islandShown && !overlay.surfaceOpen && !pill.toastActive && !pill.osdActive
                    x: {
                        const start = pill.x + pill.width / 2 - width / 2;
                        const end = pill.x + pill.width + 18 * overlay.s;
                        return start + (end - start) * reveal;
                    }
                    y: Math.max(pill.y + pill.height / 2 - height / 2, 22)
                    onHoveredChanged: if (hovered) pill.hovered = false
                    onActivated: root.toggleSurface(overlay.modelData.name, "media")
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
