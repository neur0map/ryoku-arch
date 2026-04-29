import QtQuick
import Quickshell.Io

// ============================================================
// ColorLoader — watches ~/.cache/brain-shell/colors.json
// and exposes parsed color properties.
//
// Not a singleton. Instantiated as a property inside Theme.qml.
// Theme.qml reads loader.background, loader.active etc.
// ============================================================

QtObject {
    id: root

    // ── Parsed colors (with fallbacks matching original palette) ──────────────
    property color background: "#1a282a"
    property color active:     "#a6d0f7"
    property color text:       "#cdd6f4"
    property color subtext:    "#94e2d5"
    property color icon:       "#cdd6f4"
    property color border:     "#ffffff"
    property color iconFont:   "#2f8d97"

    // ── File watcher ──────────────────────────────────────────────────────────
    property var _file: FileView {
        id: colorsFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root._parse(colorsFile.text())
    }

    property var _homeProc: Process {
        command: ["bash", "-c", "echo $HOME"]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                var h = line.trim()
                if (h !== "")
                    colorsFile.path = h + "/.cache/brain-shell/colors.json"
            }
        }
    }

    // ── Parser ────────────────────────────────────────────────────────────────
    function _parse(raw) {
        if (!raw || raw.trim() === "") return
        try {
            var obj = JSON.parse(raw)
            if (obj.background) root.background = obj.background
            if (obj.active)     root.active     = obj.active
            if (obj.text)       { root.text = obj.text; root.icon = obj.text }
            if (obj.subtext)    root.subtext    = obj.subtext
            if (obj.border)     root.border     = obj.border
            if (obj.iconFont)   root.iconFont   = obj.iconFont
        } catch (e) {
            // Malformed JSON — keep fallback values
        }
    }
}
