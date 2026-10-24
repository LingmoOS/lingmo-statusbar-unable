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

#ifndef KEYBOARDLAYOUT_H
#define KEYBOARDLAYOUT_H

#include <QObject>
#include <QStringList>
#include <QDBusInterface>

// Keyboard layouts from lingmo-settings-daemon (/Keyboard)
class KeyboardLayout : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList shortNames READ shortNames NOTIFY layoutsChanged)
    Q_PROPERTY(QStringList descriptions READ descriptions NOTIFY layoutsChanged)
    Q_PROPERTY(int count READ count NOTIFY layoutsChanged)
    Q_PROPERTY(int currentIndex READ currentIndex WRITE setCurrentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(QString currentName READ currentName NOTIFY currentIndexChanged)
    Q_PROPERTY(QString currentDescription READ currentDescription NOTIFY currentIndexChanged)

public:
    explicit KeyboardLayout(QObject *parent = nullptr);

    QStringList shortNames() const { return m_shortNames; }
    QStringList descriptions() const { return m_descriptions; }
    int count() const { return m_shortNames.size(); }
    int currentIndex() const { return m_currentIndex; }
    QString currentName() const { return m_shortNames.value(m_currentIndex); }
    QString currentDescription() const { return m_descriptions.value(m_currentIndex); }

    void setCurrentIndex(int index);
    Q_INVOKABLE void next();

signals:
    void layoutsChanged();
    void currentIndexChanged();

private slots:
    void reload();
    void onCurrentIndexChanged(int index);

private:
    QDBusInterface m_iface;
    QStringList m_shortNames;
    QStringList m_descriptions;
    int m_currentIndex = 0;
};

#endif // KEYBOARDLAYOUT_H
