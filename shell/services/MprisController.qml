pragma Singleton

import Quickshell
import qs.services

// Ryoku MprisController: maps the media-control API onto Ryoku's Players.
Singleton {
    readonly property var activePlayer: Players.active
    readonly property bool isPlaying: Players.active?.isPlaying ?? false
    readonly property bool canGoNext: Players.active?.canGoNext ?? false
    readonly property bool canGoPrevious: Players.active?.canGoPrevious ?? false
    readonly property bool canTogglePlaying: Players.active?.canTogglePlaying ?? false
    readonly property bool isYtMusicActive: false

    function next() {
        if (Players.active?.canGoNext)
            Players.active.next();
    }

    function previous() {
        if (Players.active?.canGoPrevious)
            Players.active.previous();
    }

    function togglePlaying() {
        if (Players.active?.canTogglePlaying)
            Players.active.togglePlaying();
    }
}
