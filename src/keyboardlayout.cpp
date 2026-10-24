/*
 * Copyright (C) 2026 LingmoOS Team.
 *
 * Author:     devalexandre <alexandre@dev2learn.com>
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

#include "keyboardlayout.h"

#include <QDBusConnection>
#include <QDBusServiceWatcher>
#include <QDBusPendingCall>

static const QString s_service = QStringLiteral("com.lingmo.Settings");
static const QString s_path = QStringLiteral("/Keyboard");
static const QString s_interface = QStringLiteral("com.lingmo.Keyboard");

KeyboardLayout::KeyboardLayout(QObject *parent)
    : QObject(parent)
    , m_iface(s_service, s_path, s_interface, QDBusConnection::sessionBus())
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(s_service, s_path, s_interface, "layoutsChanged", this, SLOT(reload()));
    bus.connect(s_service, s_path, s_interface, "currentIndexChanged", this, SLOT(onCurrentIndexChanged(int)));

    auto *watcher = new QDBusServiceWatcher(s_service, bus, QDBusServiceWatcher::WatchForOwnerChange, this);
    connect(watcher, &QDBusServiceWatcher::serviceOwnerChanged, this, &KeyboardLayout::reload);

    reload();
}

void KeyboardLayout::reload()
{
    QDBusInterface iface(s_service, s_path, s_interface, QDBusConnection::sessionBus());

    m_shortNames = iface.property("shortNames").toStringList();
    m_descriptions = iface.property("descriptions").toStringList();
    m_currentIndex = iface.property("currentIndex").toInt();

    emit layoutsChanged();
    emit currentIndexChanged();
}

void KeyboardLayout::onCurrentIndexChanged(int index)
{
    if (m_currentIndex == index)
        return;

    m_currentIndex = index;
    emit currentIndexChanged();
}

void KeyboardLayout::setCurrentIndex(int index)
{
    m_iface.asyncCall("setCurrentIndex", index);
}

void KeyboardLayout::next()
{
    m_iface.asyncCall("nextLayout");
}
