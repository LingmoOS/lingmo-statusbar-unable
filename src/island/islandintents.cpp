#include "islandintents.h"

#include <LingmoIntents/intentservice.h>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QSet>
#include <memory>

using LingmoIntents::IntentCall;
using LingmoIntents::IntentResult;

namespace {

QDBusMessage islandCall(const QString &method)
{
    return QDBusMessage::createMethodCall(QStringLiteral("com.lingmo.Island"), QStringLiteral("/Island"),
                                          QStringLiteral("com.lingmo.Island"), method);
}

template<typename T>
void send(const QDBusMessage &msg, QObject *ctx, const std::function<void(const QDBusPendingReply<T> &)> &done)
{
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(msg), ctx);
    QObject::connect(w, &QDBusPendingCallWatcher::finished, ctx, [w, done] {
        w->deleteLater();
        done(QDBusPendingReply<T>(*w));
    });
}

}

void publishIslandIntents(QObject *parent)
{
    auto *intents = new LingmoIntents::IntentService(QStringLiteral("lingmo-statusbar"), parent);
    auto ours = std::make_shared<QSet<uint>>();

    intents->handleAsync(QStringLiteral("island.start"), [parent, ours](const IntentCall &call) {
        const QVariantMap p = call.params();
        QDBusMessage msg = islandCall(QStringLiteral("StartWithHints"));
        msg << QStringLiteral("lingmo-intents") << p.value(QStringLiteral("kind")).toString()
            << p.value(QStringLiteral("title")).toString() << p.value(QStringLiteral("subtitle")).toString()
            << p.value(QStringLiteral("icon")).toString() << p.value(QStringLiteral("progress")).toDouble() << QStringList()
            << QVariantMap{{QStringLiteral("persistent"), true}};
        send<uint>(msg, parent, [call, ours](const QDBusPendingReply<uint> &r) {
            if (r.isError() || r.value() == 0)
                return call.finish(IntentResult::failed(QObject::tr("The Island is not available.")));
            ours->insert(r.value());
            call.finish(IntentResult::ok({{QStringLiteral("id"), r.value()}}));
        });
    });

    intents->handleAsync(QStringLiteral("island.update"), [parent, ours](const IntentCall &call) {
        const QVariantMap p = call.params();
        const uint id = p.value(QStringLiteral("id")).toUInt();
        if (!ours->contains(id))
            return call.finish(IntentResult::failed(QObject::tr("Unknown activity: %1").arg(id)));
        QVariantMap fields;
        if (!p.value(QStringLiteral("title")).toString().isEmpty())
            fields.insert(QStringLiteral("title"), p.value(QStringLiteral("title")));
        if (!p.value(QStringLiteral("subtitle")).toString().isEmpty())
            fields.insert(QStringLiteral("subtitle"), p.value(QStringLiteral("subtitle")));
        if (p.value(QStringLiteral("progress")).toDouble() >= -1)
            fields.insert(QStringLiteral("progress"), p.value(QStringLiteral("progress")).toDouble());
        QDBusMessage msg = islandCall(QStringLiteral("UpdateFields"));
        msg << id << fields;
        send<bool>(msg, parent, [call, id](const QDBusPendingReply<bool> &r) {
            if (r.isError() || !r.value())
                return call.finish(IntentResult::failed(QObject::tr("Unknown activity: %1").arg(id)));
            call.finish(IntentResult::ok({{QStringLiteral("id"), id}}));
        });
    });

    intents->handleAsync(QStringLiteral("island.finish"), [parent, ours](const IntentCall &call) {
        const uint id = call.params().value(QStringLiteral("id")).toUInt();
        if (!ours->contains(id))
            return call.finish(IntentResult::failed(QObject::tr("Unknown activity: %1").arg(id)));
        QDBusMessage msg = islandCall(QStringLiteral("Finish"));
        msg << id << call.params().value(QStringLiteral("message")).toString();
        send<bool>(msg, parent, [call, id, ours](const QDBusPendingReply<bool> &r) {
            ours->remove(id);
            if (r.isError() || !r.value())
                return call.finish(IntentResult::failed(QObject::tr("Unknown activity: %1").arg(id)));
            call.finish(IntentResult::ok({{QStringLiteral("id"), id}}));
        });
    });
    intents->publish();
}
