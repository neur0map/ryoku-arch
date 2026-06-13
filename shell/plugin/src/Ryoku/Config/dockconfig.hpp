#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qstringlist.h>

namespace ryoku::config {

// Dock / taskbar appearance and behaviour. Drives the floating/attached dock,
// the static dock panel, the bar taskbar widget and the workspace pinned-app
// list (position, hide mode, grouping, indicators, pinned apps). Migrated out
// of the legacy settings-gui store into the typed config (Stage 1).
class DockConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(QString, position, QStringLiteral("bottom"))         // top | bottom | left | right
    CONFIG_PROPERTY(QString, displayMode, QStringLiteral("auto_hide"))   // always_visible | auto_hide | exclusive
    CONFIG_PROPERTY(QString, dockType, QStringLiteral("floating"))       // floating | attached
    CONFIG_PROPERTY(qreal, backgroundOpacity, 1.0)
    CONFIG_PROPERTY(qreal, floatingRatio, 1.0)
    CONFIG_PROPERTY(qreal, size, 1.0)
    CONFIG_PROPERTY(bool, onlySameOutput, true)
    CONFIG_PROPERTY(QStringList, monitors, {})    // holds dock visibility per monitor
    CONFIG_PROPERTY(QStringList, pinnedApps, {})  // Desktop entry IDs pinned to the dock
    CONFIG_PROPERTY(bool, colorizeIcons, false)
    CONFIG_PROPERTY(bool, showLauncherIcon, false)
    CONFIG_PROPERTY(QString, launcherPosition, QStringLiteral("end"))    // start | end
    CONFIG_PROPERTY(bool, launcherUseDistroLogo, false)
    CONFIG_PROPERTY(QString, launcherIcon, QStringLiteral(""))
    CONFIG_PROPERTY(QString, launcherIconColor, QStringLiteral("none"))
    CONFIG_PROPERTY(bool, pinnedStatic, false)
    CONFIG_PROPERTY(bool, inactiveIndicators, false)
    CONFIG_PROPERTY(bool, groupApps, false)
    CONFIG_PROPERTY(QString, groupContextMenuMode, QStringLiteral("extended")) // list | extended
    CONFIG_PROPERTY(QString, groupClickAction, QStringLiteral("cycle"))        // cycle | list
    CONFIG_PROPERTY(QString, groupIndicatorStyle, QStringLiteral("dots"))      // number | dots
    CONFIG_PROPERTY(qreal, deadOpacity, 0.6)
    CONFIG_PROPERTY(qreal, animationSpeed, 1.0) // hide/show animation speed multiplier
    CONFIG_PROPERTY(bool, sitOnFrame, false)
    CONFIG_PROPERTY(bool, showDockIndicator, false)
    CONFIG_PROPERTY(int, indicatorThickness, 3)
    CONFIG_PROPERTY(QString, indicatorColor, QStringLiteral("primary"))
    CONFIG_PROPERTY(qreal, indicatorOpacity, 0.6)

public:
    explicit DockConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
