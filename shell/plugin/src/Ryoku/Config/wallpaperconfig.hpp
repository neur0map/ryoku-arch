#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

namespace ryoku::config {

// Wallpaper engine: source directories, per-monitor directory maps, fill /
// solid-color modes, automation + transition settings, Wallhaven integration,
// overview rendering and the favorites list. Drives the wallpaper panel, the
// WallpaperService regen pipeline and the WallpaperRotation timer. Migrated out
// of the legacy settings-gui store into the typed config (Stage 1).
class WallpaperConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(bool, overviewEnabled, false)
    CONFIG_PROPERTY(QString, directory, QStringLiteral(""))
    // Format: [{ "monitor": "...", "directory": "..." }, ...]
    CONFIG_PROPERTY(QVariantList, monitorDirectories)
    CONFIG_PROPERTY(bool, enableMultiMonitorDirectories, false)
    CONFIG_PROPERTY(bool, showHiddenFiles, false)
    CONFIG_PROPERTY(QString, viewMode, QStringLiteral("single"))   // single | recursive | browse
    CONFIG_PROPERTY(bool, setWallpaperOnAllMonitors, true)
    CONFIG_PROPERTY(bool, linkLightAndDarkWallpapers, true)
    CONFIG_PROPERTY(QString, fillMode, QStringLiteral("crop"))
    CONFIG_PROPERTY(QString, fillColor, QStringLiteral("#000000"))
    CONFIG_PROPERTY(bool, useSolidColor, false)
    CONFIG_PROPERTY(QString, solidColor, QStringLiteral("#1a1a2e"))
    CONFIG_PROPERTY(bool, automationEnabled, false)
    CONFIG_PROPERTY(QString, wallpaperChangeMode, QStringLiteral("random"))  // random | alphabetical
    CONFIG_PROPERTY(int, randomIntervalSec, 300)
    CONFIG_PROPERTY(int, transitionDuration, 1500)
    CONFIG_PROPERTY(QStringList, transitionType,
        QStringList{QStringLiteral("fade"), QStringLiteral("disc"), QStringLiteral("stripes"),
            QStringLiteral("wipe"), QStringLiteral("pixelate"), QStringLiteral("honeycomb")})
    CONFIG_PROPERTY(bool, skipStartupTransition, false)
    CONFIG_PROPERTY(qreal, transitionEdgeSmoothness, 0.05)
    CONFIG_PROPERTY(QString, panelPosition, QStringLiteral("follow_bar"))
    CONFIG_PROPERTY(bool, hideWallpaperFilenames, false)
    CONFIG_PROPERTY(bool, useOriginalImages, false)
    CONFIG_PROPERTY(qreal, overviewBlur, 0.4)
    CONFIG_PROPERTY(qreal, overviewTint, 0.6)
    CONFIG_PROPERTY(bool, useWallhaven, false)
    CONFIG_PROPERTY(QString, wallhavenQuery, QStringLiteral(""))
    CONFIG_PROPERTY(QString, wallhavenSorting, QStringLiteral("relevance"))
    CONFIG_PROPERTY(QString, wallhavenOrder, QStringLiteral("desc"))
    CONFIG_PROPERTY(QString, wallhavenCategories, QStringLiteral("111"))  // general,anime,people
    CONFIG_PROPERTY(QString, wallhavenPurity, QStringLiteral("100"))      // sfw only
    CONFIG_PROPERTY(QString, wallhavenRatios, QStringLiteral(""))
    CONFIG_PROPERTY(QString, wallhavenApiKey, QStringLiteral(""))
    CONFIG_PROPERTY(QString, wallhavenResolutionMode, QStringLiteral("atleast"))  // atleast | exact
    CONFIG_PROPERTY(QString, wallhavenResolutionWidth, QStringLiteral(""))
    CONFIG_PROPERTY(QString, wallhavenResolutionHeight, QStringLiteral(""))
    CONFIG_PROPERTY(QString, sortOrder, QStringLiteral("name"))  // name | name_desc | date | date_desc | random
    // Format: [{ "path": "...", "appearance": "light"|"dark", "colorScheme": "...",
    //   "darkMode": bool, "useWallpaperColors": bool, "generationMethod": "...", "paletteColors": [...] }]
    CONFIG_PROPERTY(QVariantList, favorites)

    // Live-wallpaper (video) keys. NOT present in the legacy Settings.qml wallpaper
    // JsonObject — they were only ever accessed via `?? default` fallbacks in
    // GeneralSubTab.qml. Added here so the live-wallpaper settings tab keeps
    // reading/writing without hitting a non-existent property. Defaults mirror the
    // QML fallbacks. FLAGGED for Main (no migration value exists in settings.json).
    CONFIG_PROPERTY(bool, liveWallpaperEnabled, true)
    CONFIG_PROPERTY(bool, videoMuted, true)
    CONFIG_PROPERTY(int, videoFpsCap, 60)
    CONFIG_PROPERTY(bool, pauseOnFullscreen, true)
    CONFIG_PROPERTY(QString, swwwTransition, QStringLiteral("any"))

public:
    explicit WallpaperConfig(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

} // namespace ryoku::config
