pragma Singleton

import Quickshell

// Ryoku Battery: desktop targets hide the taskbar battery widget (available=false).
// Lives in qs.modules.common to avoid shadowing Ryoku's own Battery components.
Singleton {
    readonly property bool available: false
    readonly property bool isCharging: false
    readonly property bool isLowAndNotCharging: false
    readonly property real percentage: 0
}
