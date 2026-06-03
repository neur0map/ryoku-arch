pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Ryoku Notifications: projects Ryoku's Notifs/NotifData into the grouped
// notification API (groupsByAppName + per-app groups of projected notification
// objects).
Singleton {
    id: root

    function _urgencyStr(u) {
        return u === 2 ? "critical" : u === 0 ? "low" : "normal";
    }

    function _project(n) {
        return {
            "notificationId": n.id,
            "summary": n.summary,
            "body": n.body,
            "appName": n.appName,
            "appIcon": n.appIcon,
            "image": n.image,
            "time": n.time ? n.time.getTime() : 0,
            "urgency": root._urgencyStr(n.urgency),
            "actions": (n.actions ?? []).map(a => ({
                "identifier": a.identifier,
                "text": a.text
            })),
            "_src": n
        };
    }

    function _groups(srcList) {
        const byApp = {};
        for (let i = 0; i < srcList.length; i++) {
            const n = srcList[i];
            const proj = root._project(n);
            if (!byApp[n.appName])
                byApp[n.appName] = {
                    "appName": n.appName,
                    "time": proj.time,
                    "notifications": []
                };
            byApp[n.appName].notifications.push(proj);
            if (proj.time > byApp[n.appName].time)
                byApp[n.appName].time = proj.time;
        }
        return byApp;
    }

    function _keysByTime(groups) {
        return Object.keys(groups).sort((a, b) => groups[b].time - groups[a].time);
    }

    readonly property var list: Notifs.list.map(n => root._project(n))
    readonly property var groupsByAppName: root._groups(Notifs.list)
    readonly property var popupGroupsByAppName: root._groups(Notifs.popups)
    readonly property var appNameList: root._keysByTime(root.groupsByAppName)
    readonly property var popupAppNameList: root._keysByTime(root.popupGroupsByAppName)
    readonly property int unread: 0

    property bool silent: false
    Component.onCompleted: root.silent = Notifs.dnd
    Connections {
        target: Notifs
        function onDndChanged() {
            if (root.silent !== Notifs.dnd)
                root.silent = Notifs.dnd;
        }
    }
    onSilentChanged: if (Notifs.dnd !== root.silent)
        Notifs.dnd = root.silent

    function ensureInitialized() {}
    function markAllRead() {}

    function discardAllNotifications() {
        const all = Notifs.list.slice();
        for (let i = 0; i < all.length; i++)
            all[i].close();
    }

    function discardNotification(id) {
        const n = Notifs.list.find(x => x.id === id);
        if (n)
            n.close();
    }

    function attemptInvokeAction(id, actionId) {
        const n = Notifs.list.find(x => x.id === id);
        if (!n)
            return;
        const a = (n.actions ?? []).find(x => x.identifier === actionId);
        if (a && a.invoke)
            a.invoke();
    }

    function cancelTimeout(id) {}
}
