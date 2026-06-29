//@ pragma UseQApplication
// basic (render-on-demand) loop, not threaded: the desktop widget layer is
// mostly static, and the threaded loop spins the render thread every vsync on
// NVIDIA even when nothing changes (measured ~2x idle CPU here). on-demand
// rendering idles properly and the occasional drag/animation is still smooth.
//@ pragma DefaultEnv QSG_RENDER_LOOP = basic

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "Singletons"
import "clock"
import "weather"

// desktop widgets layer: WlrLayer.Bottom (below windows), one per monitor,
// carrying the clock and weather. only clicks on bare wallpaper land here,
// so windows above keep their input. drag = move (snaps to the fade-in
// grid), right-click a widget = its menu, right-click empty = global menu.
// every knob is live from Config; drag, menus and Ryoku Settings all write
// the same file, so surfaces retune with no reload.
ShellRoot {
    id: root

    // one IP-located weather fetch, shared across monitors, in the user's unit.
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
            // None on purpose. a full-screen Bottom layer that holds kb focus
            // keeps it on an EMPTY workspace (nothing above to steal it), so
            // the next-opened window stays unfocused until you move the mouse
            // or hit a focus bind. pointer is unaffected: layer-shell routes
            // clicks by input region, not kb interactivity (the visualiser
            // relies on the same fact), so drag + the right-click menu still
            // fire. a plugin tile that needs kb grabs its own focused item
            // rather than holding the whole surface.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            anchors { top: true; left: true; right: true; bottom: true }

            // enabled desktopWidget-hosted plugins, filtered from the shared
            // Registry. drives the Repeater below so plugin tiles ride the
            // SAME wallpaper layer as clock/weather: one layer, one input
            // model, no second full-screen surface fighting for input.
            readonly property var desktopPlugins: Registry.plugins.filter(p => p.placement && p.placement.host === "desktopWidget")

            // current persisted desktopWidget block by id. menu handlers use
            // it to round-trip a partial change (lock/scale) without dropping
            // the other coordinates.
            function placementOf(id) {
                const p = win.desktopPlugins.find(pp => pp.id === id);
                return (p && p.placement && p.placement.desktopWidget) || {};
            }

            // right-click empty desktop = global menu. sits behind the widgets
            // (which own their own right-click) and only takes RightButton, so
            // left-clicks on wallpaper fall through instead of being silently
            // swallowed.
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

            // one draggable PluginDesktopSlot per enabled desktopWidget plugin.
            // drag = write free pos. resize bracket = write scale. right-click
            // = per-tile menu. each commit goes through its own Process so a
            // Lock right after a drag can't stomp an in-flight write on
            // `persist`.
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

                    // drag commit: write new free pos. ryoku-plugins-place
                    // merges into plugins.json, the Registry's file-watch
                    // retunes every surface.
                    onMoved: (x, y) => {
                        persist.command = ["ryoku-plugins-place", modelData.id, "desktopWidget", "" + x, "" + y];
                        persist.running = true;
                    }

                    // resize commit: scale + pinned top-left + current locked
                    // flag, so a partial write never drops siblings.
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

            // per-tile right-click menu, hoisted to PanelWindow level so the
            // click-away catcher covers the whole desktop and a tile that
            // vanishes (Hide) doesn't pull the menu down with it.
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

            // position/scale writeback for plugin tiles. ryoku-plugins-place
            // merges free x/y (+ optional scale/locked) into plugins.json;
            // Registry's file-watch then retunes every surface.
            Process { id: persist }
            // separate Processes per menu action so a quick Hide-then-Lock or
            // resize-then-Lock doesn't trample an in-flight `persist` command.
            Process { id: hide }
            Process { id: lockProc }
            // settings writeback from the right-click menu.
            Process { id: settingsProc }
        }
    }
}
