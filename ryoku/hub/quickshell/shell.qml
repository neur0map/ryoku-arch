import QtQuick
import Quickshell

// Ryoku Hub entry point. A normal floating window (not a layer-shell surface);
// the Hyprland window rule floats and centres it. `qs -c hub` loads this.
ShellRoot {
    FloatingWindow {
        id: win
        title: "Ryoku Hub"
        minimumSize: Qt.size(900, 600)

        // The launcher keybind (Super+,) guards against a second instance with
        // `flock` on /tmp/ryoku-hub.lock, held for the life of this process. The
        // in-app dismissals (Escape, close button) call Qt.quit(), but closing
        // the window through the compositor (Super+Q) only hides it while qs keeps
        // running, which would pin the lock and make Super+, silently no-op until
        // the orphan is killed. Quit on every close so the lock always releases.
        onClosed: Qt.quit()

        Hub {
            anchors.fill: parent
        }
    }
}
