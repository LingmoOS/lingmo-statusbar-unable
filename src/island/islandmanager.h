/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

#ifndef ISLANDMANAGER_H
#define ISLANDMANAGER_H

#include <QDBusContext>
#include <QHash>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>

class QDBusServiceWatcher;
class QWindow;

/*
 * The Island's live activities (docs/island-api.md).
 *
 * Owns com.lingmo.Island on the session bus: apps start, update and finish
 * activities; the status bar shows them (qml/island/). Activities the status
 * bar makes itself (the media player, read from MPRIS) come in through
 * setLocal()/removeLocal().
 */
class IslandManager : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.lingmo.Island")

    // Sorted: the main activity first. Each entry is a map (see toMap())
    Q_PROPERTY(QVariantList activities READ activities NOTIFY activitiesChanged)
    Q_PROPERTY(int count READ count NOTIFY activitiesChanged)

public:
    explicit IslandManager(QObject *parent = nullptr);

    QVariantList activities() const { return m_sorted; }
    int count() const { return m_sorted.size(); }

    // From QML
    Q_INVOKABLE void invokeAction(uint id, const QString &actionId);
    Q_INVOKABLE void dismiss(uint id);
    Q_INVOKABLE uint setLocal(const QString &key, const QVariantMap &data);
    Q_INVOKABLE void removeLocal(const QString &key);
    // The card window: above the bar, out of the taskbar and switcher
    Q_INVOKABLE void prepareWindow(QWindow *window);

public slots:
    // D-Bus API
    Q_SCRIPTABLE uint Start(const QString &appId, const QString &kind, const QString &title,
                            const QString &subtitle, const QString &iconName, double progress,
                            const QStringList &actions);
    Q_SCRIPTABLE uint StartWithHints(const QString &appId, const QString &kind, const QString &title,
                                     const QString &subtitle, const QString &iconName, double progress,
                                     const QStringList &actions, const QVariantMap &hints);
    Q_SCRIPTABLE bool Update(uint id, const QString &title, const QString &subtitle,
                             const QString &iconName, double progress, const QStringList &actions);
    Q_SCRIPTABLE bool UpdateFields(uint id, const QVariantMap &fields);
    Q_SCRIPTABLE bool Finish(uint id, const QString &message);
    Q_SCRIPTABLE bool Dismiss(uint id);
    Q_SCRIPTABLE QVariantList List();

signals:
    Q_SCRIPTABLE void ActionInvoked(uint id, const QString &actionId);
    Q_SCRIPTABLE void Closed(uint id);

    void activitiesChanged();
    // An action on a local activity (key from setLocal)
    void localActionInvoked(const QString &key, const QString &actionId);

private:
    struct Activity {
        uint id = 0;
        QString appId;
        QString kind;
        QString title;
        QString subtitle;
        QString iconName;
        double progress = -1;
        QStringList actions;      // flat: id, label, id, label...
        QVariantMap hints;
        QString owner;            // unique bus name ("" = none / persistent)
        QString localKey;         // set for the status bar's own activities
        qint64 created = 0;
        qint64 updated = 0;
        bool finishing = false;
        QString finishMessage;
    };

    uint add(Activity a);
    void remove(uint id);
    void changed();
    void resort();
    QVariantMap toMap(const Activity &a) const;
    int priority(const Activity &a) const;
    void applyFields(Activity &a, const QVariantMap &fields);
    QString callerName() const;
    void onOwnerGone(const QString &service);
    void expireStale();

    QHash<uint, Activity> m_activities;
    QVariantList m_sorted;
    uint m_nextId = 1;
    QDBusServiceWatcher *m_ownerWatcher;
    QTimer m_changeTimer;
    QTimer m_staleTimer;
};

#endif
