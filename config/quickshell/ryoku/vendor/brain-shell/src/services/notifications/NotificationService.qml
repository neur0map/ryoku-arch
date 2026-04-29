pragma Singleton
import QtQuick
import Quickshell.Services.Notifications
import "../../"

// ─────────────────────────────────────────────────────────────
// NotificationService — global singleton
// ─────────────────────────────────────────────────────────────
NotificationServer {
    id: root

    bodyMarkupSupported:   true
    bodySupported:     true
    actionsSupported:      true
    keepOnReload: true
    
    signal notificationAdded(var notification)
    
    
    property var list: []

    readonly property int count: list.length
    
    onNotification: function(n) {
        n.tracked = true
        root.list = [n, ...root.list]
        if(ShellState.dnd) return
        root.notificationAdded(n)
         n.onClosed.connect(function() {
            root.list = root.list.filter(function(x) { return x !== n })
        })
    }


    function dismissAll() {
        if (!root.list) return
        const list = [...root.list]
        for (const n of list) n.dismiss()
    }
}
