pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Fires the session power actions the confirmation dialog confirms. The daemon
// (session.go) runs the documented systemctl command; QML never spawns systemctl
// itself, keeping the shell's state-in-daemon / render-in-QML split. Calls are
// fire-and-forget: reboot and shutdown tear the session down, so no reply is
// awaited. Contract 13 sec 8.
Singleton {
    id: root

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    // action is one of "logout" | "reboot" | "shutdown"; the daemon validates it.
    function run(action) {
        ctl.queued += "call session." + action + " {}\n";
        if (ctl.connected)
            ctl.flushQueued();
        else
            ctl.connected = true;
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
