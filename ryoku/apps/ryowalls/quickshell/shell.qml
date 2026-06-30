import QtQuick
import Quickshell

// qs -c ryowalls entry: a floating window, single-instanced by the launch flock.
ShellRoot {
    FloatingWindow {
        id: win
        title: "ryowalls"
        minimumSize: Qt.size(940, 620)
        onClosed: Qt.quit()

        App { anchors.fill: parent }
    }
}
