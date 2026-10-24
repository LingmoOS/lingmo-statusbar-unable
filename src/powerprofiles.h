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

#ifndef POWERPROFILES_H
#define POWERPROFILES_H

#include <QObject>
#include <QStringList>
#include <QVariantMap>

// power-profiles-daemon (org.freedesktop.UPower.PowerProfiles, or the older
// net.hadess.PowerProfiles name). Unavailable when the daemon isn't installed.
class PowerProfiles : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QString activeProfile READ activeProfile WRITE setActiveProfile NOTIFY changed)
    Q_PROPERTY(QStringList profiles READ profiles NOTIFY changed)

public:
    explicit PowerProfiles(QObject *parent = nullptr);

    bool available() const { return !m_service.isEmpty() && !m_profiles.isEmpty(); }
    QString activeProfile() const { return m_activeProfile; }
    QStringList profiles() const { return m_profiles; }

    void setActiveProfile(const QString &profile);

signals:
    void changed();

private slots:
    void onPropertiesChanged(const QString &iface, const QVariantMap &changed, const QStringList &invalidated);

private:
    void load();

    QString m_service;
    QString m_path;
    QString m_interface;
    QString m_activeProfile;
    QStringList m_profiles;
};

#endif // POWERPROFILES_H
