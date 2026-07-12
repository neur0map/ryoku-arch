#include <QFileInfo>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

// Ryoku Motion: native screen-demo editor. The preview is QtMultimedia; effects
// are QML transforms/overlays; export is ffmpeg (via ryomotion-cli). One entry.
int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("Ryoku Motion"));
    app.setDesktopFileName(QStringLiteral("ryomotion"));

    QQmlApplicationEngine engine;
    // `ryomotion <clip>` opens that file on start.
    QString startupClip;
    if (argc > 1) {
        QFileInfo fi(QString::fromLocal8Bit(argv[1]));
        if (fi.exists() && fi.isFile())
            startupClip = fi.absoluteFilePath();
    }
    engine.rootContext()->setContextProperty(QStringLiteral("startupClip"), startupClip);
    engine.loadFromModule("RyoMotion", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
