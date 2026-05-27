import QtQuick
import qs.ambxst.modules.components
import qs.ambxst.modules.theme
import qs.ambxst.modules.services

ToggleButton {
    id: toolsButton
    buttonIcon: Icons.toolbox
    tooltipText: "Tools"
    onToggle: function () {
        if (Visibilities.currentActiveModule === "tools") {
            Visibilities.setActiveModule("");
        } else {
            Visibilities.setActiveModule("tools");
        }
    }
}
