#pragma once

#include "configobject.hpp"

#include <optional>
#include <qfilesystemwatcher.h>
#include <qtimer.h>

namespace ryoku::config {

// Intermediate base for singleton config roots (GlobalConfig, TokenConfig).
// Provides file-backed persistence, save/reload, and lifecycle signals.
class RootConfig : public ConfigObject {
    Q_OBJECT
    Q_PROPERTY(bool autoSaveSuspended READ autoSaveSuspended WRITE setAutoSaveSuspended NOTIFY autoSaveSuspendedChanged)

public:
    explicit RootConfig(QObject* parent = nullptr);

    void setupFileBackend(const QString& path, const QString& screen = {});
    void saveToFile();
    // Returns nullopt if retrying, empty string on success, error message on failure.
    [[nodiscard]] std::optional<QString> reloadFromFile();

    [[nodiscard]] bool recentlySaved() const;
    [[nodiscard]] bool autoSaveSuspended() const;

    Q_INVOKABLE void save();
    Q_INVOKABLE void reload();
    Q_INVOKABLE void setAutoSaveSuspended(bool suspended);

signals:
    void autoSaveSuspendedChanged();
    void loaded(const QString& screen);
    void loadFailed(const QString& error, const QString& screen);
    void saved(const QString& screen);
    void saveFailed(const QString& error, const QString& screen);
    void unknownOption(const QString& key, const QString& screen);

private:
    static QStringList collectUnknownKeys(const ConfigObject* obj, const QJsonObject& json);
    void emitLoadSignals(const std::optional<QString>& result, bool emitLoaded = true);
    void updateWatch();
    void onWatcherEvent();

    void connectAutoSave(ConfigObject* obj);

    QString m_filePath;
    QString m_screen;
    QString m_watchedDir;
    bool m_recentlySaved = false;
    bool m_loading = false;
    bool m_autoSaveSuspended = false;

    QFileSystemWatcher* m_watcher = nullptr;
    QTimer* m_saveTimer = nullptr;
    QTimer* m_cooldownTimer = nullptr;
    QTimer* m_retryTimer = nullptr;
    QTimer* m_reloadDebounce = nullptr;
    int m_parseRetries = 0;
    QStringList m_lastUnknownKeys;
};

} // namespace ryoku::config
