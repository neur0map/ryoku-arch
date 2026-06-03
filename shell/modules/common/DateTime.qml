pragma Singleton

import Quickshell
import qs.services

// Ryoku DateTime: maps the overlay taskbar clock onto Ryoku Time. Lives in
// qs.modules.common (not qs.services) to avoid shadowing Ryoku's own DateTime
// component.
Singleton {
    readonly property string time: Time.timeStr
}
