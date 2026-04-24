//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Frame {}
    }

    Variants {
        model: Quickshell.screens
        ExclusionZones {}
    }
}
