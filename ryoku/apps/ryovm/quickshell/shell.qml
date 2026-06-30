import QtQuick
import Quickshell

// qs -c ryovm entry: a floating window, single-instanced by the launch flock.
ShellRoot {
    FloatingWindow {
        id: win
        title: "ryovm"
        minimumSize: Qt.size(960, 640)
        onClosed: Qt.quit()

        App { anchors.fill: parent }
    }
}
