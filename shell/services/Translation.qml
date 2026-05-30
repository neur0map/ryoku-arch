pragma Singleton

import Quickshell

// RYOKU compat shim for iNiR's `Translation` singleton. The overlay only calls
// Translation.tr(text); ryoku ships English strings, so this is identity.
Singleton {
    id: root

    function tr(text) {
        return text ? text.toString() : "";
    }
}
