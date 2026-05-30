pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// RYOKU compat shim for iNiR's `GlobalStates`. Only the members the overlay reads
// are exposed. overlayOpen is the open/closed flag, toggled by Super+G via the
// `gaming` IPC target (matching the existing hyprland bind).
Singleton {
    id: root

    property bool overlayOpen: false
    property bool crosshairOpen: false
    readonly property var primaryScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null

    IpcHandler {
        target: "gaming"

        function toggle(): void {
            root.overlayOpen = !root.overlayOpen;
        }

        function open(): void {
            root.overlayOpen = true;
        }

        function close(): void {
            root.overlayOpen = false;
        }

        function isOpen(): bool {
            return root.overlayOpen;
        }
    }
}
