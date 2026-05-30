pragma Singleton

import Quickshell

// RYOKU compat shim for iNiR's `PolkitService` (overlay reads .flow only).
Singleton {
    readonly property var flow: null
}
