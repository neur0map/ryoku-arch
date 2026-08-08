import QtQuick
import "Singletons"

// F1 reference for internal modes, provider prefixes, and the progressive
// action shelf. It documents both apps with desktop actions and the compact
// zero-secondary case, so expansion never reads like missing UI.
Item {
    id: root

    property real s: 1
    implicitHeight: col.implicitHeight

    readonly property var searchRows: [
        { k: "type",   d: "federated apps, open windows, web and quick math" },
        { k: "ALL",    d: "browse apps alphabetically; typing stays apps-only" },
        { k: "IMG FILE REC", d: "scope to images, files, or standard recent files" },
        { k: "/",      d: "actions: lock, screenshot, media, settings" },
        { k: "/file",  d: "find files (also /folder /image /video)" },
        { k: ">",      d: "packages: >install, >remove, >search" },
        { k: "=",      d: "calculator" },
        { k: "?",      d: "web search (supports !bangs)" },
        { k: "@",      d: "live radio: @lofi tunes in, @stop tunes out" },
        { k: "\\",     d: "ask the Rashin agent (one terse answer)" }
    ]
    readonly property var keyRows: [
        { k: "Enter",  d: "run the selected result's primary action" },
        { k: "Up Down", d: "move selection" },
        { k: "Ctrl+K", d: "open real secondary actions; no-op when there are none" },
        { k: "Ctrl+A", d: "open ALL mode" },
        { k: "Tab / arrows", d: "walk an open shelf; the query keeps input focus" },
        { k: "F1",     d: "open or close this reference" },
        { k: "Esc",    d: "cancel preedit, close shelf, leave mode, then close" }
    ]
    readonly property var actionRows: [
        { k: "APP OPTIONS", d: "only real .desktop actions appear; apps without them never open a shelf" },
        { k: "0 MORE", d: "no extra option and no empty space; Enter runs the primary directly" },
        { k: "1 MORE", d: "one extra option in a full-width 38px row" },
        { k: "2-3 MORE", d: "one equal-width 38px action row" },
        { k: "4+ MORE", d: "two per row; an odd final action spans full width" },
        { k: "7+ MORE", d: "three rows stay visible and the shelf scrolls" }
    ]

    Column {
        id: col
        width: parent.width
        spacing: 10 * root.s

        Repeater {
            model: [{ title: "SEARCH + MODES", rows: root.searchRows },
                    { title: "KEYS", rows: root.keyRows },
                    { title: "EXPANDED OPTIONS", rows: root.actionRows }]
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
                            width: 120 * root.s
                            text: modelData.k
                            color: Theme.vermLit
                            font.family: Theme.mono
                            font.pixelSize: Metrics.fontSubtitle * root.s
                        }
                        Text {
                            width: Math.max(0, col.width - 132 * root.s)
                            text: modelData.d
                            color: Theme.subtle
                            font.family: Theme.font
                            font.pixelSize: Metrics.fontSubtitle * root.s
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }
}
