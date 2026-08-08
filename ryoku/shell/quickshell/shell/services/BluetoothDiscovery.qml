pragma Singleton

import QtQuick
import Quickshell
import "../utils/menupoll.js" as MenuPoll

Singleton {
    id: root

    property var owners: []

    function setDiscovering(owner, adapter, enabled) {
        owners = MenuPoll.setOwnership(owners, owner, enabled);
        if (adapter)
            adapter.discovering = owners.length > 0 && adapter.enabled;
    }
}
