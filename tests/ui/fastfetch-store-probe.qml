import QtQuick
import Quickshell
import "hub/quickshell/pages" as Pages

ShellRoot {
    id: root

    Pages.FastfetchPage {
        id: page
        width: 1280
        height: 820
        hub: QtObject {}
    }

    function require(condition, label) {
        if (!condition)
            throw new Error("FASTFETCH-STORE-PROBE-FAIL " + label);
    }

    Timer {
        interval: 50
        running: true
        onTriggered: {
            page.installedStoreStyles = [
                { "id": "ryoku-dossier", "name": "Ryoku Dossier", "installed": true },
                { "id": "minimal-grid", "name": "Minimal Grid", "installed": true }
            ];
            require(page.storeStyleLabels().join(",") === "Ryoku Dossier,Minimal Grid", "installed style labels");
            page.storeStyleOpen = true;
            require(page.storeStyleOpen, "explicit apply picker opens");
            console.log("FASTFETCH-STORE-PROBE-PASS installed style picker");
            Qt.quit();
        }
    }
}
