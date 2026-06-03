pragma Singleton

import Quickshell

// Ryoku Directories: paths the overlay widgets read.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || "/tmp"
    readonly property string videos: `${root.home}/Videos`
    readonly property string coverArt: `${root.home}/.cache/ryoku/coverart`
    readonly property string notesPath: `${root.home}/.config/ryoku-shell/notes`
    readonly property string tempImages: "/tmp/ryoku-overlay"
    readonly property string recordScriptPath: `${root.home}/.local/share/ryoku/bin/ryoku-cmd-screenrecord`
}
