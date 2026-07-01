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
import "calendar"

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
            // None while nothing on this layer wants the keyboard, so this
            // full-screen Bottom layer never holds focus on an empty workspace
            // (which would otherwise leave the next-opened window unfocused).
            // A plugin tile's focused text field bumps `kbWanted`; the layer
            // then grabs the keyboard (the same exclusive grab the pill uses for
            // its launcher) so the field can be typed in, and releases it the
            // moment the field blurs. pointer input is unaffected either way -
            // layer-shell routes clicks by input region, not kb interactivity -
            // so drag and the right-click menu always fire.
            property int kbWanted: 0
            WlrLayershell.keyboardFocus: kbWanted > 0 ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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

            // the Repeater below is keyed by this id list, not by `desktopPlugins`
            // directly: any placement write (drag, resize, settings) rewrites
            // plugins.json and Registry reparses to a brand-new array, so binding
            // the Repeater to that array would tear down and rebuild every tile -
            // and its service - on every move, throwing away the open search and
            // page. the id list only changes when a plugin is enabled or
            // disabled, so moving a tile keeps its delegate and its live service.
            property var desktopPluginIds: []
            function syncDesktopIds() {
                const ids = win.desktopPlugins.map(p => p.id);
                const same = ids.length === win.desktopPluginIds.length
                    && ids.every((id, i) => id === win.desktopPluginIds[i]);
                if (!same)
                    win.desktopPluginIds = ids;
            }
            Component.onCompleted: win.syncDesktopIds()
            Connections {
                target: Registry
                function onPluginsChanged() { win.syncDesktopIds(); }
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
                active: clockSlot.dragging || weatherSlot.dragging || calSlot.dragging
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

            WidgetSlot {
                id: calSlot
                widget: "cal"
                visible: Config.calEnabled
                anchor: Config.calAnchor
                freeX: Config.calX
                freeY: Config.calY
                locked: Config.calLocked
                bg: Config.calBg
                radius: Config.calRadius
                scaleCfg: Config.calScale
                pad: Config.calBg === "none" ? 0 : Math.round(20 * Config.calScale)
                opacity: Config.calOpacity
                onMenuRequested: (x, y, w) => menu.openFor(w, x, y)
                // the calendar's add field types on this wallpaper layer, so the
                // layer grabs the keyboard while the field holds focus, the same
                // exclusive grab the plugin tiles use.
                onEditingChanged: win.kbWanted += editing ? 1 : -1
                Calendar {}
            }

            // one draggable PluginDesktopSlot per enabled desktopWidget plugin.
            // drag = write free pos. resize bracket = write scale. right-click
            // = per-tile menu. each commit goes through its own Process so a
            // Lock right after a drag can't stomp an in-flight write on
            // `persist`.
            Repeater {
                model: win.desktopPluginIds
                delegate: PluginDesktopSlot {
                    id: slot
                    required property string modelData
                    readonly property string pid: modelData
                    // live registry entry for this id, re-resolved whenever
                    // Registry reloads. placement (x/y/scale/bg) updates here
                    // without rebuilding the delegate, because the model is the
                    // stable id list, not the per-write plugin array.
                    readonly property var entry: Registry.plugins.find(p => p.id === slot.pid) || null
                    readonly property var dw: (entry && entry.placement && entry.placement.desktopWidget) || ({})
                    readonly property string dir: entry ? entry.dir : ""

                    pluginId: slot.pid
                    locked: slot.dw.locked === true
                    scaleCfg: slot.dw.scale || 0.85
                    freeX: slot.dw.x !== undefined ? slot.dw.x : 80
                    freeY: slot.dw.y !== undefined ? slot.dw.y : 80
                    bg: slot.dw.bg ? slot.dw.bg : ((entry && entry.manifest && entry.manifest.defaults && entry.manifest.defaults.desktopWidget && entry.manifest.defaults.desktopWidget.bg) || "card")
                    radius: slot.dw.radius || 26

                    onMoved: (x, y) => {
                        persist.command = ["ryoku-plugins-place", slot.pid, "desktopWidget", "" + x, "" + y];
                        persist.running = true;
                    }
                    onResized: (sc) => {
                        const x = (slot.dw.x !== undefined) ? slot.dw.x : Math.round(slot.x);
                        const y = (slot.dw.y !== undefined) ? slot.dw.y : Math.round(slot.y);
                        const lk = (slot.dw.locked === true);
                        persist.command = ["ryoku-plugins-place", slot.pid, "desktopWidget",
                            "" + x, "" + y, "" + sc, "" + lk];
                        persist.running = true;
                    }
                    onMenuRequested: (mx, my, id) => {
                        pluginMenu.openFor(id, slot.dw.locked === true, mx, my,
                            slot.entry ? slot.entry.manifest : null,
                            slot.entry ? slot.entry.placement : null);
                    }

                    // when the content exposes `editing` (a focused text field),
                    // the wallpaper layer grabs the keyboard for as long as it
                    // stays true. the flag falls back to false if the content is
                    // ever torn down, so the grab can't leak.
                    readonly property bool editing: !!(item && item.editing)
                    onEditingChanged: win.kbWanted += editing ? 1 : -1
                    Component.onDestruction: if (editing) win.kbWanted -= 1

                    property var api: QtObject {
                        property var mainInstance: svc.item
                        property var pluginSettings: (slot.entry && slot.entry.placement && slot.entry.placement.settings) ? slot.entry.placement.settings : ({})
                        property string pluginDir: slot.dir
                        function saveSettings() {}
                    }

                    Loader {
                        id: svc
                        active: slot.dir.length > 0
                        source: slot.dir.length > 0 ? "file://" + slot.dir + "/service/Main.qml" : ""
                        onLoaded: if (item) item.pluginApi = slot.api
                    }

                    contentUrl: slot.dir.length > 0 ? "file://" + slot.dir + "/content/Widget.qml" : ""
                    configure: (it) => {
                        it.pluginApi = slot.api;
                        it.screen = win.screen;
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
