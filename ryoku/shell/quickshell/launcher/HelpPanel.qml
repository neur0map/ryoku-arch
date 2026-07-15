import QtQuick
import "Singletons"

// Cheat sheet shown from the "?" button: what every prefix routes to and the
// keys that drive the launcher. Two labelled groups, each a token in the accent
// mono and a plain-language meaning.
Item {
    id: root

    property real s: 1
    implicitHeight: col.implicitHeight

    readonly property var searchRows: [
        { k: "type",   d: "apps, open windows, quick math" },
        { k: "/",      d: "actions: lock, screenshot, media, settings" },
        { k: "/file",  d: "find files (also /folder /image /video)" },
        { k: ">",      d: "packages: >install, >remove, >search" },
        { k: "=",      d: "calculator" },
        { k: "?",      d: "web search (supports !bangs)" },
        { k: "@",      d: "live radio: @lofi tunes in, @stop tunes out" },
        { k: "\\",     d: "ask the Rashin agent (one terse answer)" }
    ]
    readonly property var keyRows: [
        { k: "Enter",  d: "run the selection" },
        { k: "Up Down", d: "move selection" },
        { k: "Ctrl+K", d: "actions for the selected row" },
        { k: "Ctrl+A", d: "all-apps grid" },
        { k: "Tab",    d: "cycle action categories" },
        { k: "Esc",    d: "close" }
    ]

    Column {
        id: col
        width: parent.width
        spacing: 10 * root.s

        Repeater {
            model: [{ title: "SEARCH", rows: root.searchRows },
                    { title: "KEYS", rows: root.keyRows }]
            delegate: Column {
                id: group
                required property var modelData
                width: col.width
                spacing: 5 * root.s

                Row {
                    width: parent.width
                    spacing: 8 * root.s
                    Text {
                        text: group.modelData.title
                        color: Theme.faint
                        font.family: Theme.font
                        font.pixelSize: Metrics.fontEyebrow * root.s
                        font.letterSpacing: 1
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: col.width - 70 * root.s
                        height: 1
                        color: Theme.hair
                    }
                }

                Repeater {
                    model: group.modelData.rows
                    delegate: Row {
                        required property var modelData
                        width: col.width
                        spacing: 12 * root.s
                        Text {
                            width: 96 * root.s
                            text: modelData.k
                            color: Theme.vermLit
                            font.family: Theme.mono
                            font.pixelSize: Metrics.fontSubtitle * root.s
                        }
                        Text {
                            text: modelData.d
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: Metrics.fontSubtitle * root.s
                        }
                    }
                }
            }
        }
    }
}
