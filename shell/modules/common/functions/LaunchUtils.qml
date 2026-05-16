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

    function lookupDesktopEntry(desktopId) {
        const id = root.normalizeDesktopId(desktopId)
        if (id.length === 0) return null
        return DesktopEntries.byId(id)
            ?? DesktopEntries.byId(id + ".desktop")
            ?? DesktopEntries.heuristicLookup(id)
    }

    // Launch a Quickshell DesktopEntry, correctly honoring Terminal=true.
    // Quickshell's DesktopEntry.execute() runs the binary without a PTY, so
    // entries like nvim/btop/htop/nvtop/wiremix fail silently when invoked
    // that way. For Terminal=true entries we run the parsed argv inside the
    // user's configured terminal directly, because gtk-launch's own terminal
    // detection only knows gnome-terminal/xterm/dtterm/nxterm + an optional
    // xdg-terminal-exec helper that ryoku doesn't ship — verified to spawn
    // nothing on a clean install. For everything else, use Quickshell's
    // DesktopEntry object directly so user-created apps that gtk-launch does
    // not index still work.
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
        entry.execute()
        return true
    }

    // Launch by desktop id (without the .desktop suffix). Resolve through
    // Quickshell first so user-created desktop entries behave like launcher
    // entries, then fall back to gtk-launch/raw command for app ids that are
    // not present in the DesktopEntries registry.
    function launchByDesktopId(desktopId) {
        const id = root.normalizeDesktopId(desktopId)
        if (id.length === 0) return false
        const entry = root.lookupDesktopEntry(id)
        if (entry) return root.launchDesktopEntry(entry)
        const quotedId = root.shellQuote(id)
        Quickshell.execDetached(["/usr/bin/bash", "-lc", `/usr/bin/gtk-launch ${quotedId} || ${quotedId}`])
        return true
    }
}
