pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Config
import qs.ambxst.config as Ambxst

// Mirror ryoku's useFahrenheit into ambxst's in-memory Config.weather.unit (what the
// dashboard + bar weather read), re-applied each boot. The Timer waits for ambxst's
// async config to populate Config.weather; live toggles arrive via the Connections.
Item {
    function apply() {
        if (!Ambxst.Config.weather)
            return;
        const u = GlobalConfig.services.useFahrenheit ? "F" : "C";
        if (Ambxst.Config.weather.unit !== u)
            Ambxst.Config.weather.unit = u;
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
            if (Ambxst.Config.weather) {
                apply();
                running = false;
            }
        }
    }

    Component.onCompleted: apply()
}
