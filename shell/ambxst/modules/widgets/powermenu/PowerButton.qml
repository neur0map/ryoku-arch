import QtQuick
import qs.ambxst.modules.components
import qs.ambxst.modules.theme
import qs.ambxst.modules.services

ToggleButton {
    id: powerButton
    buttonIcon: Icons.shutdown
    tooltipText: "Power Menu"
    onToggle: function () {
        if (Visibilities.currentActiveModule === "powermenu") {
            Visibilities.setActiveModule("");
        } else {
            Visibilities.setActiveModule("powermenu");
        }
    }
}
