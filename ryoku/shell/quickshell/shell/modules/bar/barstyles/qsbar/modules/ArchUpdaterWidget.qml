import QtQuick
import Quickshell
import Quickshell.Io
import "../IconMap.js" as IconMap

Item {
    id: rootMod
    required property var root

    property int updateCount: 0
    property int systemCount: 0
    property int aurCount: 0
    property bool refreshing: false
    property bool preferShell: false

    readonly property bool hasUpdates: rootMod.updateCount > 0
    readonly property bool badgePrefsLoaded: root._widgetsLoaded
    readonly property int packageBadgeCount: (rootMod.badgePrefsLoaded && root.archBadgePackages) ? Math.max(0, rootMod.updateCount) : 0
    readonly property int cleanThemeCount: {
        var n = 0, list = root.themeUpdList || []
        for (var i = 0; i < list.length; i++) {
            var t = list[i] || {}
            if (t.state === "clean" && t.behind > 0) n++
        }
        return n
    }
    readonly property bool hasThemeUpdates: rootMod.cleanThemeCount > 0
    readonly property int themeBadgeCount: (rootMod.badgePrefsLoaded && root.archBadgeThemes) ? Math.max(0, rootMod.cleanThemeCount) : 0
    readonly property bool hasShellUpdate: root.shellUpdateBehind > 0
        || root.shellUpdateProgressVisible
    readonly property int shellBadgeCount: (rootMod.badgePrefsLoaded && root.archBadgeShell && rootMod.hasShellUpdate) ? 1 : 0
    readonly property int badgeCount: rootMod.packageBadgeCount + rootMod.themeBadgeCount + rootMod.shellBadgeCount
    readonly property bool hasBadge: rootMod.badgeCount > 0
    readonly property bool hasNotice: rootMod.hasUpdates || rootMod.hasThemeUpdates
        || root.themeUpdLocalEdits > 0 || rootMod.hasShellUpdate

    implicitWidth: 26
    implicitHeight: 28

    Process {
        id: checkProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                rootMod.parseOutput(this.text)
                rootMod.refreshing = false
                refreshWatchdog.stop()
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0) rootMod.refreshing = false
            refreshWatchdog.stop()
        }
    }

    // safety: if the check ever hangs (AUR RPC stalls past the timeout), unstick
    // `refreshing` so future refreshes aren't blocked forever
    // checkupdates can sync a DB over the network + the 30s AUR timeout, so the
    // legitimate worst case is well past 45s. Kill the process (not just the flag)
    // so the state is unambiguous if it ever hangs.
    Timer {
        id: refreshWatchdog; interval: 130000
        onTriggered: { rootMod.refreshing = false; checkProc.running = false }
    }

    Timer {
        interval: 1800000; running: root.modStatus || root.archVisible; repeat: true; triggeredOnStart: true
        onTriggered: root.archRefreshTick++
    }

    property int extTrigger: root.archRefreshTick
    onExtTriggerChanged: {
        if (!rootMod.refreshing) rootMod.doRefresh()
    }

    function doRefresh() {
        // Ryoku-native: the bar reads the same seam the Hub and update island do
        // (`ryoku status --json`) — the channel commits behind plus, when
        // checkupdates is present, pending pacman packages. No qs-arch-* scripts.
        rootMod.refreshing = true
        refreshWatchdog.restart()
        checkProc.command = ["bash", "-c", "ryoku status --json 2>/dev/null"]
        checkProc.running = false
        checkProc.running = true
    }

    function parseOutput(text) {
        var updates = []
        var count = 0
        try {
            var d = JSON.parse(text.trim())
            var list = d.updates instanceof Array ? d.updates : []
            for (var i = 0; i < list.length; i++) {
                var u = list[i] || {}
                updates.push({name: u.name || "", oldVer: u.old || "", newVer: u.new || "", source: "system"})
            }
            count = (typeof d.pendingUpdates === "number") ? d.pendingUpdates : list.length
        } catch (e) {
            updates = []
            count = 0
        }
        // No per-package security gate in the Ryoku model: stamp the scan fresh so
        // the panel treats the list as current, and let `ryoku update` own applying.
        root.archScanId = ""
        root.archScanCheckedEpoch = Math.floor(Date.now() / 1000)
        root.archScanHash = ""
        root.archScanSystemCount = count
        rootMod.systemCount = count
        rootMod.aurCount = 0
        rootMod.updateCount = count
        root.archUpdates = updates
    }

    Item {
        anchors.centerIn: parent
        width: 20
        height: 20

        IconText {
            id: ic
            anchors.centerIn: parent
            text: rootMod.refreshing ? "\uE5D5" : IconMap.icon("package_2")
            color: rootMod.refreshing
                ? Qt.rgba(root.sumi.r, root.sumi.g, root.sumi.b, 1)
                : (rootMod.hasNotice ? root.seal : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.4))
            font.pixelSize: 14
        }

        Rectangle {
            visible: rootMod.hasBadge && !rootMod.refreshing
            anchors.verticalCenter: ic.verticalCenter
            anchors.verticalCenterOffset: -6
            anchors.horizontalCenter: ic.horizontalCenter
            anchors.horizontalCenterOffset: 7
            width: Math.max(12, badgeText.implicitWidth + 6)
            height: 12
            radius: 6
            color: root.seal

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: rootMod.badgeCount > 99 ? "99+" : String(rootMod.badgeCount)
                color: root.paper
                font.family: root.mono
                font.pixelSize: 7
                font.weight: Font.Bold
            }
        }
    }

    readonly property string tooltipText: {
        if (rootMod.refreshing) return ""
        var parts = []
        if (rootMod.systemCount) parts.push(rootMod.systemCount + " system")
        if (rootMod.aurCount) parts.push(rootMod.aurCount + " AUR")
        if (rootMod.cleanThemeCount > 0) parts.push(rootMod.cleanThemeCount + " themes")
        if (root.themeUpdLocalEdits > 0) parts.push(root.themeUpdLocalEdits + " review")
        if (root.shellProgressRunning) parts.push("shell updating")
        else if (root.shellProgressFailed || root.shellProgressInterrupted) parts.push("shell failed")
        else if (root.shellProgressCompleted) parts.push("shell done")
        else if (root.shellUpdateBehind > 0) parts.push("shell update")
        if (parts.length === 0) return "Up to date"
        return parts.join(" \u00B7 ") + "\nClick to view details"
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onEntered: { tip.show(); }
        onExited: { tip.hide(); }
        onClicked: (e) => {
            tip.hide();
            if (e.button === Qt.RightButton) {
                root.archRefreshTick++;
            } else {
                if (root.shellUpdateProgressVisible || rootMod.preferShell) {
                    root.showShellUpdateTabFromWidget()
                    return
                }
                if (root.shellUpdateBehind > 0
                        && !rootMod.hasUpdates
                        && !rootMod.hasThemeUpdates
                        && root.themeUpdLocalEdits <= 0) {
                    root.activeUpdateTab = "shell"
                }
                root.archVisible = true;
            }
        }
    }
}
