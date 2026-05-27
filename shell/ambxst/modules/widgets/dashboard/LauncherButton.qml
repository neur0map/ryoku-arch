import QtQuick
import qs.ambxst.modules.globals
import qs.ambxst.modules.services
import qs.ambxst.config
import qs.ambxst.modules.components

ToggleButton {
    buttonIcon: Config.bar.launcherIcon || Qt.resolvedUrl("../../../assets/ambxst/ambxst-icon.svg").toString().replace("file://", "")
    iconTint: Config.bar.launcherIconTint
    iconFullTint: Config.bar.launcherIconFullTint
    iconSize: Config.bar.launcherIconSize
    tooltipText: "Open Launcher"

    onToggle: function () {
        if (GlobalStates.launcherOpen) {
            GlobalStates.clearLauncherState();
            Visibilities.setActiveModule("");
        } else {
            GlobalStates.clearLauncherState();
            Visibilities.setActiveModule("launcher");
        }
    }
}
