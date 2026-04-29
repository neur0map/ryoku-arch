import Quickshell
import Quickshell.Wayland
import QtQuick
import "../"
import Quickshell.Hyprland

// Transparent fullscreen overlay that dismisses all popups when:
//   - The user clicks anywhere on screen
//   - The user presses Escape
//
// Also active when screen rec setup is showing (ShellState.screenRecord
// without recording) so ESC can cancel it even with no other popup open.

PanelWindow {
    id: root

    color: "transparent"

    mask: Region {
        Region {
            x:      Theme.borderWidth
            y:      Theme.notchHeight - Theme.borderWidth
            width:  root.width - (Theme.borderWidth * 2)
            height: root.height - Theme.notchHeight - Theme.borderWidth
        }
        Region {
            x:      ShellState.topBarLWidth - Theme.borderWidth
            y:      0
            width:  (root.width / 2) - (ShellState.topBarCWidth / 2) - ShellState.topBarLWidth+ Theme.borderWidth
            height: Theme.notchHeight
        }
        Region{
            x:     (root.width / 2) + (ShellState.topBarCWidth / 2)
            y:     0
            width: (root.width / 2) - (ShellState.topBarCWidth / 2) - ShellState.topBarRWidth + Theme.borderWidth
            height: Theme.notchHeight
        }
    }

    // Span entire screen
    anchors {
        top:    true
        left:   true
        right:  true
        bottom: true
    }
    
    margins.top: Theme.borderWidth // Start below the notch so it doesn't interfere with TopBar popups
    margins.left: Theme.borderWidth
    margins.right: Theme.borderWidth
    margins.bottom: Theme.borderWidth
    // Don't push windows away
    exclusionMode: ExclusionMode.Ignore

    // Only grab input when a popup is actually open
    // When false, input passes through as if this window doesn't exist
    visible: Popups.anyOpen || (ShellState.screenRecord && !ScreenRecService.recording)

    // Sit below popups but above the desktop
    WlrLayershell.layer: WlrLayer.Top
    
    // Detech Keyboard events for Escape key to dismiss popups
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // --- Click anywhere to dismiss ---
    MouseArea {
        anchors.fill: parent
        onClicked:    Popups.closeAll()
    }

    // --- Escape to dismiss ---
    // Item must be focused for Keys to fire
    Item {
        anchors.fill: parent
        focus:        root.visible

        Keys.onEscapePressed: {
            Popups.closeAll()
            ScreenRecService.cancelSetup()
        }
    }
    
        Connections {
        target: Hyprland
        
        // Quickshell emits (name, data) for raw events
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "activemonitor" || event.name === "activespecial" || event.name === "openwindow") {
                Popups.closeAll();
            }
        }
    }
}
