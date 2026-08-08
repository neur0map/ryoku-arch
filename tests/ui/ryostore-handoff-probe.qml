import QtQuick
import Quickshell
import "hub/pages" as Pages

ShellRoot {
    id: root
    property int attempts: 0

    QtObject {
        id: hub
        property string query: ""
        property var committed: ({})
        function val(key) { return undefined; }
        function stageLive(key, value) {}
        function edit(key, value) {}
    }

    Pages.LockscreenPage { id: locks; width: 1180; height: 760; visible: false; hub: hub }
    Pages.AppearancePage { id: appearance; width: 1180; height: 760; visible: false; hub: hub }
    Pages.AddonsPage { id: addons; width: 1180; height: 760; visible: false; hub: hub }
    Pages.BarStudioPage { id: bars; width: 1180; height: 760; visible: false; hub: hub }
    Pages.FastfetchPage { id: fastfetch; width: 1180; height: 760; visible: false; hub: hub }

    function require(condition, label) {
        if (!condition)
            throw new Error("RYOSTORE-HANDOFF-PROBE-FAIL " + label);
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            root.attempts++;
            if (root.attempts > 200)
                throw new Error("RYOSTORE-HANDOFF-PROBE-FAIL timed out");
            if (locks.skins.length !== 1 || addons.plugins.length !== 1
                    || addons.bundles.length !== 1 || bars.barStyles.length !== 3)
                return;
            require(locks.skins[0].installed === true, "installed locks only");
            require(addons.updateFor(addons.plugins[0]) === "2.0.0", "plugin update from RyoStore");
            require(addons.bundles[0].installedCount === 1, "partial bundle retained");
            require(addons.bundles[0].metadata.items.length === 2, "bundle components rendered");
            appearance.browseRices();
            locks.browseStore();
            addons.tab = "Plugins";
            addons.browseStore();
            addons.tab = "Bundles";
            addons.browseStore();
            bars.browseBarStyles();
            fastfetch.browseFastfetch();
            addons.removeBundle("creator", "editor");
            addons.removeBundle("creator", "");
            console.log("RYOSTORE-HANDOFF-PROBE-PASS");
            Qt.quit();
        }
    }
}
