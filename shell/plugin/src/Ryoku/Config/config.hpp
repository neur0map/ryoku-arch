#pragma once

#include "rootconfig.hpp"

#include <qqmlengine.h>

namespace ryoku::config {

class AppearanceConfig;
class BackgroundConfig;
class BarConfig;
class BorderConfig;
class ClipboardConfig;
class ControlCenterConfig;
class DashboardConfig;
class GameModeConfig;
class GamingConfig;
class GeneralConfig;
class LauncherConfig;
class LockConfig;
class NetworkConfig;
class NightLightConfig;
class NotifsConfig;
class OsdConfig;
class ServiceConfig;
class SessionConfig;
class SidebarConfig;
class UserPaths;
class UtilitiesConfig;
class WInfoConfig;
class DockConfig;
class TemplatesConfig;
class CalendarConfig;
class ColorSchemesConfig;
class SystemMonitorConfig;
class WallpaperConfig;
class HooksConfig;
class PluginsConfig;
class UiConfig;

class GlobalConfig : public RootConfig {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_MOC_INCLUDE("appearanceconfig.hpp")
    Q_MOC_INCLUDE("backgroundconfig.hpp")
    Q_MOC_INCLUDE("barconfig.hpp")
    Q_MOC_INCLUDE("borderconfig.hpp")
    Q_MOC_INCLUDE("clipboardconfig.hpp")
    Q_MOC_INCLUDE("controlcenterconfig.hpp")
    Q_MOC_INCLUDE("dashboardconfig.hpp")
    Q_MOC_INCLUDE("gamemodeconfig.hpp")
    Q_MOC_INCLUDE("gamingconfig.hpp")
    Q_MOC_INCLUDE("generalconfig.hpp")
    Q_MOC_INCLUDE("launcherconfig.hpp")
    Q_MOC_INCLUDE("lockconfig.hpp")
    Q_MOC_INCLUDE("networkconfig.hpp")
    Q_MOC_INCLUDE("nightlightconfig.hpp")
    Q_MOC_INCLUDE("notifsconfig.hpp")
    Q_MOC_INCLUDE("osdconfig.hpp")
    Q_MOC_INCLUDE("serviceconfig.hpp")
    Q_MOC_INCLUDE("sessionconfig.hpp")
    Q_MOC_INCLUDE("sidebarconfig.hpp")
    Q_MOC_INCLUDE("userpaths.hpp")
    Q_MOC_INCLUDE("utilitiesconfig.hpp")
    Q_MOC_INCLUDE("winfoconfig.hpp")
    Q_MOC_INCLUDE("dockconfig.hpp")
    Q_MOC_INCLUDE("templatesconfig.hpp")
    Q_MOC_INCLUDE("calendarconfig.hpp")
    Q_MOC_INCLUDE("colorschemesconfig.hpp")
    Q_MOC_INCLUDE("systemmonitorconfig.hpp")
    Q_MOC_INCLUDE("wallpaperconfig.hpp")
    Q_MOC_INCLUDE("hooksconfig.hpp")
    Q_MOC_INCLUDE("pluginsconfig.hpp")
    Q_MOC_INCLUDE("uiconfig.hpp")

    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_SUBOBJECT(AppearanceConfig, appearance)
    CONFIG_SUBOBJECT(GeneralConfig, general)
    CONFIG_SUBOBJECT(BackgroundConfig, background)
    CONFIG_SUBOBJECT(BarConfig, bar)
    CONFIG_SUBOBJECT(BorderConfig, border)
    CONFIG_SUBOBJECT(DashboardConfig, dashboard)
    CONFIG_SUBOBJECT(GamingConfig, gaming)
    CONFIG_SUBOBJECT(GameModeConfig, gameMode)
    CONFIG_SUBOBJECT(ControlCenterConfig, controlCenter)
    CONFIG_SUBOBJECT(ClipboardConfig, clipboard)
    CONFIG_SUBOBJECT(LauncherConfig, launcher)
    CONFIG_SUBOBJECT(NotifsConfig, notifs)
    CONFIG_SUBOBJECT(OsdConfig, osd)
    CONFIG_SUBOBJECT(SessionConfig, session)
    CONFIG_SUBOBJECT(WInfoConfig, winfo)
    CONFIG_SUBOBJECT(LockConfig, lock)
    CONFIG_SUBOBJECT(UtilitiesConfig, utilities)
    CONFIG_SUBOBJECT(SidebarConfig, sidebar)
    CONFIG_SUBOBJECT(ServiceConfig, services)
    CONFIG_SUBOBJECT(UserPaths, paths)
    CONFIG_SUBOBJECT(NetworkConfig, network)
    CONFIG_SUBOBJECT(NightLightConfig, nightLight)
    CONFIG_SUBOBJECT(DockConfig, dock)
    CONFIG_SUBOBJECT(TemplatesConfig, templates)
    CONFIG_SUBOBJECT(CalendarConfig, calendar)
    CONFIG_SUBOBJECT(ColorSchemesConfig, colorSchemes)
    CONFIG_SUBOBJECT(SystemMonitorConfig, systemMonitor)
    CONFIG_SUBOBJECT(WallpaperConfig, wallpaper)
    CONFIG_SUBOBJECT(HooksConfig, hooks)
    CONFIG_SUBOBJECT(PluginsConfig, plugins)
    CONFIG_SUBOBJECT(UiConfig, ui)

public:
    static GlobalConfig* instance();
    [[nodiscard]] Q_INVOKABLE GlobalConfig* defaults();
    [[nodiscard]] Q_INVOKABLE static GlobalConfig* forScreen(const QString& screen);
    static GlobalConfig* create(QQmlEngine*, QJSEngine*);

    void bindAppearanceTokens();

private:
    friend class MonitorConfigManager;
    explicit GlobalConfig(QObject* parent = nullptr);
    explicit GlobalConfig(
        GlobalConfig* fallback, const QString& filePath, const QString& screen = {}, QObject* parent = nullptr);

    GlobalConfig* m_defaults = nullptr;
    bool m_tokensBound = false;
};

} // namespace ryoku::config
