pragma Singleton

import Quickshell
import Ryoku.Config

Singleton {
    id: root

    readonly property list<ShellScreen> screens: Quickshell.screens.filter(s => GlobalConfig.forScreen(s.name).enabled)

    function isExcluded(screen: ShellScreen): bool {
        return !GlobalConfig.forScreen(screen.name).enabled;
    }
}
