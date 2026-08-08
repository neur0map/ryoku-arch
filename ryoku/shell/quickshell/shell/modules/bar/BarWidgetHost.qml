pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Ryoku.FrameBars
import "framebars/widgets"
import shell.services

// Maps a catalogue id to its Rail* component and forwards the widget's intents
// (menu open, bar action) up to the frame. A self-hiding widget collapses the
// host to nothing so its zone leaves no gap.
Item {
    id: root

    property string widgetId: ""
    required property string edge
    required property real scale
    // space the zone leaves this widget's group (RailZone pushes the binding);
    // only the dock consumes it, to shrink on rails too short for every zone.
    property real zoneAvail: -1
    signal menuRequested(string id, rect ownerRect)
    signal actionRequested(string id)

    readonly property bool loaded: widgetLoader.item !== null
    // The item's own implicitWidth is already 0 when it self-hides (a widget
    // gates on its own condition, never on `visible`, which ancestors pull to
    // false while the bar is collapsed). Hiding a zero-width host lets the zone
    // skip it entirely, so a self-hidden widget leaves no gap.
    implicitWidth: widgetLoader.item ? widgetLoader.item.implicitWidth : 0
    implicitHeight: widgetLoader.item ? widgetLoader.item.implicitHeight : 0
    visible: widgetLoader.item ? widgetLoader.item.implicitWidth > 0 : false

    function componentFor(id) {
        switch (id) {
        case "clock": return clockComponent;
        case "workspaces": return workspacesComponent;
        case "tray": return trayComponent;
        case "quick-settings": return quickSettingsComponent;
        case "dock": return dockComponent;
        case "music": return musicComponent;
        case "sysmon": return sysmonComponent;
        case "vpn": return vpnComponent;
        case "recording": return recordingComponent;
        case "audio-input":
        case "audio-output":
        case "battery":
        case "bluetooth":
        case "network":
        case "notifications": return statusComponent;
        case "lock":
        case "logout":
        case "shutdown": return actionComponent;
        default:
            if (BarCatalog.entry(id)) console.error("frame bars: no host component for " + id);
            return null;
        }
    }

    // Dock data: every toplevel as { className, address, pid }, sorted by pid so
    // resolve() lays the running classes out in pid order (contract 03 sec 3.3).
    function clients() {
        const result = [];
        const toplevels = Hyprland.toplevels.values;
        for (let i = 0; i < toplevels.length; ++i) {
            const data = toplevels[i] && toplevels[i].lastIpcObject;
            const className = data && (data.class || data.initialClass);
            if (typeof className === "string" && className)
                result.push({ className: className, address: data.address || "", pid: (typeof data.pid === "number" ? data.pid : 0) });
        }
        result.sort((a, b) => a.pid - b.pid);
        return result;
    }

    // Class of the focused window, for the dock's selected state.
    function activeClass() {
        const active = Hyprland.activeToplevel && Hyprland.activeToplevel.lastIpcObject;
        return active ? (active.class || active.initialClass || "") : "";
    }

    // A dock with nothing pinned and nothing running renders nothing, which on
    // a fresh boot reads as "the dock is gone". Fall back to the stock role
    // apps (the ones the shipped binds launch) that resolve to an installed
    // desktop entry.
    function starterPins() {
        const out = [];
        for (const className of ["kitty", "chromium", "nautilus"])
            if (DesktopEntries.heuristicLookup(className)) out.push(className);
        return out;
    }

    function updatePinned(className, add) {
        const next = JSON.parse(JSON.stringify(Config.frameBars));
        const pinned = next.dock && Array.isArray(next.dock.pinned) ? next.dock.pinned : [];
        next.dock = { pinned: add ? pinned.concat(pinned.includes(className) ? [] : [className]) : pinned.filter(value => value !== className) };
        Config.frameBars = next;
    }

    // Left click: no running clients -> launch; already selected -> cycle to the
    // next client of the class (by address); else focus, preferring a client on
    // the active workspace. Contract 03 sec 4.1.
    function activate(className) {
        const toplevels = Hyprland.toplevels.values;
        const matches = [];
        for (let i = 0; i < toplevels.length; ++i) {
            const d = toplevels[i] && toplevels[i].lastIpcObject;
            if (d && (d.class === className || d.initialClass === className) && d.address)
                matches.push(d);
        }
        if (matches.length === 0) {
            const entry = DesktopEntries.heuristicLookup(className);
            if (entry)
                entry.execute();
            return;
        }
        matches.sort((a, b) => a.address < b.address ? -1 : (a.address > b.address ? 1 : 0));
        const active = Hyprland.activeToplevel && Hyprland.activeToplevel.lastIpcObject ? Hyprland.activeToplevel.lastIpcObject.address : "";
        const idx = matches.findIndex(m => m.address === active);
        let target;
        if (idx >= 0) {
            target = matches[(idx + 1) % matches.length];
        } else {
            const ws = Workspaces.activeId;
            target = matches.find(m => m.workspace && m.workspace.id === ws) || matches[0];
        }
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + target.address + '" })');
    }

    Loader {
        id: widgetLoader
        anchors.centerIn: parent
        sourceComponent: root.componentFor(root.widgetId)
    }
    Connections {
        target: widgetLoader.item
        ignoreUnknownSignals: true
        function onMenuRequested(id, ownerRect) {
            const topLeft = widgetLoader.item.mapToGlobal(ownerRect.x, ownerRect.y);
            root.menuRequested(id, { x: topLeft.x, y: topLeft.y, width: ownerRect.width, height: ownerRect.height });
        }
        function onActionRequested(id) { root.actionRequested(id); }
    }

    Component { id: clockComponent; RailClock { edge: root.edge; scale: root.scale } }
    Component { id: workspacesComponent; RailWorkspaces { edge: root.edge; scale: root.scale } }
    Component { id: trayComponent; RailTray { edge: root.edge; scale: root.scale } }
    Component { id: quickSettingsComponent; RailQuickSettings { edge: root.edge; scale: root.scale } }
    Component {
        id: dockComponent
        RailDock {
            edge: root.edge
            scale: root.scale
            pinned: Config.normalizedFrameBars.dock.pinned.length > 0
                ? Config.normalizedFrameBars.dock.pinned : root.starterPins()
            clients: root.clients()
            activeClass: root.activeClass()
            maxExtent: root.zoneAvail
            onActivate: className => root.activate(className)
            onPin: className => root.updatePinned(className, true)
            onUnpin: className => root.updatePinned(className, false)
        }
    }
    Component { id: statusComponent; RailStatus { edge: root.edge; scale: root.scale; statusId: root.widgetId } }
    Component { id: musicComponent; RailMusic { edge: root.edge; scale: root.scale } }
    Component { id: sysmonComponent; RailSysmon { edge: root.edge; scale: root.scale } }
    Component { id: vpnComponent; RailVpn { edge: root.edge; scale: root.scale; active: true } }
    Component { id: recordingComponent; RailRecording { edge: root.edge; scale: root.scale } }
    Component { id: actionComponent; RailAction { edge: root.edge; scale: root.scale; actionId: root.widgetId } }
}
