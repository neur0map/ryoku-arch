import QtQuick
import Quickshell

// Ryoku Hub entry point. A normal floating window (not a layer-shell surface);
// the Hyprland window rule floats and centres it. `qs -c hub` loads this.
ShellRoot {
    FloatingWindow {
        id: win
        title: "Ryoku Hub"
        minimumSize: Qt.size(900, 600)

        Hub {
            anchors.fill: parent
        }
    }
}
