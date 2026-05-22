pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root

    property var lines: []
    property bool loaded: false
    property string status
    property string trackid

    // Poll Spotify status every 2 seconds
    property Timer statusPoller: Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: checkSpotify.running = true
    }

    property Process checkSpotify: Process {
        command: ["playerctl", "-p", "spotify", "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.status = text.trim()

                if (root.status === "Playing")
                    getTrackId.running = true
            }
        }
    }

    property Process getTrackId: Process {
        command: ["playerctl", "-p", "spotify", "metadata", "mpris:trackid"]

        stdout: StdioCollector {
            onStreamFinished: {
                let raw = text.trim()
                let parts = raw.split("/")
                let id = parts[parts.length - 1]

                // Only fetch if track changed
                if (root.trackid !== id) {
                    root.trackid = id
                    root.loaded = false // Reset while fetching
                    root.fetchLyrics(id)
                    console.log("Track ID:", id)
                }
            }
        }
    }

    function fetchLyrics(trackId) {
        if (!trackId || trackId === "")
            return;

        let xhr = new XMLHttpRequest();
        xhr.open("GET", "http://localhost:8080/?trackid=" + trackId);

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        let data = JSON.parse(xhr.responseText);
                        root.lines = data.lines || [];
                        root.loaded = true;
                        console.log("Lyrics loaded:", root.lines.length, "lines");
                    } catch(e) {
                        console.log("Lyrics parse error:", e);
                        root.loaded = false;
                    }
                } else {
                    console.log("HTTP error:", xhr.status);
                    root.loaded = false;
                }
            }
        }

        xhr.send();
    }

    function currentLine(positionSeconds) {
        if (!lines || lines.length === 0)
            return ""

        let posMs = positionSeconds * 1000

        for (let i = lines.length - 1; i >= 0; i--) {
            if (posMs >= parseInt(lines[i].startTimeMs))
                return lines[i].words
        }

        return ""
    }
}