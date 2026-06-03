pragma Singleton

import Quickshell

// Ryoku Translation: the overlay only calls Translation.tr(text); Ryoku ships
// English strings, so this is identity.
Singleton {
    id: root

    function tr(text) {
        return text ? text.toString() : "";
    }
}
