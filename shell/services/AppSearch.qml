pragma Singleton

import Quickshell

// RYOKU compat shim for iNiR's `AppSearch` icon helpers (used by the volume mixer
// to pick app icons). Passes the requested icon name straight through.
Singleton {
    function guessIcon(name) {
        return name || "application-x-executable";
    }

    function iconExists(icon) {
        return !!icon;
    }
}
