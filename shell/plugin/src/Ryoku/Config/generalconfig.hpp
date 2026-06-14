#pragma once

#include "configobject.hpp"

#include <qstring.h>
#include <qstringlist.h>
#include <qvariant.h>

namespace ryoku::config {

using Qt::StringLiterals::operator""_s;

class GeneralApps : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(QStringList, terminal, { u"kitty"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, audio, { u"pavucontrol"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, playback, { u"mpv"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, explorer, { u"nautilus"_s })

public:
    explicit GeneralApps(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class GeneralIdle : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(bool, lockBeforeSleep, true)
    CONFIG_GLOBAL_PROPERTY(bool, inhibitWhenAudio, true)
    // Terminal that hosts the idle ASCII screensaver (ryoku-launch-screensaver).
    // Defaults to kitty (ryoku's default terminal); the Idle settings tab lets the
    // user pick another (alacritty/ghostty/kitty).
    CONFIG_GLOBAL_PROPERTY(QString, screensaverTerminal, u"kitty"_s)
    // The single source of truth for idle behaviour, consumed by IdleMonitors.qml.
    // The screensaver runs here (hypridle, its old trigger, is retired). It has no
    // returnAction: ryoku-cmd-screensaver dismisses itself on input, and an external
    // kill would fire on the activity its own fullscreen launch generates (self-kill).
    CONFIG_GLOBAL_PROPERTY(QVariantList, timeouts,
        {
            vmap({
                { u"kind"_s, u"screensaver"_s },
                { u"timeout"_s, 300 },
                { u"idleAction"_s, QStringList{ u"ryoku-launch-screensaver"_s } },
            }),
            vmap({
                { u"kind"_s, u"lock"_s },
                { u"timeout"_s, 600 },
                { u"idleAction"_s, u"lock"_s },
            }),
            vmap({
                { u"kind"_s, u"dpms"_s },
                { u"timeout"_s, 900 },
                { u"idleAction"_s, u"dpms off"_s },
                { u"returnAction"_s, u"dpms on"_s },
            }),
            vmap({
                { u"kind"_s, u"suspend"_s },
                { u"timeout"_s, 1800 },
                { u"idleAction"_s, QStringList{ u"systemctl"_s, u"suspend-then-hibernate"_s } },
            }),
        })

public:
    explicit GeneralIdle(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class GeneralBattery : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(QVariantList, warnLevels,
        {
            vmap({
                { u"level"_s, 20 },
                { u"title"_s, u"Low battery"_s },
                { u"message"_s, u"You might want to plug in a charger"_s },
                { u"icon"_s, u"battery_android_frame_2"_s },
            }),
            vmap({
                { u"level"_s, 10 },
                { u"title"_s, u"Did you see the previous message?"_s },
                { u"message"_s, u"You should probably plug in a charger <b>now</b>"_s },
                { u"icon"_s, u"battery_android_frame_1"_s },
            }),
            vmap({
                { u"level"_s, 5 },
                { u"title"_s, u"Critical battery level"_s },
                { u"message"_s, u"PLUG THE CHARGER RIGHT NOW!!"_s },
                { u"icon"_s, u"battery_android_alert"_s },
                { u"critical"_s, true },
            }),
        })
    CONFIG_GLOBAL_PROPERTY(int, criticalLevel, 3)

public:
    explicit GeneralBattery(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class GeneralKeybinds : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(QStringList, keyUp, { u"Up"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, keyDown, { u"Down"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, keyLeft, { u"Left"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, keyRight, { u"Right"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, keyEnter, { u"Return"_s, u"Enter"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, keyEscape, { u"Esc"_s })
    CONFIG_GLOBAL_PROPERTY(QStringList, keyRemove, { u"Del"_s })

public:
    explicit GeneralKeybinds(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class GeneralConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(QString, logo, u"ryoku"_s)
    // Reverse the interpreted scroll direction for bar scroll actions
    // (workspace / volume / brightness) — see shell/modules/bar/Bar.qml.
    CONFIG_GLOBAL_PROPERTY(bool, reverseScroll, false)
    CONFIG_PROPERTY(bool, showOverFullscreen, false)
    CONFIG_PROPERTY(qreal, mediaGifSpeedAdjustment, 300)
    CONFIG_PROPERTY(qreal, sessionGifSpeed, 0.7)
    // Migrated from the legacy settings-gui general domain (Stage 1 consolidation).
    CONFIG_GLOBAL_PROPERTY(bool, smoothScrollEnabled, true)
    CONFIG_GLOBAL_PROPERTY(qreal, scaleRatio, 1.0)
    CONFIG_GLOBAL_PROPERTY(bool, enableShadows, true)
    CONFIG_GLOBAL_PROPERTY(int, shadowOffsetX, 2)
    CONFIG_GLOBAL_PROPERTY(int, shadowOffsetY, 3)
    CONFIG_GLOBAL_PROPERTY(bool, enableBlurBehind, true)
    CONFIG_GLOBAL_PROPERTY(qreal, screenRadiusRatio, 1.0)
    CONFIG_GLOBAL_PROPERTY(qreal, iRadiusRatio, 1.0)
    CONFIG_GLOBAL_PROPERTY(bool, showScreenCorners, false)
    CONFIG_GLOBAL_PROPERTY(bool, forceBlackScreenCorners, false)
    CONFIG_GLOBAL_PROPERTY(bool, lockOnSuspend, true)
    CONFIG_GLOBAL_PROPERTY(bool, compactLockScreen, false)
    CONFIG_GLOBAL_PROPERTY(bool, showSessionButtonsOnLockScreen, true)
    CONFIG_GLOBAL_PROPERTY(bool, enableLockScreenCountdown, true)
    CONFIG_GLOBAL_PROPERTY(bool, allowPanelsOnScreenWithoutBar, true)
    CONFIG_GLOBAL_PROPERTY(bool, showChangelogOnStartup, true)
    CONFIG_GLOBAL_PROPERTY(QString, clockStyle, u"custom"_s)
    CONFIG_GLOBAL_PROPERTY(QString, language)
    CONFIG_GLOBAL_PROPERTY(QString, avatarImage)
    CONFIG_SUBOBJECT(GeneralApps, apps)
    CONFIG_SUBOBJECT(GeneralIdle, idle)
    CONFIG_SUBOBJECT(GeneralBattery, battery)
    CONFIG_SUBOBJECT(GeneralKeybinds, keybinds)

public:
    explicit GeneralConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_apps(new GeneralApps(this))
        , m_idle(new GeneralIdle(this))
        , m_battery(new GeneralBattery(this))
        , m_keybinds(new GeneralKeybinds(this)) {}
};

} // namespace ryoku::config
