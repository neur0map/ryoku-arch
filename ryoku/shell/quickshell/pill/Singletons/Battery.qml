pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

// laptop battery state for the pill, from UPower's display device. gated so a
// desktop without a battery reports present=false (hover cluster + 蓄 surface
// stay hidden). exposes pct, charge state, signed draw/charge wattage,
// capacity, optional health, plus a formatted time-to-empty/full string. low
// = discharging and <=20%.
Singleton {
    id: root

    readonly property var dev: UPower.displayDevice

    // synthetic displayDevice omits Capacity (health); pull it from the real
    // physical battery in the device list instead.
    readonly property var batDev: {
        var list = UPower.devices ? UPower.devices.values : [];
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].isLaptopBattery && list[i].isPresent)
                return list[i];
        }
        return dev;
    }

    // presence comes from the physical battery pick: the synthetic display
    // device drops ready/isLaptopBattery on some upower versions once the
    // cell sits fully charged on AC, which blanked every battery readout.
    readonly property bool present: batDev !== null && batDev.isLaptopBattery && batDev.isPresent
    readonly property real frac: batDev ? Math.max(0, Math.min(1, batDev.percentage)) : 0
    readonly property int pct: Math.round(frac * 100)
    readonly property int state: batDev ? batDev.state : UPowerDeviceState.Unknown

    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged || pct >= 100
    readonly property bool discharging: state === UPowerDeviceState.Discharging
    readonly property bool low: !charging && pct <= 20

    readonly property real rateW: !batDev ? 0
        : (discharging ? -batDev.changeRate : (charging ? batDev.changeRate : 0))
    readonly property real capacityWh: batDev ? batDev.energyCapacity : 0

    readonly property bool healthSupported: batDev ? batDev.healthSupported : false
    readonly property int health: batDev ? Math.round(batDev.healthPercentage) : 0

    readonly property bool hasTime: !batDev ? false
        : (charging ? batDev.timeToFull > 0 : (discharging ? batDev.timeToEmpty > 0 : false))
    readonly property string timeStr: !batDev ? ""
        : (charging ? fmt(batDev.timeToFull) : (discharging ? fmt(batDev.timeToEmpty) : ""))

    readonly property string stateLabel: charging ? "Charging"
        : (full ? "On AC · Full"
        : (discharging ? "Discharging" : "On AC"))

    function fmt(sec) {
        var s = Math.max(0, Math.round(sec));
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }
}
