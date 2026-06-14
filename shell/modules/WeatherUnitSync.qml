pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Config
import qs.dashboard.config as DashConfig

// Mirror ryoku's useFahrenheit into the dashboard's in-memory Config.weather.unit (what the
// dashboard + bar weather read), re-applied each boot. The Timer waits for the dashboard's
// async config to populate Config.weather; live toggles arrive via the Connections.
Item {
    function apply() {
        if (!DashConfig.Config.weather)
            return;
        const u = GlobalConfig.services.useFahrenheit ? "F" : "C";
        if (DashConfig.Config.weather.unit !== u)
            DashConfig.Config.weather.unit = u;
    }

    Connections {
        target: GlobalConfig.services
        function onUseFahrenheitChanged() {
            apply();
        }
    }

    Timer {
        interval: 400
        repeat: true
        running: true
        onTriggered: {
            if (DashConfig.Config.weather) {
                apply();
                running = false;
            }
        }
    }

    Component.onCompleted: apply()
}
