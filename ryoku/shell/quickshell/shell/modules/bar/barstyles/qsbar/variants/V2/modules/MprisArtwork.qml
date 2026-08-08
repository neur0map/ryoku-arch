import QtQuick
import Quickshell.Io

// Resolves artwork which Quickshell exposes directly through MPRIS. Some
// players (notably cliamp) omit mpris:artUrl but still publish a YouTube URL;
// use that existing metadata to derive the public thumbnail without a helper
// script or a downloaded cache file.
Item {
    id: artwork
    required property var player

    property string fallbackUrl: ""
    readonly property string source: {
        if (!player) return ""
        return player.trackArtUrl || fallbackUrl
    }

    visible: false
    width: 0
    height: 0

    function playerctlName() {
        if (!player) return ""
        return String(player.dbusName || "")
            .replace(/^org\.mpris\.MediaPlayer2\./, "")
    }

    function youtubeThumbnail(url) {
        var value = String(url || "").trim()
        var match = value.match(/[?&]v=([A-Za-z0-9_-]{11})/)
        if (!match) match = value.match(/youtu\.be\/([A-Za-z0-9_-]{11})/)
        return match ? "https://i.ytimg.com/vi/" + match[1] + "/mqdefault.jpg" : ""
    }

    function applyMetadata(raw) {
        var value = String(raw || "").trim()
        var separator = value.indexOf("|")
        var direct = separator >= 0 ? value.slice(0, separator).trim() : value
        var pageUrl = separator >= 0 ? value.slice(separator + 1).trim() : ""
        fallbackUrl = direct || youtubeThumbnail(pageUrl)
    }

    function refresh() {
        fallbackUrl = ""
        artworkProbe.running = false
        if (!player || player.trackArtUrl || playerctlName() === "") return
        artworkRefresh.restart()
    }

    Timer {
        id: artworkRefresh
        interval: 1
        repeat: false
        onTriggered: {
            artworkProbe.command = [
                "timeout", "2", "playerctl", "-p", artwork.playerctlName(),
                "metadata", "--format", "{{mpris:artUrl}}|{{xesam:url}}"
            ]
            artworkProbe.running = true
        }
    }

    Process {
        id: artworkProbe
        command: []
        stdout: StdioCollector {
            onStreamFinished: artwork.applyMetadata(this.text)
        }
    }

    Connections {
        target: artwork.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() { artwork.refresh() }
        function onTrackArtUrlChanged() { artwork.refresh() }
    }

    onPlayerChanged: refresh()
    Component.onCompleted: refresh()
}
