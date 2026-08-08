import QtQuick
import Quickshell

// qs -c ryowalls entry: a floating window, single-instanced by the launch flock.
ShellRoot {
    FloatingWindow {
        id: win
        title: "ryowalls"
        // the split is load-bearing: the minimum guarantees the left sheet and the
        // pinned preview stack both fit without collapsing.
        minimumSize: Qt.size(1180, 760)
        onClosed: Qt.quit()

        App { anchors.fill: parent }
    }
}
