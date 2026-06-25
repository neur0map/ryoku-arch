pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"
import "popouts"

/**
 * Hosts every enabled plugin whose chosen host is a frame popout. Frame popouts
 * must fuse the frame's blob field, which is per-process and lives here in the
 * pill; so the pill renders them through the same Popout machinery as Mixer and
 * Power, supplying the plugin's content/Widget.qml at `full` density. Discovery
 * is the shared discover.sh (scan + merge plugins.json + enabled-only); a
 * placement change rewrites plugins.json and the daemon calls reload().
 *
 *   PluginPopouts { group: blobGroup; s: overlay.s; active: !surfaceOpen; ... }
 */
Item {
    id: root

    required property var group
    property real s: 1
    property bool active: true
    property real frameThickness: 16
    property real radius: 16
    property real smoothing: 30
    property string pinnedId: ""

    anchors.fill: parent

    property var plugins: []
    property alias repeater: popoutRepeater

    // Input-mask geometry the pill grabs so hover opens the popout and its open
    // body keeps catching input, like the built-in edge popouts. v1 binds the
    // first frame popout (the common single-popout case); `first` updates when
    // the set changes, and its trigger/body are live bindings on that instance.
    readonly property var first: plugins.length > 0 ? popoutRepeater.itemAt(0) : null
    readonly property real maskTrigX: first ? first.triggerX : 0
    readonly property real maskTrigY: first ? first.triggerY : 0
    readonly property real maskTrigW: first ? first.triggerW : 0
    readonly property real maskTrigH: first ? first.triggerH : 0
    readonly property real maskBodyX: first ? first.bodyX : 0
    readonly property real maskBodyY: first ? first.bodyY : 0
    readonly property real maskBodyW: first ? first.bodyW : 0
    readonly property real maskBodyH: first ? first.bodyH : 0

    readonly property string _shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string _script: (_shellDir && _shellDir.length > 0)
        ? _shellDir + "/quickshell/plugins/discover.sh"
        : Quickshell.env("HOME") + "/.local/share/ryoku/quickshell/plugins/discover.sh"

    function reload() { discoverProc.running = false; discoverProc.running = true; }

    Process {
        id: discoverProc
        command: ["bash", root._script]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var all = [];
                try { all = JSON.parse(text || "[]"); } catch (e) { all = []; }
                root.plugins = all.filter(p => (p.placement && p.placement.host === "framePopout"));
            }
        }
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/plugins.json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
    }

    Repeater {
        id: popoutRepeater
        model: root.plugins
        delegate: Popout {
            id: pop
            required property var modelData
            readonly property var place: modelData.placement
            group: root.group
            frameThickness: root.frameThickness
            radius: root.radius
            smoothing: root.smoothing
            edge: (place.framePopout && ["left", "right", "top", "bottom"].indexOf(place.framePopout.edge) >= 0) ? place.framePopout.edge : "right"
            align: (place.framePopout && place.framePopout.align) ? place.framePopout.align : "center"
            s: root.s
            active: root.active
            pinned: root.pinnedId === modelData.id
            openW: 360 * root.s
            openH: 460 * root.s
            hoverW: (place.framePopout && place.framePopout.hoverW) ? place.framePopout.hoverW * root.s : 0
            hoverH: (place.framePopout && place.framePopout.hoverH) ? place.framePopout.hoverH * root.s : 0

            // Per-plugin service + content, instantiated from the plugin dir.
            property var api: QtObject {
                property var mainInstance: svcLoader.item
                property var pluginSettings: (pop.place && pop.place.settings) ? pop.place.settings : {}
                property string pluginDir: pop.modelData.dir
                function saveSettings() {}
            }

            Loader {
                id: svcLoader
                source: "file://" + pop.modelData.dir + "/service/Main.qml"
                onLoaded: if (item) item.pluginApi = pop.api
            }

            Loader {
                id: contentLoader
                anchors.fill: parent
                source: "file://" + pop.modelData.dir + "/content/Widget.qml"
                onLoaded: {
                    if (!item) return;
                    item.pluginApi = pop.api;
                    item.density = "full";
                    item.s = root.s;
                    item.widthBudget = pop.openW;
                    item.active = Qt.binding(() => pop.prog > 0.5);
                }
            }
        }
    }
}
