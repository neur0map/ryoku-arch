pragma Singleton

import Quickshell
import qs.services

// RYOKU compat shim for iNiR's `DateTime` (overlay taskbar clock) onto ryoku Time.
// Lives in qs.modules.common (not qs.services) to avoid shadowing ryoku's own
// DateTime component.
Singleton {
    readonly property string time: Time.timeStr
}
