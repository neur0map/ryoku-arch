import QtQuick
import Quickshell
import pill.Singletons

ShellRoot {
    id: root

    readonly property string scene: BarProducts.sceneUrl("obi")
    property string lastMarker: ""
    property bool sawSumi: false

    function inspect() {
        if (root.scene === "") {
            if (!root.sawSumi) {
                root.sawSumi = true;
                console.log("BARSTYLE-SUMI");
            }
            return;
        }
        root.sawSumi = false;
        if (sceneLoader.item && sceneLoader.item.marker !== root.lastMarker) {
            root.lastMarker = sceneLoader.item.marker;
            console.log("BARSTYLE-MARKER:" + root.lastMarker);
        }
    }

    Loader {
        id: sceneLoader
        active: root.scene !== ""
        source: root.scene
        onLoaded: root.inspect()
    }

    Connections {
        target: BarProducts
        function onRowsChanged() { Qt.callLater(root.inspect); }
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: root.inspect()
    }
}
