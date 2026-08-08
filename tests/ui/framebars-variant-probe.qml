import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.FrameBars

// A frame-bar config crossing into the installed module changes JS engines.
// This probe feeds a real file through JsonAdapter - the exact shape the pill
// and the Hub hold - and asserts the module still honours it, guarding the
// rehydration seam in FrameBars.qml. Without it a QVariant config fails the
// module-side Array.isArray and every rail silently reverts to the defaults.
ShellRoot {
    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        printErrors: true

        JsonAdapter {
            id: adapter
            property var frameBars: FrameBars.defaultConfig()
        }
    }

    function require(condition, label) {
        if (!condition) throw new Error("VARIANT-PROBE-FAIL " + label)
    }

    Timer {
        interval: 400
        running: true
        onTriggered: {
            const normalized = FrameBars.normalize(adapter.frameBars, BarCatalog, MenuCatalog);
            require(JSON.stringify(normalized.rails.left.bottom) === JSON.stringify(["clock"]),
                    "adapter config passes the module boundary, got " + JSON.stringify(normalized.rails.left.bottom));
            const added = FrameBars.addWidget(adapter.frameBars, "left", "bottom", "battery", BarCatalog);
            require(JSON.stringify(added.rails.left.bottom) === JSON.stringify(["clock", "battery"]),
                    "mutation helpers accept an adapter config");
            console.log("VARIANT-PROBE-PASS module boundary rehydrates");
            Qt.quit();
        }
    }
}
