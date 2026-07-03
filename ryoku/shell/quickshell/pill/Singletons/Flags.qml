pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// session flags in a little JSON file, watched for outside changes so every
// daemon (pill, launcher) shares one DND / Keep-Awake / Game-Mode state. no
// extra notif server or idle inhibitor. flip in one surface, the rest catch
// up on the next file event, and it survives a daemon restart.
// keepAwakeSince = epoch ms Keep-Awake last turned on (0 when off), so every
// surface reads the same "how long" elapsed.
Singleton {
    id: root

    property alias dnd: adapter.dnd
    property alias keepAwake: adapter.keepAwake
    property alias keepAwakeSince: adapter.keepAwakeSince
    property alias gameMode: adapter.gameMode

    // stamp when Keep-Awake turns on, clear when off, so no toggle site has
    // to track it. guarded so a file reload (stamp already set) doesn't
    // reset the running clock.
    onKeepAwakeChanged: {
        if (keepAwake && !adapter.keepAwakeSince)
            adapter.keepAwakeSince = Date.now();
        else if (!keepAwake)
            adapter.keepAwakeSince = 0;
    }

    // game mode pulls DND on so notifs can't break a fullscreen game's
    // tearing / direct scanout, and restores the prior DND on exit, so
    // users who keep DND on independently of gaming aren't clobbered.
    onGameModeChanged: {
        if (gameMode) {
            adapter.gameDndPrev = dnd;
            dnd = true;
        } else {
            dnd = adapter.gameDndPrev;
        }
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/flags.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        // atomic writes (temp + rename): a SIGTERM during a shell refresh, or
        // two surfaces writing at once, can't leave a half-written file that
        // fails parse on next load and silently drops Keep-Awake back to off.
        atomicWrites: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter
            property bool dnd: false
            property bool keepAwake: false
            property real keepAwakeSince: 0
            property bool gameMode: false
            property bool gameDndPrev: false
        }
    }

    // seed only on a real first run (no content yet). guard on the loaded
    // text, not file.loaded, so a slow/failed load never overwrites a present
    // file from defaults and wipes Keep-Awake across a refresh.
    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
