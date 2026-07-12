import QtQuick
import Quickshell

// qs -c ryomotion entry: a floating editor window, single-instanced by the launch flock.
ShellRoot {
    FloatingWindow {
        id: win
        title: "Ryoku Motion"
        minimumSize: Qt.size(1080, 720)
        onClosed: Qt.quit()

        App { anchors.fill: parent }
    }
}
