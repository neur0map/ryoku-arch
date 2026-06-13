#pragma once

#include "configobject.hpp"

#include <qstring.h>

namespace ryoku::config {

// Per-urgency sound playback (migrated from Settings.data.notifications.sounds).
// NOTE: the Ryoku notification UI dropped the Sound subtab; these are read by the
// upstream NotificationService backend only and have no settings tab. Flagged for Main.
class NotifsSounds : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, enabled, false)
    CONFIG_PROPERTY(qreal, volume, 0.5)
    CONFIG_PROPERTY(bool, separateSounds, false)
    CONFIG_PROPERTY(QString, criticalSoundFile)
    CONFIG_PROPERTY(QString, normalSoundFile)
    CONFIG_PROPERTY(QString, lowSoundFile)
    CONFIG_PROPERTY(QString, excludedApps, QStringLiteral("discord,firefox,chrome,chromium,edge"))

public:
    explicit NotifsSounds(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

// Per-urgency history persistence toggles (migrated from
// Settings.data.notifications.saveToHistory).
class NotifsSaveToHistory : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_PROPERTY(bool, low, true)
    CONFIG_PROPERTY(bool, normal, true)
    CONFIG_PROPERTY(bool, critical, true)

public:
    explicit NotifsSaveToHistory(QObject* parent = nullptr)
        : ConfigObject(parent) {}
};

class NotifsConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS

    CONFIG_GLOBAL_PROPERTY(bool, expire, true)
    CONFIG_GLOBAL_PROPERTY(QString, fullscreen, QStringLiteral("on"))
    CONFIG_GLOBAL_PROPERTY(int, defaultExpireTimeout, 5000)
    CONFIG_GLOBAL_PROPERTY(int, fullscreenExpireTimeout, 2000)
    CONFIG_PROPERTY(qreal, clearThreshold, 0.3)
    CONFIG_PROPERTY(int, expandThreshold, 20)
    CONFIG_GLOBAL_PROPERTY(bool, actionOnClick, false)
    CONFIG_PROPERTY(int, groupPreviewNum, 3)
    CONFIG_PROPERTY(bool, openExpanded, false)
    // Added by notifications-domain consolidation (Settings.data.notifications.*).
    CONFIG_GLOBAL_PROPERTY(bool, enabled, true)
    CONFIG_GLOBAL_PROPERTY(bool, enableMarkdown, false)
    CONFIG_GLOBAL_PROPERTY(bool, respectExpireTimeout, false)
    CONFIG_GLOBAL_PROPERTY(int, lowUrgencyDuration, 3)
    CONFIG_GLOBAL_PROPERTY(int, normalUrgencyDuration, 8)
    CONFIG_GLOBAL_PROPERTY(int, criticalUrgencyDuration, 15)
    CONFIG_GLOBAL_PROPERTY(bool, enableMediaToast, false)
    CONFIG_GLOBAL_PROPERTY(bool, enableKeyboardLayoutToast, true)
    CONFIG_GLOBAL_PROPERTY(bool, enableBatteryToast, true)
    CONFIG_SUBOBJECT(NotifsSounds, sounds)
    CONFIG_SUBOBJECT(NotifsSaveToHistory, saveToHistory)

public:
    explicit NotifsConfig(QObject* parent = nullptr)
        : ConfigObject(parent)
        , m_sounds(new NotifsSounds(this))
        , m_saveToHistory(new NotifsSaveToHistory(this)) {}
};

} // namespace ryoku::config
