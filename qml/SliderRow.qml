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
import QtQuick.Controls
import QtQuick.Layouts
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Icon + slider (+ optional value and trailing item) on one row of a ControlCard
RowLayout {
    id: control

    property alias slider: _slider
    property alias iconSource: _icon.source
    property string valueText: ""
    default property alias trailing: _trailing.data

    signal iconClicked()

    spacing: LingmoUI.Units.largeSpacing
    implicitHeight: 36

    Item {
        Layout.preferredWidth: LingmoUI.Units.iconSizes.small
        Layout.preferredHeight: LingmoUI.Units.iconSizes.small

        Image {
            id: _icon
            anchors.fill: parent
            sourceSize: Qt.size(width, height)
            smooth: false
            antialiasing: true
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            onClicked: control.iconClicked()
        }
    }

    Slider {
        id: _slider
        Layout.fillWidth: true
        Layout.fillHeight: true
    }

    Label {
        visible: control.valueText !== ""
        text: control.valueText
        color: LingmoUI.Theme.disabledTextColor
        horizontalAlignment: Text.AlignRight
        Layout.preferredWidth: _metrics.advanceWidth("6500 K")

        FontMetrics { id: _metrics }
    }

    Item {
        id: _trailing
        visible: children.length > 0
        Layout.preferredWidth: childrenRect.width
        Layout.preferredHeight: childrenRect.height
    }
}
