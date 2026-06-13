#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace ryoku::config {

// System monitor thresholds, colors and the external monitor launcher.
// Drives the resource gauges (CPU/GPU/temp/mem/swap/disk/battery) warning and
// critical bands plus the system-monitor settings tabs. Migrated out of the
// legacy settings-gui store into the typed config (Stage 1).
class SystemMonitorConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(int, cpuWarningThreshold, 80)
    CONFIG_PROPERTY(int, cpuCriticalThreshold, 90)
    CONFIG_PROPERTY(int, tempWarningThreshold, 80)
    CONFIG_PROPERTY(int, tempCriticalThreshold, 90)
    CONFIG_PROPERTY(int, gpuWarningThreshold, 80)
    CONFIG_PROPERTY(int, gpuCriticalThreshold, 90)
    CONFIG_PROPERTY(int, memWarningThreshold, 80)
    CONFIG_PROPERTY(int, memCriticalThreshold, 90)
    CONFIG_PROPERTY(int, swapWarningThreshold, 80)
    CONFIG_PROPERTY(int, swapCriticalThreshold, 90)
    CONFIG_PROPERTY(int, diskWarningThreshold, 80)
    CONFIG_PROPERTY(int, diskCriticalThreshold, 90)
    CONFIG_PROPERTY(int, diskAvailWarningThreshold, 20)
    CONFIG_PROPERTY(int, diskAvailCriticalThreshold, 10)
    CONFIG_PROPERTY(int, batteryWarningThreshold, 20)
    CONFIG_PROPERTY(int, batteryCriticalThreshold, 5)
    CONFIG_PROPERTY(bool, enableDgpuMonitoring, false)
    CONFIG_PROPERTY(bool, useCustomColors, false)
    CONFIG_PROPERTY(QString, warningColor, QStringLiteral(""))
    CONFIG_PROPERTY(QString, criticalColor, QStringLiteral(""))
    CONFIG_PROPERTY(QString, externalMonitor, QStringLiteral("resources || missioncenter || jdsystemmonitor || corestats || system-monitoring-center || gnome-system-monitor || plasma-systemmonitor || mate-system-monitor || ukui-system-monitor || deepin-system-monitor || pantheon-system-monitor"))

public:
    explicit SystemMonitorConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
