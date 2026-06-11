import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Internal
import Ryoku.Config

Scope {
    id: root

    readonly property string lockCommand: 'if [ -x "$HOME/.local/share/quickshell-lockscreen/lock.sh" ]; then exec env -u QS_CONFIG_NAME -u QS_CONFIG_PATH -u QS_MANIFEST "$HOME/.local/share/quickshell-lockscreen/lock.sh"; else exec loginctl lock-session; fi'
    readonly property bool locked: lockProcess.running || lockRequested

    property bool lockRequested

    function lock(): string {
        if (lockProcess.running)
            return "running";

        lockRequested = true;
        lockProcess.running = true;
        return "locking";
    }

    function unlock(): string {
        Quickshell.execDetached(["loginctl", "unlock-session"]);
        lockRequested = false;
        return "unlocking";
    }

    function isLocked(): string {
        return locked ? "locked" : "unlocked";
    }

    IpcHandler {
        function lock(): string {
            return root.lock();
        }

        function unlock(): string {
            return root.unlock();
        }

        function isLocked(): string {
            return root.isLocked();
        }

        target: "lock"
    }

    Process {
        id: lockProcess

        command: ["sh", "-c", root.lockCommand]
        onExited: {
            root.lockRequested = false;
        }
    }

    // Bridge logind session Lock/Unlock and pre-sleep locking to qylock. This
    // replaces hypridle's lock_cmd + before_sleep_cmd: `loginctl lock-session`
    // (idle-timeout, manual, or any client) now renders the lockscreen, and the
    // session locks before suspend when configured. LogindManager (Ryoku.Internal)
    // watches org.freedesktop.login1 Session Lock/Unlock + Manager PrepareForSleep.
    LogindManager {
        onLockRequested: root.lock()
        onUnlockRequested: root.unlock()
        onAboutToSleep: if (GlobalConfig.general.idle.lockBeforeSleep) root.lock()
    }
}
