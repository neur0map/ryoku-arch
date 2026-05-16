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
    // that way. For Terminal=true entries we run the parsed argv inside the
    // user's configured terminal directly, because gtk-launch's own terminal
    // detection only knows gnome-terminal/xterm/dtterm/nxterm + an optional
    // xdg-terminal-exec helper that ryoku doesn't ship — verified to spawn
    // nothing on a clean install. For everything else we prefer gtk-launch
    // (handles Exec field codes, OnlyShowIn, etc.).
    function launchDesktopEntry(entry) {
        if (!entry) return false
        if (entry.runInTerminal) {
            const terminal = Config.options?.apps?.terminal ?? "kitty"
            const cmdArgv = entry.command ?? []
            if (cmdArgv.length > 0) {
                Quickshell.execDetached([terminal, "-e"].concat(cmdArgv))
                return true
            }
        }
        const id = root.normalizeDesktopId(String(entry.id ?? "").trim())
        if (id.length > 0) return root.launchByDesktopId(id)
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
