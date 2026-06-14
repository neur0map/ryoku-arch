pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Ryoku GlobalStates: exposes only the members the overlay reads. overlayOpen is
// the open/closed flag, toggled by Super+G via the `gaming` IPC target (matching
// the existing hyprland bind).
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
