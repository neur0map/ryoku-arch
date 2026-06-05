pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // usage.json path
    // QUICKSHELL-GIT: property string usageFilePath: Quickshell.cachePath("usage.json")
    property string usageFilePath: Quickshell.env("HOME") + "/.cache/ambxst/usage.json"

    // Cache: { appId: { count, lastUsed } }
    property var usageData: ({})
    property bool dataLoaded: false
    property bool fileReady: false

    signal usageDataReady

    readonly property int maxBoostScore: 200
    readonly property int dayInMs: 86400000

    Process {
        id: ensureUsageFile
        running: true
        command: ["bash", "-c", "mkdir -p \"$(dirname '" + root.usageFilePath + "')\" && if [ ! -f '" + root.usageFilePath + "' ]; then echo '{}' > '" + root.usageFilePath + "'; fi"]
        onExited: {
            root.fileReady = true;
            Qt.callLater(() => usageFile.reload());
        }
    }

    FileView {
        id: usageFile
        path: root.fileReady ? root.usageFilePath : ""
        onLoaded: root.loadUsageData()
    }

    Component.onCompleted: {
        Qt.callLater(() => usageFile.reload());
    }

    function loadUsageData() {
        try {
            const data = usageFile.text();
            if (!data || data.trim() === "") {
                console.log("UsageTracker: No existing usage data, starting fresh");
                root.usageData = {};
                root.dataLoaded = true;
                root.usageDataReady();
                return;
            }

            root.usageData = JSON.parse(data);
            console.log("UsageTracker: Loaded", Object.keys(root.usageData).length, "entries from usage.json");
            root.dataLoaded = true;
            root.usageDataReady();
        } catch (e) {
            console.warn("UsageTracker: Failed to parse usage.json:", e);
            root.usageData = {};
            root.dataLoaded = true;
            root.usageDataReady();
        }
    }

    function saveUsageData() {
        if (!root.fileReady) {
            console.warn("UsageTracker: File not ready, skipping save");
            return;
        }

        const jsonData = JSON.stringify(usageData, null, 2);
        usageFile.setText(jsonData);
    }

    function recordUsage(appId) {
        if (!appId) {
            console.warn("UsageTracker: recordUsage called with empty appId");
            return;
        }

        var now = Date.now();

        if (usageData[appId]) {
            usageData[appId].count++;
            usageData[appId].lastUsed = now;
        } else {
            usageData[appId] = {
                count: 1,
                lastUsed: now
            };
        }

        usageData = usageData;

        saveUsageData();
    }

    function getUsageScore(appId) {
        if (!appId || !usageData[appId]) {
            return 0;
        }

        var data = usageData[appId];
        var now = Date.now();
        var daysSinceLastUse = (now - data.lastUsed) / dayInMs;

        var timeBoost = maxBoostScore * Math.exp(-daysSinceLastUse / 7);

        // Frequency score: logarithmic to prevent over-weighting
        var frequencyScore = Math.log(data.count + 1) * 20;

        return timeBoost + frequencyScore;
    }

    function getTopApps(limit) {
        if (!limit)
            limit = 10;

        var apps = [];
        for (var appId in usageData) {
            apps.push({
                appId: appId,
                score: getUsageScore(appId),
                count: usageData[appId].count,
                lastUsed: usageData[appId].lastUsed
            });
        }

        apps.sort(function (a, b) {
            return b.score - a.score;
        });

        return apps.slice(0, limit);
    }

    function pruneOldEntries() {
        var now = Date.now();
        var ninetyDaysInMs = dayInMs * 90;
        var changed = false;

        for (var appId in usageData) {
            if (now - usageData[appId].lastUsed > ninetyDaysInMs) {
                delete usageData[appId];
                changed = true;
            }
        }

        if (changed) {
            usageData = usageData;
            saveUsageData();
        }
    }
}
