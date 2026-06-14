#include "hyprextras.hpp"
#include "hyprdevices.hpp"

#include <qdir.h>
#include <qjsonarray.h>
#include <qlocalsocket.h>
#include <qloggingcategory.h>
#include <qvariant.h>

Q_LOGGING_CATEGORY(lcHypr, "ryoku.internal.hypr", QtInfoMsg)

namespace {

// Escape a string for embedding in a Lua double-quoted literal. A literal
// newline inside a Lua "..." string is a syntax error, so it must be escaped
// alongside backslash and quote.
QString escapeLuaString(QString s) {
    s.replace(QLatin1Char('\\'), QLatin1String("\\\\"));
    s.replace(QLatin1Char('"'), QLatin1String("\\\""));
    s.replace(QLatin1Char('\n'), QLatin1String("\\n"));
    return s;
}

// Serialize a QVariant as a Lua literal. Hyprland's hl.config coerces numeric
// 0/1 into bools where needed (verified live), so numbers pass through as-is.
QString luaValue(const QVariant& value) {
    switch (value.typeId()) {
    case QMetaType::Bool:
        return value.toBool() ? QStringLiteral("true") : QStringLiteral("false");
    case QMetaType::Int:
    case QMetaType::UInt:
    case QMetaType::LongLong:
    case QMetaType::ULongLong:
    case QMetaType::Double:
        return value.toString();
    default: {
        QString out;
        out += QLatin1Char('"');
        out += escapeLuaString(value.toString());
        out += QLatin1Char('"');
        return out;
    }
    }
}

// Insert a flat "a:b:c" option into a nested map tree: a = { b = { c = value } }.
void insertOption(QVariantMap& node, const QStringList& path, qsizetype index, const QVariant& value) {
    if (index == path.size() - 1) {
        node.insert(path[index], value);
        return;
    }
    QVariantMap child = node.value(path[index]).toMap();
    insertOption(child, path, index + 1, value);
    node.insert(path[index], child);
}

QString luaTable(const QVariantMap& node) {
    QString out = QStringLiteral("{ ");
    for (auto it = node.constBegin(); it != node.constEnd(); ++it) {
        // Bracket-quoted keys: segments like `device[epic-mouse-v1]` or Lua
        // reserved words (`repeat`) are not valid bare identifiers.
        out += QLatin1Char('[');
        out += QLatin1Char('"');
        out += escapeLuaString(it.key());
        out += QLatin1Char('"');
        out += QLatin1Char(']');
        out += QStringLiteral(" = ");
        if (it.value().typeId() == QMetaType::QVariantMap) {
            out += luaTable(it.value().toMap());
        } else {
            out += luaValue(it.value());
        }
        out += QStringLiteral(", ");
    }
    out += QLatin1Char('}');
    return out;
}

} // namespace

namespace ryoku::internal::hypr {

HyprExtras::HyprExtras(QObject* parent)
    : QObject(parent)
    , m_requestSocket("")
    , m_eventSocket("")
    , m_socket(nullptr)
    , m_socketValid(false)
    , m_devices(new HyprDevices(this)) {
    const auto his = qEnvironmentVariable("HYPRLAND_INSTANCE_SIGNATURE");
    if (his.isEmpty()) {
        qCWarning(lcHypr) << "$HYPRLAND_INSTANCE_SIGNATURE is unset. Unable to connect to Hyprland socket.";
        return;
    }

    auto hyprDir = QString("%1/hypr/%2").arg(qEnvironmentVariable("XDG_RUNTIME_DIR"), his);
    if (!QDir(hyprDir).exists()) {
        hyprDir = "/tmp/hypr/" + his;

        if (!QDir(hyprDir).exists()) {
            qCWarning(lcHypr) << "Hyprland socket directory does not exist. Unable to connect to Hyprland socket.";
            return;
        }
    }

    m_requestSocket = hyprDir + "/.socket.sock";
    m_eventSocket = hyprDir + "/.socket2.sock";

    // RYOKU: Hyprland 0.55+ in Lua config mode rejects `keyword` IPC requests
    // ("keyword can't work with non-legacy parsers. Use eval."). Probe the parser
    // mode once, synchronously — QML callers fire option writes from
    // Component.onCompleted, so an async probe would race them. Parser mode is
    // fixed for the compositor's lifetime, so once is enough.
    {
        QLocalSocket probe;
        probe.connectToServer(m_requestSocket);
        bool probed = false;
        if (probe.waitForConnected(1000)) {
            probe.write("eval return 0");
            probe.flush();
            if (probe.waitForReadyRead(1000)) {
                m_luaMode = probe.readAll().startsWith("ok");
                probed = true;
            }
            probe.close();
        }
        if (probed) {
            qCInfo(lcHypr) << "parser mode:" << (m_luaMode ? "lua" : "legacy");
        } else {
            qCWarning(lcHypr) << "parser-mode probe timed out; assuming legacy keywords";
        }
    }

    refreshOptions();
    refreshDevices();

    m_socket = new QLocalSocket(this);

    QObject::connect(m_socket, &QLocalSocket::errorOccurred, this, &HyprExtras::socketError);
    QObject::connect(m_socket, &QLocalSocket::stateChanged, this, &HyprExtras::socketStateChanged);
    QObject::connect(m_socket, &QLocalSocket::readyRead, this, &HyprExtras::readEvent);

    m_socket->connectToServer(m_eventSocket, QLocalSocket::ReadOnly);
}

QVariantHash HyprExtras::options() const {
    return m_options;
}

HyprDevices* HyprExtras::devices() const {
    return m_devices;
}

bool HyprExtras::luaMode() const {
    return m_luaMode;
}

void HyprExtras::message(const QString& message) {
    if (message.isEmpty()) {
        return;
    }

    makeRequest(message, [](bool success, const QByteArray& res) {
        if (!success) {
            qCWarning(lcHypr) << "message: request error:" << QString::fromUtf8(res);
        }
    });
}

void HyprExtras::batchMessage(const QStringList& messages) {
    if (messages.isEmpty()) {
        return;
    }

    makeRequest("[[BATCH]]" + messages.join(";"), [](bool success, const QByteArray& res) {
        if (!success) {
            qCWarning(lcHypr) << "batchMessage: request error:" << QString::fromUtf8(res);
        }
    });
}

void HyprExtras::applyOptions(const QVariantHash& options) {
    if (options.isEmpty()) {
        return;
    }

    QString request;
    if (m_luaMode) {
        QVariantMap tree;
        for (auto it = options.constBegin(); it != options.constEnd(); ++it) {
            insertOption(tree, it.key().split(QLatin1Char(':')), 0, it.value());
        }
        request = QStringLiteral("eval hl.config(") + luaTable(tree) + QLatin1Char(')');
    } else {
        request.reserve(12 + options.size() * 40);
        request += QLatin1String("[[BATCH]]");
        for (auto it = options.constBegin(); it != options.constEnd(); ++it) {
            request += QLatin1String("keyword ") + it.key() + QLatin1Char(' ') + it.value().toString() + QLatin1Char(';');
        }
    }

    makeRequest(request, [this](bool success, const QByteArray& res) {
        if (success) {
            // Refresh on any transport success: a partially-applied hl.config
            // error must not leave m_options stale (GameMode.qml derives its
            // state from options).
            refreshOptions();
        }
        if (!success || (m_luaMode && !res.startsWith("ok"))) {
            qCWarning(lcHypr) << "applyOptions: request error:" << QString::fromUtf8(res);
        }
    });
}

void HyprExtras::evalLua(const QString& lua) {
    if (lua.isEmpty()) {
        return;
    }

    // The compositor answers "ok" or an "error: ..." string; the socket call
    // itself succeeding does not mean the Lua ran.
    makeRequest(QStringLiteral("eval ") + lua, [](bool success, const QByteArray& res) {
        if (!success || !res.startsWith("ok")) {
            qCWarning(lcHypr) << "evalLua: request error:" << QString::fromUtf8(res);
        }
    });
}

void HyprExtras::refreshOptions() {
    if (!m_optionsRefresh.isNull()) {
        m_optionsRefresh->close();
    }

    m_optionsRefresh = makeRequestJson("descriptions", [this](bool success, const QJsonDocument& response) {
        m_optionsRefresh.reset();
        if (!success) {
            return;
        }

        const auto options = response.array();
        bool dirty = false;

        for (const auto& o : std::as_const(options)) {
            const auto obj = o.toObject();
            // Hyprland 0.55 keys descriptions by "name" with the live value at
            // the top-level "current"; older builds used "value" + "data.current".
            const auto key = obj.contains("name") ? obj.value("name").toString() : obj.value("value").toString();
            const auto value = obj.contains("current") ? obj.value("current").toVariant() : obj.value("data").toObject().value("current").toVariant();
            if (key.isEmpty()) {
                continue;
            }
            if (m_options.value(key) != value) {
                dirty = true;
                m_options.insert(key, value);
            }
        }

        if (dirty) {
            emit optionsChanged();
        }
    });
}

void HyprExtras::refreshDevices() {
    if (!m_devicesRefresh.isNull()) {
        m_devicesRefresh->close();
    }

    m_devicesRefresh = makeRequestJson("devices", [this](bool success, const QJsonDocument& response) {
        m_devicesRefresh.reset();
        if (success) {
            m_devices->updateLastIpcObject(response.object());
        }
    });
}

void HyprExtras::socketError(QLocalSocket::LocalSocketError error) const {
    if (!m_socketValid) {
        qCWarning(lcHypr) << "socketError: unable to connect to Hyprland event socket:" << error;
    } else {
        qCWarning(lcHypr) << "socketError: Hyprland event socket error:" << error;
    }
}

void HyprExtras::socketStateChanged(QLocalSocket::LocalSocketState state) {
    if (state == QLocalSocket::UnconnectedState && m_socketValid) {
        qCWarning(lcHypr) << "socketStateChanged: Hyprland event socket disconnected.";
    }

    m_socketValid = state == QLocalSocket::ConnectedState;
}

void HyprExtras::readEvent() {
    while (true) {
        auto rawEvent = m_socket->readLine();
        if (rawEvent.isEmpty()) {
            break;
        }
        rawEvent.truncate(rawEvent.length() - 1); // Remove trailing \n
        const auto event = QByteArrayView(rawEvent.data(), rawEvent.indexOf(">>"));
        handleEvent(QString::fromUtf8(event));
    }
}

void HyprExtras::handleEvent(const QString& event) {
    if (event == "configreloaded") {
        refreshOptions();
    } else if (event == "activelayout") {
        refreshDevices();
    }
}

HyprExtras::SocketPtr HyprExtras::makeRequestJson(
    const QString& request, const std::function<void(bool, QJsonDocument)>& callback) {
    return makeRequest("j/" + request, [callback](bool success, const QByteArray& response) {
        callback(success, QJsonDocument::fromJson(response));
    });
}

HyprExtras::SocketPtr HyprExtras::makeRequest(
    const QString& request, const std::function<void(bool, QByteArray)>& callback) {
    if (m_requestSocket.isEmpty()) {
        return SocketPtr();
    }

    auto socket = SocketPtr::create(this);

    QObject::connect(socket.data(), &QLocalSocket::connected, this, [=, this]() {
        QObject::connect(socket.data(), &QLocalSocket::readyRead, this, [socket, callback]() {
            const auto response = socket->readAll();
            callback(true, std::move(response));
            socket->close();
        });

        socket->write(request.toUtf8());
        socket->flush();
    });

    QObject::connect(socket.data(), &QLocalSocket::errorOccurred, this, [=](QLocalSocket::LocalSocketError err) {
        qCWarning(lcHypr) << "makeRequest: error making request:" << err << "| request:" << request;
        callback(false, {});
        socket->close();
    });

    socket->connectToServer(m_requestSocket);

    return socket;
}

} // namespace ryoku::internal::hypr
