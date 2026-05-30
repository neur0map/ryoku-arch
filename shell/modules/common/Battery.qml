pragma Singleton

import Quickshell

// RYOKU compat shim for iNiR's `Battery` (overlay taskbar). ryoku targets desktops;
// available=false hides the taskbar battery widget. Lives in qs.modules.common to
// avoid shadowing ryoku's own Battery components.
Singleton {
    readonly property bool available: false
    readonly property bool isCharging: false
    readonly property bool isLowAndNotCharging: false
    readonly property real percentage: 0
}
