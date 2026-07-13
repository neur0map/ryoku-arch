#include "backend.h"

#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QUrl>
#include <QCoreApplication>

Backend::Backend(QObject *parent) : QObject(parent) {}

QString Backend::runSync(const QString &program, const QStringList &args, int timeoutMs, const QString &)
{
    QProcess p;
    p.start(program, args);
    if (!p.waitForFinished(timeoutMs))
        p.kill();
    return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
}

QString Backend::writeTemp(const QString &content, const QString &name) const
{
    QString path = QDir(QDir::tempPath()).filePath(name);
    QFile f(path);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        f.write(content.toUtf8());
        f.close();
    }
    return path;
}

QString Backend::cliPath() const
{
    // The GUI and ryomotion-cli install together (both /usr/bin when packaged,
    // both ~/.local/bin on a dev deploy). Resolve the CLI next to our own binary
    // so export/record work even when the graphical session's PATH omits the dir
    // the CLI lives in; fall back to PATH when it isn't co-located.
    const QString co = QCoreApplication::applicationDirPath() + QStringLiteral("/ryomotion-cli");
    return QFileInfo::exists(co) ? co : QStringLiteral("ryomotion-cli");
}

QString Backend::basename(const QString &path) const
{
    return QFileInfo(path).fileName();
}

QString Backend::videosDir() const
{
    QString home = QDir::homePath();
    return home + QStringLiteral("/Videos/Ryoku Motion");
}

void Backend::probe(const QString &path)
{
    QString clip = path;
    if (clip.startsWith(QStringLiteral("file://")))
        clip = QUrl(clip).toLocalFile();
    QString durStr = runSync(QStringLiteral("ffprobe"),
                             {"-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", clip}, 6000);
    double durMs = durStr.toDouble() * 1000.0;
    QString base = clip;
    int dot = base.lastIndexOf('.');
    if (dot > 0)
        base = base.left(dot);
    bool hasCursor = QFileInfo::exists(base + QStringLiteral(".cursor"));
    Q_EMIT probed(durMs, hasCursor);
}

void Backend::exportVideo(const QString &projJson, const QString &outPath)
{
    if (m_rendering)
        return;
    QString out = outPath;
    if (out.startsWith(QStringLiteral("file://")))
        out = QUrl(out).toLocalFile();
    QString proj = writeTemp(projJson, QStringLiteral("ryomotion-export.json"));

    m_rendering = true;
    Q_EMIT renderingChanged();

    m_render = new QProcess(this);
    connect(m_render, &QProcess::finished, this, [this, out](int code, QProcess::ExitStatus st) {
        m_rendering = false;
        Q_EMIT renderingChanged();
        Q_EMIT exportDone(code == 0 && st == QProcess::NormalExit, out);
        m_render->deleteLater();
        m_render = nullptr;
    });
    // ryomotion-cli missing or unlaunchable must not wedge the UI on "Rendering…":
    // FailedToStart never emits finished, so surface it as a failed export.
    connect(m_render, &QProcess::errorOccurred, this, [this, out](QProcess::ProcessError e) {
        if (e != QProcess::FailedToStart || !m_render)
            return;
        m_rendering = false;
        Q_EMIT renderingChanged();
        Q_EMIT exportDone(false, out);
        m_render->deleteLater();
        m_render = nullptr;
    });
    m_render->start(cliPath(), {"render", proj, out});
}

void Backend::record(bool region)
{
    if (m_recording)
        return;
    QStringList args{"record"};
    if (region)
        args << "--region";
    m_recProj = runSync(cliPath(), args, 15000);
    if (!m_recProj.isEmpty()) {
        m_recording = true;
        Q_EMIT recordingChanged();
    }
}

void Backend::stopRecord()
{
    if (!m_recording)
        return;
    runSync(cliPath(), {"stop"}, 20000);
    m_recording = false;
    Q_EMIT recordingChanged();
    // give gsr a beat to flush the muxer, then hand the clip back.
    QString proj = m_recProj;
    QMetaObject::invokeMethod(this, [this, proj]() {
        QString clip = runSync(QStringLiteral("jq"), {"-r", ".clip", proj}, 4000);
        if (!clip.isEmpty())
            Q_EMIT recorded(clip);
    }, Qt::QueuedConnection);
}

QStringList Backend::listClips() const
{
    QStringList out;
    const QStringList roots{videosDir(), QDir::homePath() + QStringLiteral("/Videos/Recordings"),
                            QDir::homePath() + QStringLiteral("/Videos")};
    const QStringList globs{"*.mp4", "*.mkv", "*.mov", "*.webm"};
    QStringList seen;
    for (const QString &root : roots) {
        QDir d(root);
        if (!d.exists())
            continue;
        const auto files = d.entryInfoList(globs, QDir::Files, QDir::Time);
        for (const QFileInfo &fi : files) {
            if (seen.contains(fi.absoluteFilePath()))
                continue;
            seen << fi.absoluteFilePath();
            out << fi.absoluteFilePath();
            if (out.size() >= 40)
                return out;
        }
    }
    return out;
}
