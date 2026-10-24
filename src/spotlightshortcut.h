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

#pragma once

#include <QObject>
#include <QString>

// Spotlight's global shortcut, stored in lingmo-chotkeys' config
// (~/.config/lingmoglobalshortcutsrc: one [Key+Sequence] group per shortcut)
class SpotlightShortcut : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString shortcut READ shortcut NOTIFY shortcutChanged)

public:
    explicit SpotlightShortcut(QObject *parent = nullptr);

    QString shortcut() const { return m_shortcut; }

    // Returns an empty string when it worked, otherwise a message for the user
    Q_INVOKABLE QString setShortcut(const QString &sequence);
    // Portable text ("Ctrl+Space") for a key event, empty for a lone modifier
    Q_INVOKABLE QString sequenceFromKey(int key, int modifiers) const;
    Q_INVOKABLE void openSpotlight() const;

Q_SIGNALS:
    void shortcutChanged();

private:
    void reload();
    static QString configPath();

    QString m_shortcut;
};
