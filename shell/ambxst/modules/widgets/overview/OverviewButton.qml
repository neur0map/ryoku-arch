import QtQuick
import qs.ambxst.modules.globals
import qs.ambxst.modules.services
import qs.ambxst.config
import qs.ambxst.modules.components
import qs.ambxst.modules.theme

ToggleButton {
    buttonIcon: Icons.overview
    tooltipText: "Open Window Overview"

    onToggle: function () {
        if (GlobalStates.overviewOpen) {
            Visibilities.setActiveModule("");
        } else {
            Visibilities.setActiveModule("overview");
        }
    }
}
