pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live state for the keyring island, driven by the ryoku-shell daemon's GNOME
 * keyring system prompter. When gnome-keyring needs a password (unlocking the
 * login keyring, or choosing one for a fresh "Default" keyring the first time an
 * app stores a secret) the daemon pushes the prompt here via `keyringPrompt` and
 * the pill grows the KeyringSurface island instead of gcr drawing a centred GTK
 * dialog.
 *
 * The typed secret goes back over the daemon's control socket on its own line,
 * never as a process argument, so it cannot leak through the world-readable
 * /proc/<pid>/cmdline. The daemon owns the secret exchange and encrypts it before
 * it touches the bus.
 */
Singleton {
    id: root

    property bool active: false
    property bool busy: false          // a submitted answer is resolving
    property int promptId: -1
    property string mon: ""
    property string promptType: "password"   // "password" | "confirm"
    property string title: ""
    property string message: ""
    property string description: ""
    property string warning: ""
    property string choiceLabel: ""
    property bool choiceChosen: false
    property bool passwordNew: false         // choosing a new password (confirm field)
    property string continueLabel: ""
    property string cancelLabel: ""

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"

    // Fired when a fresh prompt arrives so the surface resets its fields and
    // takes focus, even when the island is already open (a wrong-password retry).
    signal opened()

    function apply(payload) {
        try {
            var o = JSON.parse(payload);
            root.promptId = o.id !== undefined ? o.id : -1;
            root.mon = o.mon || "";
            root.promptType = o.type || "password";
            root.title = o.title || "";
            root.message = o.message || "";
            root.description = o.description || "";
            root.warning = o.warning || "";
            root.choiceLabel = o.choiceLabel || "";
            root.choiceChosen = !!o.choiceChosen;
            root.passwordNew = !!o.passwordNew;
            root.continueLabel = o.continueLabel || "";
            root.cancelLabel = o.cancelLabel || "";
            root.busy = false;
            root.active = true;
            root.opened();
        } catch (e) {
            // A malformed payload should never wedge the island open.
            root.clear();
        }
    }

    function clear() {
        root.active = false;
        root.busy = false;
        root.promptId = -1;
        root.warning = "";
    }

    // Submit the typed secret (continue). The island stays up in a busy state
    // until the daemon either hides it (success/abort) or re-prompts (retry).
    function submit(secret, choice) {
        if (root.promptId < 0 || root.busy)
            return;
        root.busy = true;
        respond("continue", secret, choice);
    }

    // User dismissal (Escape, backdrop, Cancel). Only meaningful while a prompt
    // is live and not already resolving.
    function dismiss() {
        if (root.active && !root.busy)
            cancel();
    }

    function cancel() {
        if (root.promptId < 0)
            return;
        respond("cancel", "", false);
        root.clear();
    }

    function respond(action, secret, choice) {
        var head = "keyring-respond " + root.promptId + " " + action + " " + (choice ? "1" : "0") + "\n";
        sock.queued = head + secret + "\n";
        if (sock.connected) {
            sock.flushQueued();
        } else {
            sock.connected = true;
        }
    }

    Socket {
        id: sock
        path: root.sockPath
        property string queued: ""

        function flushQueued() {
            if (queued.length === 0)
                return;
            write(queued);
            flush();
            queued = "";
            // The daemon reads the command + secret and closes the connection
            // itself; disconnecting here races the write and would truncate the
            // secret's second line.
        }

        onConnectionStateChanged: if (connected) flushQueued()
    }
}
