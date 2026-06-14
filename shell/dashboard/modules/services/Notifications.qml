pragma Singleton
pragma ComponentBehavior: Bound

// ─────────────────────────────────────────────────────────────────────────────
//  Ambxst — AGPL-3.0-or-later
//  Ryoku notification adapter, derived from Ambxst's notification service.
//  This file is licensed under the GNU Affero General Public License v3.0 or
//  later. See the upstream Ambxst project for the full license text.
// ─────────────────────────────────────────────────────────────────────────────
//
//  RYOKU BRIDGE
//  ------------
//  Quickshell only lets ONE process own the org.freedesktop.Notifications DBus
//  name, and ryoku already runs its own NotificationServer (qs.services →
//  Notifs). This singleton therefore does NOT register a NotificationServer.
//  Instead it is a passive ADAPTER: it reads ryoku's live `Notifs.list`
//  (list<NotifData>) and projects each entry into the Notif shape the
//  dashboard panel expects (string urgency, ms `time`, cached* fields, etc.).
//
//  Dismiss / action-invoke are forwarded to ryoku's own mechanism, mirrored from
//  shell/modules/sidebar/Notif* :
//    • dismiss  → NotifData.close()   (sets closed, drops from Notifs.list,
//                                       calls notification.dismiss(), destroys)
//    • action   → action.invoke()     (NotifData.actions[i].invoke closure)
//
//  Programmatic notifications created via notifyInternal() (e.g. Battery alerts)
//  are kept as a small LOCAL list and merged into `list`; they never touch DBus.
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.services

Singleton {
    id: root

    // Local, programmatically-created notifications (notifyInternal). These are
    // NOT system notifications and do not go through DBus.
    property var internalNotifs: []
    property int internalIdCounter: 1

    // Map a ryoku NotifData urgency int → the dashboard's string form.
    function urgencyToString(u) {
        if (u === NotificationUrgency.Critical)
            return "critical";
        if (u === NotificationUrgency.Low)
            return "low";
        return "normal";
    }

    // Project one ryoku NotifData into the dashboard Notif shape. Carries `_src` so
    // dismiss / action-invoke can reach back into the live NotifData object.
    function fromNotifData(n) {
        return {
            "id": n.id,
            "_src": n,
            "notification": n.notification,
            "actions": (n.actions ?? []).map(a => ({
                        "identifier": a.identifier,
                        "text": a.text,
                        "invoke": a.invoke
                    })),
            "popup": n.popup,
            "appIcon": n.appIcon ?? "",
            "appName": n.appName ?? "",
            "body": n.body ?? "",
            "image": n.image ?? "",
            "summary": n.summary ?? "",
            "time": n.time ? n.time.getTime() : Date.now(),
            "urgency": root.urgencyToString(n.urgency),
            "historyPriority": 0,
            "replaceKey": "",
            // The image-caching layer is a no-op in the bridge: ryoku already
            // resolves icon/image paths, so cached* mirror the live values.
            "isCached": false,
            "cachedImage": n.image ?? "",
            "cachedAppIcon": n.appIcon ?? "",
            "localActionHandlers": ({})
        };
    }

    // `list` is the union of ryoku's live notifications and any local internal
    // notifications, newest first. Everything downstream derives from this.
    property var list: {
        const live = Notifs.list.map(n => root.fromNotifData(n));
        const all = [...live, ...root.internalNotifs];
        all.sort((a, b) => b.time - a.time);
        return all;
    }

    property var popupList: list.filter(notif => notif.popup)

    // dnd bridge: the dashboard's `silent` ⇆ ryoku's Notifs.dnd.
    property bool silent: Notifs.dnd
    onSilentChanged: {
        if (Notifs.dnd !== silent)
            Notifs.dnd = silent;
    }

    property bool popupInhibited: silent

    property var latestTimeForApp: ({})

    onListChanged: {
        const map = {};
        root.list.forEach(notif => {
            if (!map[notif.appName] || notif.time > map[notif.appName])
                map[notif.appName] = notif.time;
        });
        root.latestTimeForApp = map;
    }

    function appNameListForGroups(groups) {
        return Object.keys(groups).sort((a, b) => {
            if (groups[b].historyPriority !== groups[a].historyPriority) {
                return groups[b].historyPriority - groups[a].historyPriority;
            }
            return groups[b].time - groups[a].time;
        });
    }

    function groupsForList(list) {
        const groups = {};
        list.forEach((notif, index) => {
            if (!notif || !notif.appName || (!notif.summary && !notif.body)) {
                return;
            }

            if (!groups[notif.appName]) {
                groups[notif.appName] = {
                    appName: notif.appName,
                    appIcon: notif.appIcon,
                    notifications: [],
                    time: 0,
                    historyPriority: 0,
                    totalCount: 0
                };
            }
            groups[notif.appName].notifications.push(notif);
            groups[notif.appName].totalCount++;
            groups[notif.appName].time = root.latestTimeForApp[notif.appName] || notif.time;
            groups[notif.appName].historyPriority = Math.max(groups[notif.appName].historyPriority || 0, notif.historyPriority || 0);
        });

        return groups;
    }

    property var groupsByAppName: groupsForList(root.list)
    property var popupGroupsByAppName: groupsForList(root.popupList)
    property var appNameList: appNameListForGroups(root.groupsByAppName)
    property var popupAppNameList: appNameListForGroups(root.popupGroupsByAppName)

    function notifyInternal(options) {
        if (!options || (!options.summary && !options.body)) {
            return null;
        }

        if (options.replaceKey) {
            root.internalNotifs = root.internalNotifs.filter(n => n.replaceKey !== options.replaceKey);
        }

        const notificationId = "ryoku-internal-" + (root.internalIdCounter++);
        const obj = {
            "id": notificationId,
            "_src": null,
            "notification": null,
            "actions": options.actions || [],
            "appIcon": options.appIcon || "",
            "appName": options.appName || "Ryoku",
            "body": options.body || "",
            "image": options.image || "",
            "summary": options.summary || "",
            "time": options.time || Date.now(),
            "urgency": typeof options.urgency === "number" ? root.urgencyToString(options.urgency) : (options.urgency || "normal"),
            "historyPriority": options.historyPriority || 0,
            "replaceKey": options.replaceKey || "",
            "isCached": false,
            "cachedImage": options.image || "",
            "cachedAppIcon": options.appIcon || "",
            "localActionHandlers": options.actionHandlers || {},
            "popup": !root.popupInhibited && options.popup !== false
        };

        root.internalNotifs = [...root.internalNotifs, obj];
        return obj;
    }

    function findNotif(id) {
        return root.list.find(notif => notif.id === id) ?? null;
    }

    function discardNotification(id) {
        const notif = root.findNotif(id);
        if (!notif)
            return;

        if (notif._src) {
            // Live ryoku notification: mirror shell/modules/sidebar/Notif.qml.
            notif._src.close();
        } else {
            root.internalNotifs = root.internalNotifs.filter(n => n.id !== id);
        }
    }

    function discardNotifications(ids) {
        if (!ids || ids.length === 0)
            return;
        ids.forEach(id => root.discardNotification(id));
    }

    function discardAllNotifications() {
        // Close every live ryoku notification, then clear local ones.
        const live = root.list.filter(n => n._src).map(n => n._src);
        live.forEach(src => src.close());
        root.internalNotifs = [];
    }

    function attemptInvokeAction(id, notifIdentifier, autoDiscard = true) {
        const notif = root.findNotif(id);
        if (notif) {
            const localHandlers = notif.localActionHandlers || {};
            const localHandler = localHandlers[notifIdentifier];
            if (typeof localHandler === "function") {
                localHandler(id);
            }

            // Live ryoku action: invoke the matching action closure, mirroring
            // shell/modules/sidebar/NotifActionList.qml (action.invoke()).
            const action = (notif.actions || []).find(a => a.identifier === notifIdentifier);
            if (action && typeof action.invoke === "function") {
                action.invoke();
            }
        }

        if (autoDiscard) {
            root.discardNotification(id);
        }
    }

    // ── Popup-timer surface ───────────────────────────────────────────────────
    // ryoku owns popup lifecycle (NotifData.timer / Notifs.shouldShowPopup), so
    // these become safe no-ops; the panel still calls them on hover etc.
    function pauseGroupTimers(appName) {}
    function resumeGroupTimers(appName) {}
    function pauseAllTimers() {}
    function resumeAllTimers() {}

    function hideAllPopups() {
        // Clear popup flags on local internal notifications; live popups are
        // governed by ryoku's own expire timers.
        let changed = false;
        const next = root.internalNotifs.map(n => {
            if (n.popup) {
                changed = true;
                return Object.assign({}, n, {
                    popup: false
                });
            }
            return n;
        });
        if (changed)
            root.internalNotifs = next;
    }
}
