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

import QtQuick
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// A rounded group inside the control centre: a light card over the blurred panel
Item {
    id: control

    default property alias content: _content.data
    property real padding: LingmoUI.Units.largeSpacing
    property real verticalPadding: LingmoUI.Units.smallSpacing

    implicitHeight: _content.childrenRect.height + verticalPadding * 2

    Rectangle {
        anchors.fill: parent
        radius: LingmoUI.Theme.bigRadius
        // A raised pane on the glass (solid card without glass)
        color: LingmoUI.Theme.glassEnabled ? LingmoUI.Theme.glassRaisedColor : LingmoUI.Theme.secondBackgroundColor
        border.width: LingmoUI.Theme.glassEnabled ? 1 : 0
        border.color: LingmoUI.Theme.glassBorderColor
        opacity: LingmoUI.Theme.glassEnabled ? 1 : (LingmoUI.Theme.darkMode ? 0.45 : 0.7)

        Behavior on color {
            ColorAnimation { duration: 200; easing.type: Easing.Linear }
        }
    }

    Item {
        id: _content
        anchors.fill: parent
        anchors.leftMargin: control.padding
        anchors.rightMargin: control.padding
        anchors.topMargin: control.verticalPadding
        anchors.bottomMargin: control.verticalPadding
    }
}
