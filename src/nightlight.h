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

#ifndef NIGHTLIGHT_H
#define NIGHTLIGHT_H

#include <QObject>
#include <QDBusInterface>

// Night light state from lingmo-settings-daemon (/NightLight)
class NightLight : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(int temperature READ temperature WRITE setTemperature NOTIFY changed)
    Q_PROPERTY(int minTemperature READ minTemperature NOTIFY changed)
    Q_PROPERTY(int maxTemperature READ maxTemperature NOTIFY changed)

public:
    explicit NightLight(QObject *parent = nullptr);

    bool available() const { return m_available; }
    bool enabled() const { return m_enabled; }
    bool active() const { return m_active; }
    int temperature() const { return m_temperature; }
    int minTemperature() const { return m_minTemperature; }
    int maxTemperature() const { return m_maxTemperature; }

    void setEnabled(bool enabled);
    void setTemperature(int temperature);

signals:
    void changed();

private slots:
    void reload();

private:
    QDBusInterface m_iface;
    bool m_available = false;
    bool m_enabled = false;
    bool m_active = false;
    int m_temperature = 4000;
    int m_minTemperature = 2500;
    int m_maxTemperature = 6500;
};

#endif // NIGHTLIGHT_H
