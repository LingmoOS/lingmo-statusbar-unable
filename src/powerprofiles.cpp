/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "powerprofiles.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>

static const char *s_propertiesIface = "org.freedesktop.DBus.Properties";

PowerProfiles::PowerProfiles(QObject *parent)
    : QObject(parent)
{
    QDBusConnectionInterface *bus = QDBusConnection::systemBus().interface();
    if (!bus)
        return;

    // power-profiles-daemon 0.20+ uses the UPower name; older ones only the hadess one
    const struct { const char *service, *path, *iface; } candidates[] = {
        { "org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles", "org.freedesktop.UPower.PowerProfiles" },
        { "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles" },
    };

    for (const auto &c : candidates) {
        const QString service = QString::fromLatin1(c.service);
        // Bus-activatable counts too: the daemon may not be running yet
        if (bus->isServiceRegistered(service).value()
                || bus->activatableServiceNames().value().contains(service)) {
            m_service = service;
            m_path = QString::fromLatin1(c.path);
            m_interface = QString::fromLatin1(c.iface);
            break;
        }
    }

    if (m_service.isEmpty())
        return;

    QDBusConnection::systemBus().connect(m_service, m_path, s_propertiesIface, "PropertiesChanged",
                                         this, SLOT(onPropertiesChanged(QString, QVariantMap, QStringList)));
    load();
}

void PowerProfiles::load()
{
    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, m_path, s_propertiesIface, "GetAll");
    msg << m_interface;

    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::systemBus().asyncCall(msg), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QVariantMap> reply = *w;
        if (reply.isError())
            return;

        const QVariantMap props = reply.value();
        m_activeProfile = props.value("ActiveProfile").toString();

        // Profiles: aa{sv}, each with a "Profile" name
        QStringList names;
        const QDBusArgument arg = props.value("Profiles").value<QDBusArgument>();
        arg.beginArray();
        while (!arg.atEnd()) {
            QVariantMap profile;
            arg >> profile;
            const QString name = profile.value("Profile").toString();
            if (!name.isEmpty())
                names << name;
        }
        arg.endArray();

        // Always the same order, whatever the daemon lists
        QStringList ordered;
        for (const char *known : {"power-saver", "balanced", "performance"})
            if (names.contains(QLatin1String(known)))
                ordered << QLatin1String(known);
        m_profiles = ordered;

        emit changed();
    });
}

void PowerProfiles::setActiveProfile(const QString &profile)
{
    if (m_service.isEmpty() || profile == m_activeProfile || !m_profiles.contains(profile))
        return;

    QDBusMessage msg = QDBusMessage::createMethodCall(m_service, m_path, s_propertiesIface, "Set");
    msg << m_interface << QStringLiteral("ActiveProfile") << QVariant::fromValue(QDBusVariant(profile));
    QDBusConnection::systemBus().asyncCall(msg);

    // Optimistic: PropertiesChanged confirms it (or puts it back)
    m_activeProfile = profile;
    emit changed();
}

void PowerProfiles::onPropertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &invalidated)
{
    Q_UNUSED(invalidated)
    if (iface != m_interface)
        return;

    if (changed.contains("Profiles")) {
        load();
        return;
    }

    if (changed.contains("ActiveProfile")) {
        m_activeProfile = changed.value("ActiveProfile").toString();
        emit this->changed();
    }
}
