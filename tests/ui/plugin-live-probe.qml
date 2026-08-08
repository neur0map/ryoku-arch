import QtQuick
import Quickshell
import "widgets" as Widgets
import "widgets/Singletons" as WidgetState

ShellRoot {
    id: root

    readonly property var entry: WidgetState.Registry.plugins.find(plugin => plugin.id === "fixture") || null
    readonly property string versionQuery: entry && entry.version
        ? "?v=" + encodeURIComponent(entry.version) : ""
    property bool sawV2: false

    Widgets.PluginDesktopSlot {
        id: desktop
        contentUrl: root.entry
            ? "file://" + root.entry.dir + "/content/Widget.qml" + root.versionQuery : ""
        configure: (content) => {
            content.pluginApi = api;
            content.density = "full";
        }
    }

    Widgets.PluginObjectSlot {
        id: service
        source: root.entry
            ? "file://" + root.entry.dir + "/service/Main.qml" + root.versionQuery : ""
        configure: (object) => { object.pluginApi = api; }
    }

    QtObject {
        id: api
    }

    function inspect() {
        if (root.entry && desktop.item && service.item) {
            const marker = service.item.marker + ":" + desktop.item.marker;
            if (marker !== root.lastMarker) {
                root.lastMarker = marker;
                console.log("PLUGIN-LIVE-MARKER:" + marker);
            }
            if (marker === "service-v2:content-v2")
                root.sawV2 = true;
        } else if (root.sawV2 && !root.entry) {
            console.log("PLUGIN-LIVE-REMOVED");
            Qt.quit();
        }
    }
    property string lastMarker: ""

    Connections {
        target: WidgetState.Registry
        function onPluginsChanged() { root.inspect(); }
    }
    Connections {
        target: desktop
        function onItemChanged() { root.inspect(); }
    }
    Connections {
        target: service
        function onItemChanged() { root.inspect(); }
    }
    Timer {
        interval: 20
        repeat: true
        running: true
        onTriggered: root.inspect()
    }
}
