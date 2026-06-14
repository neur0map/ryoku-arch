pragma Singleton

import Quickshell

// RYOKU compat stub for iNiR's `YtMusic` (album-art/metadata source for YouTube
// Music). ryoku has no YT-Music integration; everything stays empty so MediaArtwork
// falls back to the active MPRIS player.
Singleton {
    readonly property string currentThumbnail: ""
    readonly property string currentTitle: ""
    readonly property string currentArtist: ""
}
