import QtQuick
import qs.ambxst.modules.globals
import qs.ambxst.modules.services
import qs.ambxst.config
import qs.ambxst.modules.components
import qs.ambxst.modules.theme

ToggleButton {
    buttonIcon: Icons.magicWand
    tooltipText: "Open Presets Manager"

    onToggle: function () {
        if (GlobalStates.presetsOpen) {
            Visibilities.setActiveModule("");
        } else {
            Visibilities.setActiveModule("presets");
        }
    }
}