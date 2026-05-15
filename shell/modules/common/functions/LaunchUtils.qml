pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell

Singleton {
    id: root

    function shellQuote(value) {
        const text = String(value ?? "")
        return "'" + text.replace(/'/g, "'\\''") + "'"
    }

    function normalizeDesktopId(desktopId) {
        let id = String(desktopId ?? "").trim().replace(/\.desktop$/i, "")
        if (id === "spotify" || id === "spotify-launcher") return "spotify-launcher"
        if (id === "com.github.th_ch.youtube_music") {
            if (DesktopEntries.heuristicLookup("pear-desktop")) return "pear-desktop"
            return "youtube-music"
        }
        return id
    }

    // Launch a Quickshell DesktopEntry, correctly honoring Terminal=true.
    // Quickshell's DesktopEntry.execute() runs the binary without a PTY, so
    // entries like nvim/btop/htop/nvtop/wiremix fail silently when invoked
    // that way. gtk-launch parses the .desktop file itself and spawns a
    // terminal when Terminal=true; we fall back to a manual terminal wrap if
    // the entry has no usable id (rare for system-installed apps).
    function launchDesktopEntry(entry) {
        if (!entry) return false
        const rawId = String(entry.id ?? "").trim()
        const id = root.normalizeDesktopId(rawId)
        if (id.length > 0) {
            return root.launchByDesktopId(id)
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
    // path, no DesktopEntry object required. If the desktop id lookup fails,
    // keep the old behavior of trying the id as a command.
    function launchByDesktopId(desktopId) {
        const id = root.normalizeDesktopId(desktopId)
        if (id.length === 0) return false
        const quotedId = root.shellQuote(id)
        Quickshell.execDetached(["/usr/bin/bash", "-lc", `/usr/bin/gtk-launch ${quotedId} || ${quotedId}`])
        return true
    }
}
