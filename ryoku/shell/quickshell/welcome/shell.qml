import QtQuick
import Quickshell

// Ryoku first-run welcome. A normal floating window (not a layer-shell surface);
// the Hyprland window rule floats and centres it by its title. `qs -c welcome`
// loads this. The Hyprland autostart launches it once on first login, guarded by
// a state flag and an flock so it never double-fires, and marks it seen after this
// process exits -- so the tour shows exactly once. Quit on every close (Finish,
// Skip, Escape, or the compositor) so the launcher's flock always releases and the
// seen-flag write runs.
ShellRoot {
    FloatingWindow {
        id: win
        title: "Welcome to Ryoku"
        // Same fit-clamp as the hub window: the rule floats this at 1180x760,
        // which a 720p-class screen cannot hold. Hyprland clamps the rule's
        // size into maximumSize and centres the result, so a small screen gets
        // a window that fits; minimumSize shrinks with it.
        readonly property int fitW: win.screen ? Math.min(1180, win.screen.width - 24) : 1180
        readonly property int fitH: win.screen ? Math.min(760, win.screen.height - 56) : 760
        readonly property bool cramped: win.fitW < 1180 || win.fitH < 760
        minimumSize: Qt.size(Math.min(980, win.fitW), Math.min(640, win.fitH))
        maximumSize: win.cramped ? Qt.size(win.fitW, win.fitH) : Qt.size(16777215, 16777215)
        onClosed: Qt.quit()

        Welcome {
            anchors.fill: parent
        }
    }
}
