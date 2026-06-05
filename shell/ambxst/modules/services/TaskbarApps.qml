pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.ambxst.config
import qs.ambxst.modules.services

Singleton {
    id: root

    function isPinned(appId) {
        const pinnedApps = Config.pinnedApps?.apps || [];
        return pinnedApps.some(id => id.toLowerCase() === appId.toLowerCase());
    }

    function togglePin(appId) {
        let pinnedApps = Config.pinnedApps?.apps || [];
        const normalizedAppId = appId.toLowerCase();
        
        if (isPinned(appId)) {
            Config.pinnedApps.apps = pinnedApps.filter(id => id.toLowerCase() !== normalizedAppId);
        } else {
            Config.pinnedApps.apps = pinnedApps.concat([appId]);
        }

        Config.savePinnedApps();
    }

    function getDesktopEntry(appId) {
        if (!appId) return null;
        return DesktopEntries.heuristicLookup(appId) || null;
    }

    function launchApp(appId) {
        const entry = getDesktopEntry(appId);
        if (entry) {
            AppSearch.launchApp(entry);
        }
    }

    property var _appCache: ({})
    property var _previousKeys: []

    property list<var> apps: []

    // Debounce update
    Timer {
        id: updateTimer
        interval: 100
        repeat: false
        onTriggered: root._updateApps()
    }

    Connections {
        target: ToplevelManager.toplevels
        function onObjectInsertedPost() {
            updateTimer.restart();
        }
        function onObjectRemovedPost() {
            updateTimer.restart();
        }
    }

    Connections {
        target: Config.pinnedApps ?? null
        function onAppsChanged() {
            updateTimer.restart();
        }
    }

    Connections {
        target: Config.dock ?? null
        function onIgnoredAppRegexesChanged() {
            updateTimer.restart();
        }
    }

    Component.onCompleted: {
        _updateApps();
    }

    function _updateApps() {
        var map = new Map();

        const pinnedApps = Config.pinnedApps?.apps ?? [];
        const ignoredRegexStrings = Config.dock?.ignoredAppRegexes ?? [];
        const ignoredRegexes = ignoredRegexStrings.map(pattern => new RegExp(pattern, "i"));

        for (const appId of pinnedApps) {
            const key = appId.toLowerCase();
            if (!map.has(key)) {
                map.set(key, {
                    appId: appId,
                    pinned: true,
                    toplevels: []
                });
            }
        }

        var unpinnedRunningApps = [];
        const toplevels = ToplevelManager.toplevels.values;
        for (let i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            if (ignoredRegexes.some(re => re.test(toplevel.appId))) continue;
            
            const key = toplevel.appId.toLowerCase();
            
            if (map.has(key)) {
                map.get(key).toplevels.push(toplevel);
            } else {
                const existing = unpinnedRunningApps.find(app => app.key === key);
                if (!existing) {
                    unpinnedRunningApps.push({
                        key: key,
                        appId: toplevel.appId,
                        toplevels: [toplevel]
                    });
                } else {
                    existing.toplevels.push(toplevel);
                }
            }
        }

        if (pinnedApps.length > 0 && unpinnedRunningApps.length > 0) {
            map.set("SEPARATOR", { 
                appId: "SEPARATOR", 
                pinned: false, 
                toplevels: [] 
            });
        }

        for (const app of unpinnedRunningApps) {
            map.set(app.key, {
                appId: app.appId,
                pinned: false,
                toplevels: app.toplevels
            });
        }

        var newKeys = Array.from(map.keys());

        for (const oldKey of _previousKeys) {
            if (!map.has(oldKey) && _appCache[oldKey]) {
                _appCache[oldKey].destroy();
                delete _appCache[oldKey];
            }
        }

        var values = [];
        for (const [key, value] of map) {
            if (_appCache[key]) {
                _appCache[key].toplevels = value.toplevels;
                _appCache[key].pinned = value.pinned;
                values.push(_appCache[key]);
            } else {
                const entry = appEntryComp.createObject(root, { 
                    appId: value.appId, 
                    toplevels: value.toplevels, 
                    pinned: value.pinned 
                });
                _appCache[key] = entry;
                values.push(entry);
            }
        }

        _previousKeys = newKeys;
        apps = values;
    }

    component TaskbarAppEntry: QtObject {
        required property string appId
        property var toplevels: []
        property int toplevelCount: toplevels.length
        property bool pinned
    }
    
    Component {
        id: appEntryComp
        TaskbarAppEntry {}
    }
}
