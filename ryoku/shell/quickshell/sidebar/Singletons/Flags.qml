pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Shared session flags persisted to a small JSON file and watched for external
 * change, so every Ryoku daemon (pill, sidebar) reads and writes the same
 * Do-Not-Disturb and Keep-Awake state live without a second notification server
 * or idle inhibitor. Toggling in one surface updates the others on the next file
 * event, and the state survives a daemon restart. keepAwakeSince is the epoch
 * millisecond Keep-Awake was last enabled (0 when off), so every surface reads
 * the same "how long" elapsed time.
 */
Singleton {
    id: root

    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake
    property alias keepAwakeSince: adapter.keepAwakeSince

    // Stamp the start time when Keep-Awake turns on and clear it when off, so no
    // toggle site has to track it. Guarded so a file reload (where the stamp is
    // already set) never resets the running clock.
    onKeepAwakeChanged: {
        if (keepAwake && !adapter.keepAwakeSince)
            adapter.keepAwakeSince = Date.now();
        else if (!keepAwake)
            adapter.keepAwakeSince = 0;
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        // Atomic writes (temp + rename) so a SIGTERM during a shell refresh, or
        // the pill and sidebar singletons writing at once, can never leave a torn
        // half-written file that fails to parse on the next load — which would
        // silently drop persisted Keep-Awake back to the default off.
        atomicWrites: true

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter
            property bool dnd: false
            property bool keepAwake: false
            property real keepAwakeSince: 0
        }
    }

    // Seed the file only on a genuine first run (no content to load). Guard on
    // the loaded text, not file.loaded, so a slow or failed load never overwrites
    // a present file from defaults and wipes Keep-Awake across a refresh.
    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
