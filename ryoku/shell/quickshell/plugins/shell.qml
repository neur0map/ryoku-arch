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
 * its free position back to plugins.json through the daemon.
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
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; left: true; right: true; bottom: true }

            Repeater {
                model: root.desktopPlugins
                delegate: PluginDesktopSlot {
                    id: slot
                    required property var modelData
                    readonly property var place: modelData.placement
                    pluginId: modelData.id
                    freeX: (place.desktopWidget && place.desktopWidget.x !== undefined) ? place.desktopWidget.x : 80
                    freeY: (place.desktopWidget && place.desktopWidget.y !== undefined) ? place.desktopWidget.y : 80
                    bg: (place.desktopWidget && place.desktopWidget.bg) ? place.desktopWidget.bg : "card"

                    onMoved: (x, y) => persist.command =
                        ["ryoku-plugins-place", modelData.id, "desktopWidget", "" + x, "" + y]

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

                    Loader {
                        id: contentLoader
                        source: "file://" + modelData.dir + "/content/Widget.qml"
                        onLoaded: {
                            if (!item) return;
                            item.pluginApi = slot.api;
                            item.density = "compact";
                            item.s = 1;
                            item.widthBudget = 320;
                            item.active = true;
                        }
                    }
                }
            }

            // Position writeback. ryoku-plugins-place merges the new free x/y into
            // plugins.json; the Registry's file watch then retunes every surface.
            Process { id: persist }
        }
    }
}
