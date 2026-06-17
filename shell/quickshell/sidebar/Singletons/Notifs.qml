pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
    property var seenIds: ({})
    property var arrivalMs: ({})
    property var popups: []
    property int tick: 0
    property var collapsedApps: ({})
    property var history: []
    property var userDismissed: ({})
    property var expireAt: ({})

    readonly property var tracked: server.trackedNotifications.values
    readonly property int count: tracked.length + history.length

    readonly property int unread: {
        var u = 0;
        for (var i = 0; i < tracked.length; i++)
            if (!seenIds[tracked[i].id]) u++;
        return u;
    }

    readonly property var groups: {
        var map = {};
        var order = [];
        function add(app, item) {
            if (map[app] === undefined) { map[app] = []; order.push(app); }
            map[app].push(item);
        }
        for (var i = tracked.length - 1; i >= 0; i--) {
            var n = tracked[i];
            add((n.appName && n.appName.length) ? n.appName : "System", { live: true, n: n });
        }
        for (var j = 0; j < history.length; j++)
            add(history[j].app, { live: false, n: history[j] });
        return order.map(function(a) { return { app: a, items: map[a] }; });
    }

    function dismissNotif(n) {
        var d = userDismissed;
        d[n.id] = true;
        root.userDismissed = d;
        n.dismiss();
    }

    function removeHistory(id) {
        root.history = root.history.filter(function(h) { return h.id !== id; });
    }

    function markAllSeen() {
        var m = {};
        for (var i = 0; i < tracked.length; i++) m[tracked[i].id] = true;
        root.seenIds = m;
    }

    function clearAll() {
        var l = tracked.slice();
        var d = userDismissed;
        for (var i = 0; i < l.length; i++) d[l[i].id] = true;
        root.userDismissed = d;
        for (var j = 0; j < l.length; j++) l[j].dismiss();
        root.history = [];
        root.popups = [];
    }

    function removePopup(n) {
        root.popups = root.popups.filter(function(p) { return p !== n; });
    }

    function toggleCollapsed(app) {
        var c = collapsedApps;
        c[app] = !c[app];
        root.collapsedApps = c;
    }

    function ageLabel(n) {
        void root.tick;
        var t = arrivalMs[n.id];
        if (!t) return "";
        var m = Math.floor((Date.now() - t) / 60000);
        if (m < 1) return "now";
        if (m < 60) return m + "m";
        return Math.floor(m / 60) + "h";
    }

    function progressOf(n) {
        var h = n.hints || {};
        if (h["value"] === undefined) return -1;
        return Math.max(0, Math.min(100, Number(h["value"])));
    }

    Timer {
        interval: 30000
        running: root.count > 0
        repeat: true
        onTriggered: root.tick++
    }

    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: function(n) {
            n.tracked = true;
            var a = root.arrivalMs;
            a[n.id] = Date.now();
            root.arrivalMs = a;
            var e = root.expireAt;
            e[n.id] = Date.now() + (n.urgency === NotificationUrgency.Low ? 4000 : 6000);
            root.expireAt = e;
            n.closed.connect(function(reason) {
                if (!root.userDismissed[n.id])
                    root.history = [{
                        app: (n.appName && n.appName.length) ? n.appName : "System",
                        summary: n.summary,
                        body: n.body,
                        appIcon: n.appIcon,
                        image: n.image,
                        urgency: n.urgency,
                        id: "h" + n.id + "-" + Date.now()
                    }].concat(root.history).slice(0, 50);
                else {
                    var du = root.userDismissed;
                    delete du[n.id];
                    root.userDismissed = du;
                }
                root.removePopup(n);
                var b = root.arrivalMs;
                delete b[n.id];
                root.arrivalMs = b;
                var c = root.expireAt;
                delete c[n.id];
                root.expireAt = c;
            });
            var critical = n.urgency === NotificationUrgency.Critical;
            if (!root.dnd || critical)
                root.popups = root.popups.concat([n]).slice(-3);
        }
    }
}
