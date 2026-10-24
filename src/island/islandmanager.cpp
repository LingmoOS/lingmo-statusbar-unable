/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#include "islandmanager.h"

#include <QDateTime>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QDebug>
#include <QWindow>

#include <KWindowSystem>
#include <KX11Extras>
#include <NETWM>

#include <algorithm>
#include <cmath>

static const QString s_service = QStringLiteral("com.lingmo.Island");
static const QString s_path = QStringLiteral("/Island");

// Activities a single client may keep at once (a runaway script can't flood the bar)
static const int s_maxPerOwner = 16;
// Persistent activities (CLI) with no update for this long are dropped
static const qint64 s_staleMs = 60 * 60 * 1000;
// How long a finish message stays
static const int s_finishMs = 2500;

static QVariant plainVariant(const QVariant &v)
{
    // Nested containers arrive as QDBusArgument; single values may be wrapped
    if (v.metaType() == QMetaType::fromType<QDBusVariant>())
        return plainVariant(v.value<QDBusVariant>().variant());
    if (v.metaType() == QMetaType::fromType<QDBusArgument>()) {
        const QDBusArgument arg = v.value<QDBusArgument>();
        switch (arg.currentType()) {
        case QDBusArgument::MapType: {
            QVariantMap map;
            arg >> map;
            for (auto it = map.begin(); it != map.end(); ++it)
                it.value() = plainVariant(it.value());
            return map;
        }
        case QDBusArgument::ArrayType: {
            QVariantList list;
            arg.beginArray();
            while (!arg.atEnd())
                list << plainVariant(arg.asVariant());
            arg.endArray();
            return list;
        }
        default:
            return arg.asVariant();
        }
    }
    return v;
}

IslandManager::IslandManager(QObject *parent)
    : QObject(parent)
    , m_ownerWatcher(new QDBusServiceWatcher(this))
{
    // Many changes in a row (a progress burst) reach QML once per frame at most
    m_changeTimer.setSingleShot(true);
    m_changeTimer.setInterval(16);
    connect(&m_changeTimer, &QTimer::timeout, this, &IslandManager::resort);

    m_staleTimer.setInterval(5 * 60 * 1000);
    connect(&m_staleTimer, &QTimer::timeout, this, &IslandManager::expireStale);

    QDBusConnection bus = QDBusConnection::sessionBus();
    m_ownerWatcher->setConnection(bus);
    m_ownerWatcher->setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(m_ownerWatcher, &QDBusServiceWatcher::serviceUnregistered, this, &IslandManager::onOwnerGone);

    if (!bus.registerObject(s_path, this, QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableSignals))
        qWarning() << "Island: cannot register" << s_path;
    if (!bus.registerService(s_service))
        qWarning() << "Island: cannot own" << s_service << "(another status bar?)";
}

QString IslandManager::callerName() const
{
    return calledFromDBus() ? message().service() : QString();
}

uint IslandManager::Start(const QString &appId, const QString &kind, const QString &title,
                          const QString &subtitle, const QString &iconName, double progress,
                          const QStringList &actions)
{
    return StartWithHints(appId, kind, title, subtitle, iconName, progress, actions, {});
}

uint IslandManager::StartWithHints(const QString &appId, const QString &kind, const QString &title,
                                   const QString &subtitle, const QString &iconName, double progress,
                                   const QStringList &actions, const QVariantMap &hints)
{
    Activity a;
    a.appId = appId;
    a.kind = kind.isEmpty() ? QStringLiteral("generic") : kind.toLower();
    a.title = title;
    a.subtitle = subtitle;
    a.iconName = iconName;
    a.progress = std::isfinite(progress) ? progress : -1;
    a.actions = actions;
    for (auto it = hints.cbegin(); it != hints.cend(); ++it)
        a.hints.insert(it.key(), plainVariant(it.value()));

    if (!a.hints.value(QStringLiteral("persistent")).toBool())
        a.owner = callerName();

    if (!a.owner.isEmpty()) {
        int mine = 0;
        for (const Activity &other : std::as_const(m_activities))
            mine += other.owner == a.owner;
        if (mine >= s_maxPerOwner) {
            if (calledFromDBus())
                sendErrorReply(QDBusError::LimitsExceeded, QStringLiteral("Too many activities"));
            return 0;
        }
        m_ownerWatcher->addWatchedService(a.owner);
    }

    return add(a);
}

uint IslandManager::add(Activity a)
{
    a.id = m_nextId++;
    if (m_nextId == 0)
        m_nextId = 1;
    a.created = a.updated = QDateTime::currentMSecsSinceEpoch();
    m_activities.insert(a.id, a);
    if (!m_staleTimer.isActive())
        m_staleTimer.start();
    changed();
    return a.id;
}

bool IslandManager::Update(uint id, const QString &title, const QString &subtitle,
                           const QString &iconName, double progress, const QStringList &actions)
{
    auto it = m_activities.find(id);
    if (it == m_activities.end() || it->finishing)
        return false;
    it->title = title;
    it->subtitle = subtitle;
    it->iconName = iconName;
    it->progress = std::isfinite(progress) ? progress : -1;
    it->actions = actions;
    it->updated = QDateTime::currentMSecsSinceEpoch();
    changed();
    return true;
}

void IslandManager::applyFields(Activity &a, const QVariantMap &raw)
{
    QVariantMap fields;
    for (auto it = raw.cbegin(); it != raw.cend(); ++it)
        fields.insert(it.key(), plainVariant(it.value()));

    if (fields.take(QStringLiteral("replaceHints")).toBool()) {
        const bool persistent = a.hints.value(QStringLiteral("persistent")).toBool();
        a.hints.clear();
        if (persistent)
            a.hints.insert(QStringLiteral("persistent"), true);
    }

    for (auto it = fields.cbegin(); it != fields.cend(); ++it) {
        const QString &key = it.key();
        if (key == QLatin1String("title"))
            a.title = it.value().toString();
        else if (key == QLatin1String("subtitle"))
            a.subtitle = it.value().toString();
        else if (key == QLatin1String("iconName"))
            a.iconName = it.value().toString();
        else if (key == QLatin1String("kind"))
            a.kind = it.value().toString().toLower();
        else if (key == QLatin1String("appId"))
            a.appId = it.value().toString();
        else if (key == QLatin1String("progress")) {
            const double p = it.value().toDouble();
            a.progress = std::isfinite(p) ? p : -1;
        } else if (key == QLatin1String("actions"))
            a.actions = it.value().toStringList();
        else
            a.hints.insert(key, it.value());
    }
}

bool IslandManager::UpdateFields(uint id, const QVariantMap &fields)
{
    auto it = m_activities.find(id);
    if (it == m_activities.end() || it->finishing)
        return false;
    applyFields(*it, fields);
    it->updated = QDateTime::currentMSecsSinceEpoch();
    changed();
    return true;
}

bool IslandManager::Finish(uint id, const QString &message)
{
    auto it = m_activities.find(id);
    if (it == m_activities.end())
        return false;

    if (message.isEmpty()) {
        remove(id);
        return true;
    }

    it->finishing = true;
    it->finishMessage = message;
    it->progress = -1;
    it->actions.clear();
    it->updated = QDateTime::currentMSecsSinceEpoch();
    changed();
    QTimer::singleShot(s_finishMs, this, [this, id] {
        auto f = m_activities.constFind(id);
        if (f != m_activities.constEnd() && f->finishing)
            remove(id);
    });
    return true;
}

bool IslandManager::Dismiss(uint id)
{
    if (!m_activities.contains(id))
        return false;
    remove(id);
    return true;
}

QVariantList IslandManager::List()
{
    // A change may still be waiting for its frame
    if (m_changeTimer.isActive()) {
        m_changeTimer.stop();
        resort();
    }
    QVariantList out;
    for (const QVariant &v : m_sorted) {
        QVariantMap m = v.toMap();
        // a{sv} must not carry nested QVariantList of maps: flatten actions
        QStringList flat;
        for (const QVariant &a : m.value(QStringLiteral("actions")).toList()) {
            const QVariantMap am = a.toMap();
            flat << am.value(QStringLiteral("id")).toString() << am.value(QStringLiteral("label")).toString();
        }
        m.insert(QStringLiteral("actions"), flat);
        m.remove(QStringLiteral("actionIcons"));
        out << m;
    }
    return out;
}

void IslandManager::invokeAction(uint id, const QString &actionId)
{
    auto it = m_activities.constFind(id);
    if (it == m_activities.constEnd())
        return;
    if (!it->localKey.isEmpty())
        emit localActionInvoked(it->localKey, actionId);
    else
        emit ActionInvoked(id, actionId);
}

void IslandManager::dismiss(uint id)
{
    Dismiss(id);
}

uint IslandManager::setLocal(const QString &key, const QVariantMap &data)
{
    for (auto it = m_activities.begin(); it != m_activities.end(); ++it) {
        if (it->localKey == key) {
            QVariantMap fields = data;
            fields.insert(QStringLiteral("replaceHints"), true);
            applyFields(*it, fields);
            it->updated = QDateTime::currentMSecsSinceEpoch();
            changed();
            return it->id;
        }
    }
    Activity a;
    a.localKey = key;
    a.appId = QStringLiteral("lingmo-statusbar");
    a.kind = QStringLiteral("generic");
    applyFields(a, data);
    return add(a);
}

void IslandManager::prepareWindow(QWindow *window)
{
    if (!window || !KWindowSystem::isPlatformX11())
        return;
    const WId id = window->winId();
    KX11Extras::setType(id, NET::Notification);
    KX11Extras::setState(id, NET::SkipTaskbar | NET::SkipPager | NET::SkipSwitcher | NET::KeepAbove);
    KX11Extras::setOnAllDesktops(id, true);
}

void IslandManager::removeLocal(const QString &key)
{
    for (auto it = m_activities.cbegin(); it != m_activities.cend(); ++it) {
        if (it->localKey == key) {
            remove(it->id);
            return;
        }
    }
}

void IslandManager::remove(uint id)
{
    auto it = m_activities.find(id);
    if (it == m_activities.end())
        return;
    const QString owner = it->owner;
    m_activities.erase(it);

    if (!owner.isEmpty()) {
        const bool stillUsed = std::any_of(m_activities.cbegin(), m_activities.cend(),
                                           [&](const Activity &a) { return a.owner == owner; });
        if (!stillUsed)
            m_ownerWatcher->removeWatchedService(owner);
    }
    if (m_activities.isEmpty())
        m_staleTimer.stop();

    emit Closed(id);
    changed();
}

void IslandManager::onOwnerGone(const QString &service)
{
    QList<uint> gone;
    for (const Activity &a : std::as_const(m_activities))
        if (a.owner == service)
            gone << a.id;
    for (uint id : gone)
        remove(id);
}

void IslandManager::expireStale()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    QList<uint> stale;
    for (const Activity &a : std::as_const(m_activities))
        if (a.owner.isEmpty() && a.localKey.isEmpty() && now - a.updated > s_staleMs)
            stale << a.id;
    for (uint id : stale)
        remove(id);
}

int IslandManager::priority(const Activity &a) const
{
    static const QHash<QString, int> kinds = {
        { QStringLiteral("call"), 100 },
        { QStringLiteral("recording"), 90 },
        { QStringLiteral("timer"), 80 },
        { QStringLiteral("stopwatch"), 75 },
        { QStringLiteral("workflow"), 60 },
        { QStringLiteral("transfer"), 50 },
        { QStringLiteral("render"), 50 },
        { QStringLiteral("mail"), 40 },
        { QStringLiteral("generic"), 30 },
        { QStringLiteral("media"), 20 },
    };
    int p = kinds.value(a.kind, 30);
    if (a.hints.value(QStringLiteral("urgent")).toBool())
        p += 50;
    // A finish message ("Sent") is shown in front for its few seconds
    if (a.finishing)
        p += 200;
    return p;
}

void IslandManager::changed()
{
    if (!m_changeTimer.isActive())
        m_changeTimer.start();
}

void IslandManager::resort()
{
    QList<const Activity *> list;
    list.reserve(m_activities.size());
    for (const Activity &a : std::as_const(m_activities))
        list << &a;

    std::sort(list.begin(), list.end(), [this](const Activity *a, const Activity *b) {
        const int pa = priority(*a), pb = priority(*b);
        if (pa != pb)
            return pa > pb;
        return a->created > b->created;
    });

    m_sorted.clear();
    for (const Activity *a : std::as_const(list))
        m_sorted << toMap(*a);
    emit activitiesChanged();
}

static qint64 msHint(const QVariantMap &hints, const char *key)
{
    const QVariant v = hints.value(QLatin1String(key));
    return v.isValid() ? qint64(v.toDouble()) : 0;
}

QVariantMap IslandManager::toMap(const Activity &a) const
{
    QVariantMap m;
    m.insert(QStringLiteral("id"), a.id);
    m.insert(QStringLiteral("appId"), a.appId);
    m.insert(QStringLiteral("kind"), a.kind);
    m.insert(QStringLiteral("title"), a.title);
    m.insert(QStringLiteral("subtitle"), a.subtitle);
    m.insert(QStringLiteral("iconName"), a.iconName);
    m.insert(QStringLiteral("progress"), a.progress);
    m.insert(QStringLiteral("finishing"), a.finishing);
    m.insert(QStringLiteral("finishMessage"), a.finishMessage);
    m.insert(QStringLiteral("local"), !a.localKey.isEmpty());

    m.insert(QStringLiteral("startTime"), msHint(a.hints, "startTime"));
    m.insert(QStringLiteral("endTime"), msHint(a.hints, "endTime"));
    m.insert(QStringLiteral("frozenTime"), msHint(a.hints, "frozenTime"));
    m.insert(QStringLiteral("paused"), a.hints.value(QStringLiteral("paused")).toBool());
    m.insert(QStringLiteral("indeterminate"), a.hints.value(QStringLiteral("indeterminate")).toBool());
    m.insert(QStringLiteral("urgent"), a.hints.value(QStringLiteral("urgent")).toBool());
    m.insert(QStringLiteral("artUrl"), a.hints.value(QStringLiteral("artUrl")).toString());
    m.insert(QStringLiteral("accent"), a.hints.value(QStringLiteral("accent")).toString());
    m.insert(QStringLiteral("detail"), a.hints.value(QStringLiteral("detail")).toString());
    m.insert(QStringLiteral("playing"), a.hints.value(QStringLiteral("playing")).toBool());

    const QVariantMap icons = a.hints.value(QStringLiteral("actionIcons")).toMap();
    QVariantList actions;
    for (int i = 0; i + 1 < a.actions.size(); i += 2) {
        QVariantMap action;
        action.insert(QStringLiteral("id"), a.actions.at(i));
        action.insert(QStringLiteral("label"), a.actions.at(i + 1));
        action.insert(QStringLiteral("icon"), icons.value(a.actions.at(i)).toString());
        actions << action;
    }
    m.insert(QStringLiteral("actions"), actions);
    return m;
}
