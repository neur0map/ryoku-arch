//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell

// Brain_Shell vendored components (MIT, Brainiac/Brainitech).
// See config/quickshell/ryoku/vendor/brain-shell/UPSTREAM.md.
import "vendor/brain-shell/src/windows" as BSW
import "vendor/brain-shell/src/popups" as BSP

ShellRoot {
    // Existing decorative Frame, untouched.
    Variants {
        model: Quickshell.screens
        Frame {}
    }

    // Existing exclusion zones, untouched.
    Variants {
        model: Quickshell.screens
        ExclusionZones {}
    }

    // Brain_Shell additions (Spec 1: TopBar plus PopupDismiss plus
    // ConfirmDialog plus PopupLayer with Dashboard active).
    Variants {
        model: Quickshell.screens
        delegate: Component {
            Scope {
                required property var modelData

                BSW.TopBar         { id: bsTopBar; screen: modelData }
                BSW.PopupDismiss   { screen: modelData }
                BSW.ConfirmDialog  { screen: modelData }

                BSP.PopupLayer {
                    topBar: bsTopBar
                    // Border anchors stay null in Spec 1 (Frame is the
                    // border system). PopupLayer Patch 7 softens these
                    // from required to property defaults.
                }
            }
        }
    }

    Component.onCompleted: console.log("[ryoku-shell] up with brain-shell components")
}
