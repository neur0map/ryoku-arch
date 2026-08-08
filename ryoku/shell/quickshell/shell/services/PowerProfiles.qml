pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/menupoll.js" as MenuPoll

// QML view of the daemon `powerprofiles` topic. power-profiles-daemon lives in
// ryoku-shell (powerprofiles.go), so QML never shells out to powerprofilesctl:
// `subscribe powerprofiles` streams {active_profile, profiles} on every change,
// and `call powerprofiles.setProfile` sends the intent back. The list is
// service order with no client sort (contract 06 sec 2.9 / contract 11 sec 3.1).
Singleton {
    id: root

    // active profile name ("power-saver"/"balanced"/"performance"); the list in
    // service order; available when the daemon reports any profile.
    property string profile: ""
    property var profiles: []
    readonly property bool available: root.profiles.length > 0

    // active ownership is retained for the menu lifecycle (MenuPowerProfile
    // claims it on reveal); the topic streams regardless, so this now only
    // tracks owners for that contract.
    property bool active: false
    property var activeOwners: []
    function setActive(owner, enabled) {
        activeOwners = MenuPoll.setOwnership(activeOwners, owner, enabled);
        active = activeOwners.length > 0;
    }

    function setProfile(name) {
        if (typeof name !== "string" || !root.profiles.includes(name))
            return;
        root.call("powerprofiles.setProfile", { profile: name });
    }

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    function apply(line) {
        try {
            const f = JSON.parse(line);
            root.profile = typeof f.active_profile === "string" ? f.active_profile : "";
            root.profiles = Array.isArray(f.profiles) ? f.profiles : [];
        } catch (e) {
            // A malformed frame keeps the last good state.
        }
    }

    function call(method, args) {
        ctl.queued += "call " + method + " " + JSON.stringify(args) + "\n";
        if (ctl.connected)
            ctl.flushQueued();
        else
            ctl.connected = true;
    }

    Socket {
        id: sub
        path: root.sockPath
        parser: SplitParser { onRead: line => root.apply(line) }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe powerprofiles\n");
                flush();
            } else {
                root.profile = "";
                root.profiles = [];
                retry.restart();
            }
        }
    }

    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!sub.connected) sub.connected = true
    }

    Socket {
        id: ctl
        path: root.sockPath
        property string queued: ""

        function flushQueued() {
            if (queued.length === 0)
                return;
            write(queued);
            flush();
            queued = "";
        }

        onConnectionStateChanged: if (connected) flushQueued()
    }
}
