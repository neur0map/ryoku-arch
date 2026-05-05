pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models

// Taskbar embedded in the bar — reuses dock app model and logic
// but renders with bar-appropriate sizing and style.
// Supports horizontal (top/bottom bar) and vertical (left/right bar) orientations.
Item {
    id: root

    property var parentWindow: null
    property bool vertical: false
    // Bar position: "top", "bottom", "left", "right"
    property string barPosition: {
        if (vertical) return (Config.options?.bar?.bottom ?? false) ? "right" : "left"
        return (Config.options?.bar?.bottom ?? false) ? "bottom" : "top"
    }
    // Maximum height for vertical mode (-1 = no limit, 0+ = cap)
    property real maximumHeight: -1

    readonly property real barSize: vertical ? Appearance.sizes.baseVerticalBarWidth : Appearance.sizes.baseBarHeight
    property real iconSize: vertical ? Math.round(barSize * 0.58) : Math.round(barSize * 0.68)

    readonly property bool isOverflowing: vertical && maximumHeight > 0 && listView.contentHeight > (maximumHeight - 8)

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical
    implicitWidth: vertical ? barSize : (listView.contentWidth + 8)
    implicitHeight: vertical
        ? (maximumHeight > 0 ? Math.min(listView.contentHeight + 8, maximumHeight) : (listView.contentHeight + 8))
        : barSize

    // ─── Dock Items Model (mirrored from DockApps logic) ─────────────
    property var dockItems: []

    readonly property bool separatePinnedFromRunning: Config.options?.dock?.separatePinnedFromRunning ?? true
    onSeparatePinnedFromRunningChanged: rebuildDockItems()

    property var _cachedIgnoredRegexes: []
    property var _lastIgnoredRegexStrings: []

    function _getIgnoredRegexes(): list<var> {
        const ignoredRegexStrings = Config.options?.dock?.ignoredAppRegexes ?? [];
        if (JSON.stringify(ignoredRegexStrings) !== JSON.stringify(_lastIgnoredRegexStrings)) {
            const systemIgnored = ["^$", "^portal$", "^x-run-dialog$", "^kdialog$", "^org.freedesktop.impl.portal.*"];
            const allIgnored = ignoredRegexStrings.concat(systemIgnored);
            _cachedIgnoredRegexes = allIgnored.map(pattern => new RegExp(pattern, "i"));
            _lastIgnoredRegexStrings = ignoredRegexStrings.slice();
        }
        return _cachedIgnoredRegexes;
    }

    Timer {
        id: rebuildTimer
        interval: 80
        repeat: false
        onTriggered: root._doRebuildDockItems()
    }

    function rebuildDockItems(): void {
        rebuildTimer.restart()
    }

    function _dockItemsEqual(oldItems: var, newItems: var): bool {
        if (oldItems.length !== newItems.length) return false
        for (let i = 0; i < oldItems.length; i++) {
            const o = oldItems[i], n = newItems[i]
            if (o.uniqueId !== n.uniqueId || o.pinned !== n.pinned || o.section !== n.section) return false
            const oTL = o.toplevels, nTL = n.toplevels
            if (oTL.length !== nTL.length) return false
            for (let j = 0; j < oTL.length; j++) {
                if (oTL[j] !== nTL[j]) return false
            }
        }
        return true
    }

    function _doRebuildDockItems(): void {
        const pinnedApps = Config.options?.dock?.pinnedApps ?? [];
        const ignoredRegexes = _getIgnoredRegexes();
        const separate = root.separatePinnedFromRunning;

        const allToplevels = CompositorService.sortedToplevels && CompositorService.sortedToplevels.length
                ? CompositorService.sortedToplevels
                : ToplevelManager.toplevels.values;

        const runningAppsMap = new Map();
        for (const toplevel of allToplevels) {
            if (!toplevel.appId || toplevel.appId === "" || toplevel.appId === "null") continue;
            if (ignoredRegexes.some(re => re.test(toplevel.appId))) continue;

            const lowerAppId = toplevel.appId.toLowerCase();
            if (!runningAppsMap.has(lowerAppId)) {
                runningAppsMap.set(lowerAppId, {
                    appId: toplevel.appId,
                    toplevels: [],
                    pinned: false
                });
            }
            runningAppsMap.get(lowerAppId).toplevels.push(toplevel);
        }

        const values = [];
        let order = 0;

        if (!separate) {
            for (const appId of pinnedApps) {
                const lowerAppId = appId.toLowerCase();
                const runningEntry = runningAppsMap.get(lowerAppId);
                // Skip pinned apps with no desktop entry and no running windows
                if (!runningEntry && !AppSearch.lookupDesktopEntry(appId))
                    continue;
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: runningEntry?.toplevels ?? [],
                    pinned: true,
                    originalAppId: appId,
                    section: "pinned",
                    order: order++
                });
                runningAppsMap.delete(lowerAppId);
            }

            if (values.length > 0 && runningAppsMap.size > 0) {
                values.push({
                    uniqueId: "separator",
                    appId: "SEPARATOR",
                    toplevels: [],
                    pinned: false,
                    originalAppId: "SEPARATOR",
                    section: "separator",
                    order: order++
                });
            }

            for (const [lowerAppId, entry] of runningAppsMap) {
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: entry.toplevels,
                    pinned: false,
                    originalAppId: entry.appId,
                    section: "open",
                    order: order++
                });
            }
        } else {
            for (const appId of pinnedApps) {
                const lowerAppId = appId.toLowerCase();
                if (!runningAppsMap.has(lowerAppId)) {
                    // Skip pinned apps with no desktop entry
                    if (!AppSearch.lookupDesktopEntry(appId))
                        continue;
                    values.push({
                        uniqueId: "app-" + lowerAppId,
                        appId: lowerAppId,
                        toplevels: [],
                        pinned: true,
                        originalAppId: appId,
                        section: "pinned",
                        order: order++
                    });
                }
            }

            const hasPinnedOnly = values.length > 0;
            const hasRunning = runningAppsMap.size > 0;
            if (hasPinnedOnly && hasRunning) {
                values.push({
                    uniqueId: "separator",
                    appId: "SEPARATOR",
                    toplevels: [],
                    pinned: false,
                    originalAppId: "SEPARATOR",
                    section: "separator",
                    order: order++
                });
            }

            const sortedRunningApps = [];
            for (const [lowerAppId, entry] of runningAppsMap) {
                sortedRunningApps.push({ lowerAppId, entry });
            }
            sortedRunningApps.sort((a, b) => {
                const aIndex = pinnedApps.findIndex(p => p.toLowerCase() === a.lowerAppId);
                const bIndex = pinnedApps.findIndex(p => p.toLowerCase() === b.lowerAppId);
                const aIsPinned = aIndex !== -1;
                const bIsPinned = bIndex !== -1;
                if (aIsPinned && bIsPinned) return aIndex - bIndex;
                if (aIsPinned) return -1;
                if (bIsPinned) return 1;
                return 0;
            });

            for (const {lowerAppId, entry} of sortedRunningApps) {
                values.push({
                    uniqueId: "app-" + lowerAppId,
                    appId: lowerAppId,
                    toplevels: entry.toplevels,
                    pinned: pinnedApps.some(p => p.toLowerCase() === lowerAppId),
                    originalAppId: entry.appId,
                    section: "running",
                    order: order++
                });
            }
        }

        if (!_dockItemsEqual(dockItems, values)) {
            dockItems = values
        }
    }

    Connections {
        target: ToplevelManager.toplevels
        function onValuesChanged() { root.rebuildDockItems() }
    }
    Connections {
        target: CompositorService
        function onSortedToplevelsChanged() { root.rebuildDockItems() }
    }
    Connections {
        target: Config.options?.dock
        function onPinnedAppsChanged() { root.rebuildDockItems() }
        function onIgnoredAppRegexesChanged() { root.rebuildDockItems() }
    }
    Component.onCompleted: rebuildDockItems()

    // ─── Hover preview state ────────────────────────────────────────
    property Item lastHoveredButton
    property bool buttonHovered: false
    property bool contextMenuOpen: false

    signal closeAllContextMenus()

    function showPreviewPopup(appEntry: var, button: Item): void {
        if (Config.options?.dock?.hoverPreview === false) return
        previewPopup.show(appEntry, button)
    }

    // ─── ListView ───────────────────────────────────────────────────
    StyledListView {
        id: listView
        spacing: 2
        orientation: root.vertical ? ListView.Vertical : ListView.Horizontal
        // Horizontal: align left (next to sidebar button). Vertical: center horizontally, top-align.
        anchors.left: root.vertical ? undefined : parent.left
        anchors.top: root.vertical ? parent.top : undefined
        anchors.horizontalCenter: root.vertical ? parent.horizontalCenter : undefined
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        implicitWidth: root.vertical ? root.barSize : contentWidth
        implicitHeight: root.vertical ? contentHeight : root.barSize
        width: root.vertical ? root.barSize : contentWidth
        height: root.vertical
            ? (root.maximumHeight > 0 ? Math.min(contentHeight, root.maximumHeight - 8) : contentHeight)
            : root.barSize
        interactive: false
        clip: root.isOverflowing
        boundsBehavior: Flickable.StopAtBounds

        // Mouse wheel scroll when overflowing
        WheelHandler {
            enabled: root.isOverflowing
            onWheel: event => {
                const step = event.angleDelta.y * 0.6
                listView.contentY = Math.max(0,
                    Math.min(listView.contentHeight - listView.height,
                        listView.contentY - step))
            }
        }

        Behavior on implicitWidth {
            enabled: !root.vertical && Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        Behavior on implicitHeight {
            enabled: root.vertical && Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }

        model: ScriptModel {
            objectProp: "uniqueId"
            values: root.dockItems
        }

        delegate: BarTaskbarButton {
            id: taskbarDelegate
            required property var modelData
            required property int index
            appEntry: modelData
            taskbarRoot: root
            iconSize: root.iconSize
            vertical: root.vertical
            barPosition: root.barPosition
        }
    }

    // ─── Preview popup (PopupWindow anchored to bar) ────────────────
    BarTaskbarPreview {
        id: previewPopup
        dockHovered: root.buttonHovered
        barPosition: root.barPosition
        anchor.window: root.parentWindow
    }
}
