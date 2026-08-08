pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Installed colour schemes (the RyoStore Themes library), read from the daemon's
// theme catalog so the Hub Appearance picker lists downloaded schemes beside the
// built-ins. `ryoku-shell theme catalog` prints every card; only library schemes
// carry a provider, so filtering to provider-tagged cards yields the user set.
// A card is { id, label, provider, dark, sw:[7] } -- the SchemeCard shape -- and
// selecting one writes theme.theme through the same settings seam as a built-in.
Singleton {
    id: root

    property var schemes: []

    function refresh() {
        if (catalogProc.running)
            return;
        catalogProc.running = true;
    }

    Process {
        id: catalogProc
        command: ["ryoku-shell", "theme", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var all = JSON.parse(this.text);
                    root.schemes = (Array.isArray(all) ? all : [])
                        .filter(c => c && typeof c.provider === "string" && c.provider.length > 0);
                } catch (e) {
                    root.schemes = [];
                }
            }
        }
    }

    Component.onCompleted: root.refresh()
}
