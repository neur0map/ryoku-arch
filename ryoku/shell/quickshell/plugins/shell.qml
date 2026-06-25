//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "Singletons"

/**
 * Plugin desktop layer: hosts every enabled plugin whose chosen host is
 * `desktopWidget`, one draggable tile per plugin on the wallpaper layer
 * (WlrLayer.Bottom, below windows), one window per monitor. Frame-fusing hosts
 * (frame popout, island) live in the pill process instead, because the blob
 * field is per-process; this config owns the independent layers.
 *
 * Discovery is the shared Registry (discover.sh + plugins.json), so the same
 * enable/placement the pill reads drives this layer too. Dragging a tile writes
 * its free position back to plugins.json through the daemon; the resize
 * bracket writes its scale and the right-click menu writes its lock/enabled.
 * Each surface owns a small pool of one-shot Processes per action so two rapid
 * commits (e.g. a lock toggle right after a drag) never clobber each other.
 */
ShellRoot {
    id: root

    readonly property var desktopPlugins: Registry.plugins.filter(p => p.placement && p.placement.host === "desktopWidget")

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "ryoku-plugins"
            // OnDemand so the search field can take keyboard focus when clicked and
            // the slot's drag/click handlers receive the pointer; None would leave
            // the widget inert (the reported "unresponsive to drag or clicks").
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            anchors { top: true; left: true; right: true; bottom: true }

            // Look up a plugin's currently-persisted desktopWidget block by id.
            // Used by the menu handlers below to round-trip a partial change
            // (lock/scale) without dropping the other coordinates.
            function placementOf(id) {
                const p = root.desktopPlugins.find(pp => pp.id === id);
                return (p && p.placement && p.placement.desktopWidget) || {};
            }

            Repeater {
                model: root.desktopPlugins
                delegate: PluginDesktopSlot {
                    id: slot
                    required property var modelData
                    readonly property var place: modelData.placement
                    pluginId: modelData.id
                    locked: (place.desktopWidget && place.desktopWidget.locked === true) || false
                    scaleCfg: (place.desktopWidget && place.desktopWidget.scale) || 0.85
                    freeX: (place.desktopWidget && place.desktopWidget.x !== undefined) ? place.desktopWidget.x : 80
                    freeY: (place.desktopWidget && place.desktopWidget.y !== undefined) ? place.desktopWidget.y : 80
                    bg: (place.desktopWidget && place.desktopWidget.bg) ? place.desktopWidget.bg : "card"
                    radius: (place.desktopWidget && place.desktopWidget.radius) || 26

                    // Drag commit: write the new free position; ryoku-plugins-place
                    // merges into plugins.json and the Registry's file watch
                    // retunes every surface.
                    onMoved: (x, y) => {
                        persist.command = ["ryoku-plugins-place", modelData.id, "desktopWidget", "" + x, "" + y];
                        persist.running = true;
                    }

                    // Resize commit: scale + the pinned top-left + the current
                    // locked flag, so a partial write never drops siblings.
                    onResized: (sc) => {
                        const dw = (slot.place && slot.place.desktopWidget) || {};
                        const x = (dw.x !== undefined) ? dw.x : Math.round(slot.x);
                        const y = (dw.y !== undefined) ? dw.y : Math.round(slot.y);
                        const lk = (dw.locked === true);
                        persist.command = ["ryoku-plugins-place", modelData.id, "desktopWidget",
                            "" + x, "" + y, "" + sc, "" + lk];
                        persist.running = true;
                    }

                    onMenuRequested: (mx, my, id) => {
                        const dw = win.placementOf(id);
                        menu.openFor(id, dw.locked === true, mx, my);
                    }

                    property var api: QtObject {
                        property var mainInstance: svc.item
                        property var pluginSettings: (slot.place && slot.place.settings) ? slot.place.settings : ({})
                        property string pluginDir: slot.modelData.dir
                        function saveSettings() {}
                    }

                    Loader {
                        id: svc
                        source: "file://" + modelData.dir + "/service/Main.qml"
                        onLoaded: if (item) item.pluginApi = slot.api
                    }

                    contentUrl: "file://" + slot.modelData.dir + "/content/Widget.qml"
                    configure: (it) => {
                        it.pluginApi = slot.api;
                        it.density = "compact";
                        it.s = 1;
                        it.widthBudget = 360;
                        it.active = true;
                    }
                }
            }

            // Right-click menu for the tiles. Lives at the PanelWindow level so
            // its click-away catcher fills the whole desktop, and a tile that
            // disappears (Hide) doesn't take the menu down with it.
            PluginWidgetMenu {
                id: menu
                onHideRequested: (id) => {
                    hide.command = ["ryoku-plugins-place", id, "enabled", "false"];
                    hide.running = true;
                    menu.close();
                }
                onLockToggled: (id) => {
                    const dw = win.placementOf(id);
                    const x = (dw.x !== undefined) ? dw.x : 80;
                    const y = (dw.y !== undefined) ? dw.y : 80;
                    const sc = (dw.scale !== undefined) ? dw.scale : 1;
                    const lk = !(dw.locked === true);
                    lockProc.command = ["ryoku-plugins-place", id, "desktopWidget",
                        "" + x, "" + y, "" + sc, "" + lk];
                    lockProc.running = true;
                }
            }

            // Position/scale writeback. ryoku-plugins-place merges the new free
            // x/y (and optional scale/locked) into plugins.json; the Registry's
            // file watch then retunes every surface.
            Process { id: persist }
            // Dedicated processes for menu actions so a fast Hide-then-Lock or
            // resize-then-Lock doesn't clobber an in-flight command on `persist`.
            Process { id: hide }
            Process { id: lockProc }
        }
    }
}
