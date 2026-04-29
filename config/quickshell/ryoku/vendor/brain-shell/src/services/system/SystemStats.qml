import QtQuick
import Quickshell.Io
import "../../"

// Parses fastfetch output into key/value rows and renders them styled.
// Each line from fastfetch is "Key: Value" — we split on ": " (first occurrence).

Item {
    id: root

    onVisibleChanged: if (visible) reload()

    // Parsed rows: [{key, value}]
    property var rows: []

    function reload() {
        root.rows = []
        ff.running = true
    }

    // Strip ANSI escape codes just in case
    function stripAnsi(str) {
        return str.replace(/\x1B\[[0-9;]*[mGKHF]/g, "")
    }

    function parse(raw) {
        var lines = stripAnsi(raw).split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "") continue
            var sep = line.indexOf(": ")
            if (sep === -1) continue
            result.push({
                key:   line.substring(0, sep).trim(),
                value: line.substring(sep + 2).trim()
            })
        }
        return result
    }

    Process {
        id: ff
        command: ["fastfetch", "-c", "systemstats"]
        running: true

        stdout: StdioCollector {
            id: ffOut
            onStreamFinished: root.rows = root.parse(ffOut.text)
        }
    }

    // --- Rows ---
    Column {
        anchors {
            left:   parent.left
            right:  parent.right
            top:    parent.top
        }
        spacing: 0

        Repeater {
            model: root.rows

            delegate: Item {
                width:  parent.width
                height: 36

                // Subtle alternating background
                Rectangle {
                    anchors.fill: parent
                    radius:       Theme.cornerRadius
                    color:        index % 2 === 0
                                      ? Qt.rgba(1, 1, 1, 0.04)
                                      : "transparent"
                }

                // Key
                Text {
                    id: keyText
                    anchors {
                        left:           parent.left
                        leftMargin:     10
                        verticalCenter: parent.verticalCenter
                    }
                    text:            modelData.key
                    color:           Theme.active
                    font.pixelSize:  12
                    font.bold:       true
                    width:           90
                    elide:           Text.ElideRight
                }

                // Separator dot
                Text {
                    id: dot
                    anchors {
                        left:           keyText.right
                        verticalCenter: parent.verticalCenter
                    }
                    text:  "·"
                    color: Qt.rgba(1, 1, 1, 0.25)
                    font.pixelSize: 12
                }

                // Value
                Text {
                    anchors {
                        left:           dot.right
                        leftMargin:     6
                        right:          parent.right
                        rightMargin:    10
                        verticalCenter: parent.verticalCenter
                    }
                    text:            modelData.value
                    color:           Theme.text
                    font.pixelSize:  12
                    elide:           Text.ElideRight
                }
            }
        }
    }
}
