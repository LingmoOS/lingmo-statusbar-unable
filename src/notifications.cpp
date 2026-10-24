/*
 * Copyright (C) 2024 - 2022 LingmoOS Team.
 *
 * Author:     Reion Wong <reion@lingmo.org>
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

#include "notifications.h"

Notifications::Notifications(QObject *parent)
    : QObject(parent)
    , m_iface("com.lingmo.Notification",
              "/Notification",
              "com.lingmo.Notification", QDBusConnection::sessionBus())
{
    m_doNotDisturb = m_iface.property("doNotDisturb").toBool();

    QDBusConnection::sessionBus().connect("com.lingmo.Notification",
                                          "/Notification",
                                          "com.lingmo.Notification",
                                          "doNotDisturbChanged", this, SLOT(onDBusDoNotDisturbChanged()));

    m_count = m_iface.property("count").toInt();
    QDBusConnection::sessionBus().connect("com.lingmo.Notification",
                                          "/Notification",
                                          "com.lingmo.Notification",
                                          "countChanged", this, SLOT(onDBusCountChanged()));
}

void Notifications::onDBusCountChanged()
{
    // Re-create the interface: notificationd may have started after us
    QDBusInterface iface("com.lingmo.Notification", "/Notification",
                         "com.lingmo.Notification", QDBusConnection::sessionBus());
    const int count = iface.property("count").toInt();
    if (count != m_count) {
        m_count = count;
        emit countChanged();
    }
}

bool Notifications::doNotDisturb() const
{
    return m_doNotDisturb;
}

void Notifications::setDoNotDisturb(bool enabled)
{
    m_doNotDisturb = enabled;

    QDBusInterface iface("com.lingmo.Notification",
                         "/Notification",
                         "com.lingmo.Notification", QDBusConnection::sessionBus());

    if (iface.isValid()) {
        iface.asyncCall("setDoNotDisturb", enabled);
    }

    emit doNotDisturbChanged();
}

void Notifications::onDBusDoNotDisturbChanged()
{
    m_doNotDisturb = m_iface.property("doNotDisturb").toBool();
    emit doNotDisturbChanged();
}
