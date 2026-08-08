pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// QML view of the daemon `polkit` topic. The daemon is the PolicyKit1
// authentication agent: it takes BeginAuthentication from polkitd, runs the PAM
// conversation through polkit-agent-helper-1, and streams the live prompt here.
// This only renders and collects input, so the secret never becomes a process
// argument and the D-Bus and PAM plumbing stays in the daemon.
//
// `prompt` is PAM's own text ("Password: ", or a fingerprint nudge), `echo` says
// whether it may be shown as typed, and `error` carries a failed attempt so the
// island can retry in place rather than closing and reopening.
Singleton {
    id: root

    property bool active: false
    property string message: ""     // the action's description, from polkitd
    property string info: ""        // PAM_TEXT_INFO
    property string error: ""       // PAM_ERROR_MSG, e.g. a wrong password
    property string prompt: ""      // PAM_PROMPT_ECHO_OFF/ON text
    property bool echo: false       // true when the answer may be shown
    property bool busy: false       // an answer is with PAM, awaiting the verdict

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    // Fired whenever a fresh frame arrives, so the surface clears the field and
    // takes focus again on a retry without the island closing in between.
    signal refreshed()

    function apply(line) {
        try {
            const f = JSON.parse(line);
            const wasActive = root.active;
            const hadError = root.error;
            root.active = f.active === true;
            root.message = f.message || "";
            root.info = f.info || "";
            root.error = f.error || "";
            root.prompt = f.prompt || "";
            root.echo = f.echo === true;
            // A new prompt (or a new error on a retry) means PAM answered; drop
            // the busy state so the field is live again.
            if (!root.active || !wasActive || root.error !== hadError)
                root.busy = false;
            if (root.active)
                root.refreshed();
        } catch (e) {
            // A malformed frame must never wedge the island open over the desktop.
            root.active = false;
            root.busy = false;
        }
    }

    function submit(secret) {
        if (!root.active || root.busy)
            return;
        root.busy = true;
        root.send("polkit.submit", { password: secret });
    }

    function cancel() {
        if (!root.active)
            return;
        root.busy = false;
        root.send("polkit.cancel", {});
    }

    function send(method, args) {
        ctl.queued += "call " + method + " " + JSON.stringify(args) + "\n";
        if (ctl.connected)
            ctl.flushQueued();
        else
            ctl.connected = true;
    }

    // Subscription: connect, ask once, then stream. A second write to this
    // connection would half-close the stream (daemon rule), so calls use ctl.
    Socket {
        id: sub
        path: root.sockPath
        parser: SplitParser { onRead: line => root.apply(line) }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe polkit\n");
                flush();
            } else {
                root.active = false;
                root.busy = false;
                retry.restart();
            }
        }
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

    // The daemon may be down when the shell loads, or restart under it; retry
    // quietly so an authentication prompt still lands once it returns.
    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!sub.connected) sub.connected = true
    }
}
