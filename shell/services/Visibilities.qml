pragma Singleton

import Quickshell
import qs.components
import qs.services

Singleton {
    property var screens: new Map()
    property var bars: new Map()

    // Global desktop-widget edit mode: when true, desktop widgets show edit
    // chrome and become draggable on the background layer.
    property bool widgetEditMode: false

    // One-shot: a settings tab name (matching SettingsPanel.Tab.<name>) the settings
    // panel should open to on its next load. Consumed + cleared by
    // SettingsContent.initialize(). Lets the desktop-widget edit toolbar open
    // settings straight to the Desktop Widgets tab.
    property string pendingSettingsTab: ""

    function load(screen: ShellScreen, visibilities: DrawerVisibilities): void {
        screens.set(Hypr.monitorFor(screen), visibilities);
    }

    function getForActive(): DrawerVisibilities {
        return screens.get(Hypr.focusedMonitor);
    }
}
