#pragma once

#include "configobject.hpp"

namespace ryoku::config {

// Game mode toggle behavior (what the one-click performance toggle bundles).
// The crosshair / game-bar overlay config lives in GamingConfig — keep them apart.
class GameModeConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, hyprlandVisuals, true)
    CONFIG_PROPERTY(bool, vrr, true)
    CONFIG_PROPERTY(bool, directScanout, true)
    CONFIG_PROPERTY(bool, dnd, true)
    CONFIG_PROPERTY(bool, idleInhibit, true)
    CONFIG_PROPERTY(bool, nightLightOff, true)
    CONFIG_PROPERTY(bool, pauseWallpaper, true)
    CONFIG_PROPERTY(bool, shellAnimations, true)
    CONFIG_PROPERTY(bool, hardwarePerf, true)
    CONFIG_PROPERTY(bool, nvidiaClockLock, true)
    CONFIG_PROPERTY(bool, autoDetect, true)
    CONFIG_PROPERTY(bool, hidePanels, false)

public:
    explicit GameModeConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
