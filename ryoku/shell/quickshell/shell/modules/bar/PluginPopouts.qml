pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import shell.services
import "popouts"
import Ryoku.PluginKit

/**
 * hosts every enabled plugin whose chosen host = frame popout. frame popouts
 * have to fuse the per-process frame blob field, which lives here in the
 * pill, so the pill renders them through the same Popout machinery as Mixer
 * and Power, supplying the plugin's content/Widget.qml at `full` density.
 * discovery = the shared discover.sh (scan + merge plugins.json + enabled
 * only); a placement change rewrites plugins.json and the daemon calls
 * reload().
 *
 *   PluginPopouts { group: blobGroup; s: overlay.s; active: !overlay.monFullscreen; ... }
 */
Item {
    id: root

    required property var group
    property real s: 1
    property bool active: true
    property real frameThickness: 16
    property real radius: Theme.radiusWidget
    property real smoothing: 30
    property string pinnedId: ""
    // fires when a keybind/IPC-pinned popout should dismiss because the pointer
    // left it (pinned closes like a hover-opened one). pill clears its popout
    // pin in response.
    signal unpinRequested(string pluginId)

    anchors.fill: parent

    property var plugins: []
    property var pluginIds: []
    property alias repeater: popoutRepeater

    // input-mask geometry the pill grabs so hover opens the popout and the
    // open body keeps catching input, same as built-in edge popouts. v1 binds
    // the first frame popout (the common single-popout case); `first` updates
    // when the set changes, trigger/body are live bindings on that instance.
    readonly property var first: pluginIds.length > 0 ? popoutRepeater.itemAt(0) : null
    readonly property real maskTrigX: first ? first.triggerX : 0
    readonly property real maskTrigY: first ? first.triggerY : 0
    readonly property real maskTrigW: first ? first.triggerW : 0
    readonly property real maskTrigH: first ? first.triggerH : 0
    readonly property real maskBodyX: first ? first.maskX : 0
    readonly property real maskBodyY: first ? first.maskY : 0
    readonly property real maskBodyW: first ? first.maskW : 0
    readonly property real maskBodyH: first ? first.maskH : 0

    readonly property string _shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string _script: (_shellDir && _shellDir.length > 0)
        ? _shellDir + "/quickshell/plugins/discover.sh"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/plugins/discover.sh"
    readonly property string _stateHome: Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")
    readonly property string _revision: root._stateHome + "/ryoku/store/revision.json"

    function reload() { discoverProc.running = false; discoverProc.running = true; }
    function syncPlugins(all) {
        const next = all.filter(plugin => plugin.placement && plugin.placement.host === "framePopout");
        root.plugins = next;
        const ids = next.map(plugin => plugin.id);
        const same = ids.length === root.pluginIds.length
            && ids.every((id, index) => id === root.pluginIds[index]);
        if (!same)
            root.pluginIds = ids;
    }
    function handleRevision(raw) {
        try {
            const revision = JSON.parse(raw || "{}");
            if (revision.category === "plugins")
                root.reload();
        } catch (error) {
        }
    }

    Process {
        id: discoverProc
        command: ["bash", root._script]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var all = [];
                try { all = JSON.parse(text || "[]"); } catch (e) { all = []; }
                root.syncPlugins(all);
            }
        }
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/plugins.json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
    }

    FileView {
        id: revisionFile
        path: root._revision
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.handleRevision(text())
    }

    Repeater {
        id: popoutRepeater
        model: root.pluginIds
        delegate: Popout {
            id: pop
            required property string modelData
            readonly property var entry: root.plugins.find(plugin => plugin.id === modelData) || null
            readonly property var place: entry ? entry.placement : ({})
            readonly property string versionQuery: entry && entry.version
                ? "?v=" + encodeURIComponent(entry.version) : ""
            group: root.group
            frameThickness: root.frameThickness
            radius: root.radius
            smoothing: root.smoothing
            edge: (place.framePopout && ["left", "right", "top", "bottom"].indexOf(place.framePopout.edge) >= 0) ? place.framePopout.edge : "top"
            align: (place.framePopout && place.framePopout.align) ? place.framePopout.align : "start"
            s: root.s
            active: root.active
            pinned: root.pinnedId === modelData
            // keybind/IPC-pinned popout dismisses once the pointer leaves it,
            // so it closes like a hover-opened one instead of staying open
            // until the keybind fires again. pointer gets a grace window to
            // travel to the fresh popout; once it has arrived (`_touched`),
            // leaving for `_graceMs` clears the pin. timer also catches a
            // hover-leave a masked layer surface can otherwise miss.
            property bool _touched: false
            readonly property int _graceMs: 2500
            onHoveredChanged: {
                if (pop.hovered) { pop._touched = true; graceTimer.stop(); }
                else if (pop.pinned) graceTimer.restart();
            }
            onPinnedChanged: {
                pop._touched = false;
                if (pop.pinned) graceTimer.restart(); else graceTimer.stop();
            }
            Timer {
                id: graceTimer
                interval: pop._touched ? 220 : pop._graceMs
                onTriggered: if (pop.pinned && !pop.hovered) root.unpinRequested(pop.modelData);
            }
            // body fits content vertically. openH = loaded content's intrinsic
            // height + inner pad, so no deadspace. width is fixed (content lays
            // out to contentW); content is inset by `pad` so nothing sits flush
            // against the edges.
            readonly property real pad: 16 * root.s
            readonly property real contentW: 360 * root.s
            readonly property real contentH: contentLoader.item ? contentLoader.item.implicitHeight : 420 * root.s
            openW: contentW + pad * 2
            openH: contentH + pad * 2
            hoverW: (place.framePopout && place.framePopout.hoverW) ? place.framePopout.hoverW * root.s : 0
            hoverH: (place.framePopout && place.framePopout.hoverH) ? place.framePopout.hoverH * root.s : 0

            // per-plugin service + content, instantiated from the plugin dir.
            property var api: QtObject {
                property var mainInstance: serviceSlot.item
                property var pluginSettings: (pop.place && pop.place.settings) ? pop.place.settings : {}
                property string pluginDir: pop.entry ? pop.entry.dir : ""
                function saveSettings() {}
            }

            PluginObjectSlot {
                id: serviceSlot
                source: pop.entry ? "file://" + pop.entry.dir + "/service/Main.qml" + pop.versionQuery : ""
                configure: (service) => { service.pluginApi = pop.api; }
            }

            PluginObjectSlot {
                id: contentLoader
                anchors.fill: parent
                anchors.margins: pop.pad
                fill: true
                source: pop.entry ? "file://" + pop.entry.dir + "/content/Widget.qml" + pop.versionQuery : ""
                configure: (content) => {
                    content.pluginApi = pop.api;
                    content.density = "full";
                    content.s = root.s;
                    content.widthBudget = pop.contentW;
                    content.active = Qt.binding(() => pop.prog > 0.5);
                }
            }
        }
    }
}
