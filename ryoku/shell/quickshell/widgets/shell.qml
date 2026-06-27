//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "Singletons"
import "clock"
import "weather"

/**
 * Desktop widgets: a wallpaper layer (WlrLayer.Bottom, below windows) carrying the
 * clock and weather, one per monitor. The layer is interactive across the
 * wallpaper so a right-click anywhere on the bare desktop opens the desktop menu;
 * windows above still receive their own input, so only clicks on visible wallpaper
 * reach it. Drag a widget to move it (it snaps to the grid that fades in),
 * right-click a widget for its own menu, right-click the desktop for the global
 * one. Everything is read live from the widgets Config; the drag, the menus, and
 * Ryoku Settings' Desktop Widgets section all write the same file, so the surfaces
 * retune with no reload.
 */
ShellRoot {
    id: root

    // One IP-located weather fetch shared by every monitor, in the user's unit.
    Binding {
        target: WeatherData
        property: "unit"
        value: Config.weatherUnit
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData

            screen: modelData
            color: "transparent"

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "ryoku-widgets"
            // None. A full-screen Bottom layer that can hold keyboard focus keeps
            // it on an EMPTY workspace (no window above it to take over), so a
            // freshly opened window stays unfocused until you move the mouse or hit
            // a focus bind. Pointer input is unaffected: layer-shell delivers clicks
            // by the input region, not keyboard interactivity (the visualiser relies
            // on the same fact), so widget drag and the right-click desktop menu
            // still fire. A plugin tile that needs the keyboard would grab focus on
            // its own focused item rather than holding the whole surface.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; left: true; right: true; bottom: true }

            // The enabled desktopWidget-hosted plugins, filtered from the shared
            // Registry. Drives the Repeater below so plugin tiles render in the
            // SAME wallpaper layer as clock/weather — one layer, one input model,
            // no second full-screen surface fighting for input.
            readonly property var desktopPlugins: Registry.plugins.filter(p => p.placement && p.placement.host === "desktopWidget")

            // Look up a plugin's currently-persisted desktopWidget block by id.
            // Used by the menu handlers below to round-trip a partial change
            // (lock/scale) without dropping the other coordinates.
            function placementOf(id) {
                const p = win.desktopPlugins.find(pp => pp.id === id);
                return (p && p.placement && p.placement.desktopWidget) || {};
            }

            // Right-click the bare desktop for the global menu. Sits behind the
            // widgets (which handle their own right-click) and takes only the right
            // button, so a left click on the wallpaper does nothing rather than
            // being swallowed in a way that feels broken.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onPressed: (mouse) => menu.openDesktop(mouse.x, mouse.y)
            }

            WidgetGrid {
                anchors.fill: parent
                active: clockSlot.dragging || weatherSlot.dragging
                gridSize: clockSlot.gridSize
            }

            WidgetSlot {
                id: clockSlot
                widget: "clock"
                visible: Config.clockEnabled
                anchor: Config.clockAnchor
                freeX: Config.clockX
                freeY: Config.clockY
                locked: Config.clockLocked
                bg: Config.clockBg
                radius: Config.clockRadius
                scaleCfg: Config.clockScale
                pad: Config.clockBg === "none" ? 0 : Math.round(24 * Config.clockScale)
                opacity: Config.clockOpacity
                onMenuRequested: (x, y, w) => menu.openFor(w, x, y)
                Clock {}
            }

            WidgetSlot {
                id: weatherSlot
                widget: "weather"
                visible: Config.weatherEnabled
                anchor: Config.weatherAnchor
                freeX: Config.weatherX
                freeY: Config.weatherY
                locked: Config.weatherLocked
                bg: Config.weatherBg
                radius: Config.weatherRadius
                scaleCfg: Config.weatherScale
                pad: Config.weatherBg === "none" ? 0 : Math.round(24 * Config.weatherScale)
                opacity: Config.weatherOpacity
                onMenuRequested: (x, y, w) => menu.openFor(w, x, y)
                Weather {}
            }

            // Plugin desktop tiles: one draggable PluginDesktopSlot per enabled
            // desktopWidget plugin. Dragging writes free position; resizing the
            // bracket writes scale; right-click opens the per-tile menu. Each
            // commit goes through a dedicated Process so a Lock right after a
            // drag never clobbers an in-flight write on `persist`.
            Repeater {
                model: win.desktopPlugins
                delegate: PluginDesktopSlot {
                    id: slot
                    required property var modelData
                    readonly property var place: modelData.placement
                    pluginId: modelData.id
                    locked: (place.desktopWidget && place.desktopWidget.locked === true) || false
                    scaleCfg: (place.desktopWidget && place.desktopWidget.scale) || 0.85
                    freeX: (place.desktopWidget && place.desktopWidget.x !== undefined) ? place.desktopWidget.x : 80
                    freeY: (place.desktopWidget && place.desktopWidget.y !== undefined) ? place.desktopWidget.y : 80
                    bg: (place.desktopWidget && place.desktopWidget.bg) ? place.desktopWidget.bg : ((modelData.manifest && modelData.manifest.defaults && modelData.manifest.defaults.desktopWidget && modelData.manifest.defaults.desktopWidget.bg) || "card")
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
                        pluginMenu.openFor(id, dw.locked === true, mx, my,
                            slot.modelData.manifest, slot.modelData.placement);
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

            WidgetMenu { id: menu }

            // Right-click menu for plugin tiles. Lives at the PanelWindow level
            // so its click-away catcher fills the whole desktop, and a tile that
            // disappears (Hide) doesn't take the menu down with it.
            PluginWidgetMenu {
                id: pluginMenu
                onHideRequested: (id) => {
                    hide.command = ["ryoku-plugins-place", id, "enabled", "false"];
                    hide.running = true;
                    pluginMenu.close();
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
                onSettingChanged: (id, key, value) => {
                    var obj = {};
                    obj[key] = value;
                    settingsProc.command = ["ryoku-plugins-place", id, "settings", JSON.stringify(obj)];
                    settingsProc.running = true;
                }
            }

            // Position/scale writeback for plugin tiles. ryoku-plugins-place
            // merges the new free x/y (and optional scale/locked) into
            // plugins.json; the Registry's file watch then retunes every surface.
            Process { id: persist }
            // Dedicated processes for menu actions so a fast Hide-then-Lock or
            // resize-then-Lock doesn't clobber an in-flight command on `persist`.
            Process { id: hide }
            Process { id: lockProc }
            // Per-widget settings writeback from the right-click menu.
            Process { id: settingsProc }
        }
    }
}
