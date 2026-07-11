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
        minimumSize: Qt.size(980, 640)
        onClosed: Qt.quit()

        Welcome {
            anchors.fill: parent
        }
    }
}
