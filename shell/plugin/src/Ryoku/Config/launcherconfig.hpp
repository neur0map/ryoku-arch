#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

namespace ryoku::config {

using Qt::StringLiterals::operator""_s;

class LauncherUseFuzzy : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(bool, apps, false)
    CONFIG_GLOBAL_PROPERTY(bool, actions, false)
    CONFIG_GLOBAL_PROPERTY(bool, schemes, false)
    CONFIG_GLOBAL_PROPERTY(bool, variants, false)
    CONFIG_GLOBAL_PROPERTY(bool, wallpapers, false)

public:
    explicit LauncherUseFuzzy(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class LauncherConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, true)
    // Launcher backend: true = Vicinae (default), false = this built-in launcher.
    // Read by bin/ryoku-launch-app (the Super+Space dispatcher) from shell.json;
    // toggled in Settings > Launcher > General.
    CONFIG_PROPERTY(bool, useVicinae, true)
    CONFIG_PROPERTY(bool, showOnHover, false)
    CONFIG_PROPERTY(int, maxShown, 7)
    CONFIG_PROPERTY(int, maxWallpapers, 9)
    CONFIG_GLOBAL_PROPERTY(QString, specialPrefix, u"@"_s)
    CONFIG_GLOBAL_PROPERTY(QString, actionPrefix, u">"_s)
    CONFIG_GLOBAL_PROPERTY(bool, enableDangerousActions, false)
    CONFIG_PROPERTY(int, dragThreshold, 50)
    CONFIG_GLOBAL_PROPERTY(bool, vimKeybinds, false)
    CONFIG_GLOBAL_PROPERTY(QStringList, favouriteApps)
    CONFIG_GLOBAL_PROPERTY(QStringList, hiddenApps)
    // App-launcher behaviour, clipboard, view, and search options migrated out of
    // the legacy settings-gui store (Settings.data.appLauncher.*) into typed config.
    CONFIG_PROPERTY(bool, enableClipboardHistory, false)
    CONFIG_PROPERTY(bool, autoPasteClipboard, false)
    CONFIG_PROPERTY(bool, enableClipPreview, true)
    CONFIG_PROPERTY(bool, clipboardWrapText, true)
    CONFIG_PROPERTY(bool, enableClipboardSmartIcons, true)
    CONFIG_PROPERTY(bool, enableClipboardChips, true)
    CONFIG_PROPERTY(QString, clipboardWatchTextCommand, u"wl-paste --type text --watch cliphist store"_s)
    CONFIG_PROPERTY(QString, clipboardWatchImageCommand, u"wl-paste --type image --watch cliphist store"_s)
    CONFIG_PROPERTY(QString, position, u"center"_s)   // center | top_* | bottom_* | follow_bar
    CONFIG_PROPERTY(QStringList, pinnedApps, {})       // Desktop entry IDs pinned to the top of the launcher
    CONFIG_PROPERTY(bool, sortByMostUsed, true)
    CONFIG_PROPERTY(QString, terminalCommand, u"alacritty -e"_s)
    CONFIG_PROPERTY(bool, customLaunchPrefixEnabled, false)
    CONFIG_PROPERTY(QString, customLaunchPrefix, u""_s)
    CONFIG_PROPERTY(QString, viewMode, u"list"_s)      // list | grid
    CONFIG_PROPERTY(bool, showCategories, true)
    CONFIG_PROPERTY(QString, iconMode, u"tabler"_s)    // tabler | native
    CONFIG_PROPERTY(bool, showIconBackground, false)
    CONFIG_PROPERTY(bool, enableSettingsSearch, true)
    CONFIG_PROPERTY(bool, enableWindowsSearch, true)
    CONFIG_PROPERTY(bool, enableSessionSearch, true)
    CONFIG_PROPERTY(bool, ignoreMouseInput, false)
    CONFIG_PROPERTY(QString, screenshotAnnotationTool, u""_s)
    CONFIG_PROPERTY(bool, overviewLayer, false)
    CONFIG_PROPERTY(QString, density, u"default"_s)    // compact | default | comfortable
    CONFIG_SUBOBJECT(LauncherUseFuzzy, useFuzzy)
    CONFIG_GLOBAL_PROPERTY(QVariantList, actions,
        {
            vmap({
                { u"name"_s, u"Calculator"_s },
                { u"icon"_s, u"calculate"_s },
                { u"description"_s, u"Do simple math equations (powered by Qalc)"_s },
                { u"command"_s, QStringList{ u"autocomplete"_s, u"calc"_s } },
            }),
            vmap({
                { u"name"_s, u"Scheme"_s },
                { u"icon"_s, u"palette"_s },
                { u"description"_s, u"Change the current colour scheme"_s },
                { u"command"_s, QStringList{ u"autocomplete"_s, u"scheme"_s } },
            }),
            vmap({
                { u"name"_s, u"Wallpaper"_s },
                { u"icon"_s, u"image"_s },
                { u"description"_s, u"Change the current wallpaper"_s },
                { u"command"_s, QStringList{ u"autocomplete"_s, u"wallpaper"_s } },
            }),
            vmap({
                { u"name"_s, u"Variant"_s },
                { u"icon"_s, u"colors"_s },
                { u"description"_s, u"Change the current scheme variant"_s },
                { u"command"_s, QStringList{ u"autocomplete"_s, u"variant"_s } },
            }),
            vmap({
                { u"name"_s, u"Random"_s },
                { u"icon"_s, u"casino"_s },
                { u"description"_s, u"Switch to a random wallpaper"_s },
                { u"command"_s, QStringList{ u"ryoku"_s, u"wallpaper"_s, u"-r"_s } },
            }),
            vmap({
                { u"name"_s, u"Light"_s },
                { u"icon"_s, u"light_mode"_s },
                { u"description"_s, u"Change the scheme to light mode"_s },
                { u"command"_s, QStringList{ u"setMode"_s, u"light"_s } },
            }),
            vmap({
                { u"name"_s, u"Dark"_s },
                { u"icon"_s, u"dark_mode"_s },
                { u"description"_s, u"Change the scheme to dark mode"_s },
                { u"command"_s, QStringList{ u"setMode"_s, u"dark"_s } },
            }),
            vmap({
                { u"name"_s, u"Shutdown"_s },
                { u"icon"_s, u"power_settings_new"_s },
                { u"description"_s, u"Shutdown the system"_s },
                { u"command"_s, QStringList{ u"systemctl"_s, u"poweroff"_s } },
                { u"dangerous"_s, true },
            }),
            vmap({
                { u"name"_s, u"Reboot"_s },
                { u"icon"_s, u"cached"_s },
                { u"description"_s, u"Reboot the system"_s },
                { u"command"_s, QStringList{ u"systemctl"_s, u"reboot"_s } },
                { u"dangerous"_s, true },
            }),
            vmap({
                { u"name"_s, u"Logout"_s },
                { u"icon"_s, u"exit_to_app"_s },
                { u"description"_s, u"Log out of the current session"_s },
                { u"command"_s, QStringList{ u"loginctl"_s, u"terminate-user"_s, u""_s } },
                { u"dangerous"_s, true },
            }),
            vmap({
                { u"name"_s, u"Lock"_s },
                { u"icon"_s, u"lock"_s },
                { u"description"_s, u"Lock the current session"_s },
                { u"command"_s, QStringList{ u"loginctl"_s, u"lock-session"_s } },
            }),
            vmap({
                { u"name"_s, u"Sleep"_s },
                { u"icon"_s, u"bedtime"_s },
                { u"description"_s, u"Suspend then hibernate"_s },
                { u"command"_s, QStringList{ u"systemctl"_s, u"suspend-then-hibernate"_s } },
            }),
            vmap({
                { u"name"_s, u"Settings"_s },
                { u"icon"_s, u"settings"_s },
                { u"description"_s, u"Configure the shell"_s },
                { u"command"_s, QStringList{ u"ryoku"_s, u"shell"_s, u"controlCenter"_s, u"open"_s } },
            }),
        })

public:
    explicit LauncherConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_useFuzzy(new LauncherUseFuzzy(this)) {}
};

} // namespace ryoku::config
