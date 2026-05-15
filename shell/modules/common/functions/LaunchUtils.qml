pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell

Singleton {
    id: root

    // Launch a Quickshell DesktopEntry, correctly honoring Terminal=true.
    // Quickshell's DesktopEntry.execute() runs the binary without a PTY, so
    // entries like nvim/btop/htop/nvtop/wiremix fail silently when invoked
    // that way. gtk-launch parses the .desktop file itself and spawns a
    // terminal when Terminal=true; we fall back to a manual terminal wrap if
    // the entry has no usable id (rare for system-installed apps).
    function launchDesktopEntry(entry) {
        if (!entry) return false
        const rawId = String(entry.id ?? "").trim()
        const id = rawId.replace(/\.desktop$/i, "")
        if (id.length > 0) {
            Quickshell.execDetached(["/usr/bin/gtk-launch", id])
            return true
        }
        if (entry.runInTerminal) {
            const terminal = Config.options?.apps?.terminal ?? "/usr/bin/kitty"
            const cmd = (entry.command ?? []).join(" ")
            Quickshell.execDetached(["/usr/bin/bash", "-c", `${terminal} -e '${cmd}'`])
            return true
        }
        entry.execute()
        return true
    }

    // Launch by desktop id (without the .desktop suffix). Same gtk-launch
    // path, no DesktopEntry object required. Useful for taskbar/dock click
    // handlers where only an appId is in hand.
    function launchByDesktopId(desktopId) {
        const id = String(desktopId ?? "").trim().replace(/\.desktop$/i, "")
        if (id.length === 0) return false
        Quickshell.execDetached(["/usr/bin/gtk-launch", id])
        return true
    }
}
