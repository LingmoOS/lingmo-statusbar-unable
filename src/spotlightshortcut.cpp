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

#include "spotlightshortcut.h"

#include <QFileSystemWatcher>
#include <QKeySequence>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>

static const QString SpotlightExec = QStringLiteral("lingmo-spotlight");

SpotlightShortcut::SpotlightShortcut(QObject *parent)
    : QObject(parent)
{
    reload();
    // lingmo-chotkeys or another status bar may change it
    auto *watcher = new QFileSystemWatcher(this);
    watcher->addPath(configPath());
    connect(watcher, &QFileSystemWatcher::fileChanged, this, [this, watcher] {
        watcher->addPath(configPath());   // QSettings replaces the file on save
        reload();
    });
}

QString SpotlightShortcut::configPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
           + QStringLiteral("/lingmoglobalshortcutsrc");
}

void SpotlightShortcut::reload()
{
    QSettings settings(configPath(), QSettings::IniFormat);
    QString found;
    for (const QString &group : settings.childGroups()) {
        if (settings.value(group + QStringLiteral("/Exec")).toString() == SpotlightExec) {
            found = group;
            break;
        }
    }
    if (found != m_shortcut) {
        m_shortcut = found;
        Q_EMIT shortcutChanged();
    }
}

QString SpotlightShortcut::setShortcut(const QString &sequence)
{
    const QString seq = QKeySequence(sequence).toString(QKeySequence::PortableText);
    if (seq.isEmpty())
        return tr("Invalid shortcut");

    QSettings settings(configPath(), QSettings::IniFormat);
    for (const QString &group : settings.childGroups()) {
        const QString exec = settings.value(group + QStringLiteral("/Exec")).toString();
        if (QKeySequence(group) == QKeySequence(seq) && exec != SpotlightExec)
            return tr("%1 is already used by %2").arg(seq, exec);
    }
    // Drop the old binding, then add the new one; lingmo-chotkeys picks it up
    for (const QString &group : settings.childGroups()) {
        if (settings.value(group + QStringLiteral("/Exec")).toString() == SpotlightExec)
            settings.remove(group);
    }
    settings.beginGroup(seq);
    settings.setValue(QStringLiteral("Comment"), QStringLiteral("Spotlight"));
    settings.setValue(QStringLiteral("Exec"), SpotlightExec);
    settings.endGroup();
    settings.sync();

    reload();
    return {};
}

QString SpotlightShortcut::sequenceFromKey(int key, int modifiers) const
{
    switch (key) {
    case Qt::Key_Control: case Qt::Key_Shift: case Qt::Key_Alt:
    case Qt::Key_Meta: case Qt::Key_Super_L: case Qt::Key_Super_R:
    case Qt::Key_AltGr: case 0:
        return {};
    }
    const QKeyCombination combo(Qt::KeyboardModifiers(modifiers) & ~Qt::KeypadModifier, Qt::Key(key));
    return QKeySequence(combo).toString(QKeySequence::PortableText);
}

void SpotlightShortcut::openSpotlight() const
{
    QProcess::startDetached(SpotlightExec, {});
}
