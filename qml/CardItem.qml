/*
 * Copyright (C) 2024 LingmoOS Team.
 *
 * Author:     Reion Wong <aj@lingmo.org>
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

import QtQuick 2.12
import QtQuick.Controls 2.12
import QtQuick.Layouts 1.12
import Qt5Compat.GraphicalEffects
import LingmoUI.CompatibleModule 3.0 as LingmoUI

Item {
    id: control

    property bool checked: false
    property alias icon: _image.source
    property alias label: _titleLabel.text

    signal clicked
    signal pressAndHold

    readonly property color _ink: LingmoUI.Theme.textColor
    property color backgroundColor: Qt.rgba(_ink.r, _ink.g, _ink.b, 0.08)
    property color hoverColor: Qt.rgba(_ink.r, _ink.g, _ink.b, 0.13)
    property color pressedColor: Qt.rgba(_ink.r, _ink.g, _ink.b, 0.18)

    property color highlightHoverColor: LingmoUI.Theme.darkMode ? Qt.lighter(LingmoUI.Theme.highlightColor, 1.1)
                                                                : Qt.darker(LingmoUI.Theme.highlightColor, 1.1)
    property color highlightPressedColor: LingmoUI.Theme.darkMode ? Qt.lighter(LingmoUI.Theme.highlightColor, 1.2)
                                                                  : Qt.darker(LingmoUI.Theme.highlightColor, 1.2)

    MouseArea {
        id: _mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: control.clicked()

        onPressedChanged: {
            imageItem.scale = pressed ? 0.95 : 1.0
        }

        onPressAndHold: {
            control.pressAndHold()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: LingmoUI.Units.smallSpacing / 2
        anchors.rightMargin: LingmoUI.Units.smallSpacing / 2
        spacing: LingmoUI.Units.smallSpacing

        Item {
            Layout.fillHeight: true
        }

        Item {
            id: imageItem
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44

            Layout.alignment: Qt.AlignHCenter

            Behavior on scale {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutSine
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: height / 2

                Behavior on color { ColorAnimation { duration: 120 } }

                color: {
                    if (control.checked) {
                        if (_mouseArea.pressed)
                            return highlightPressedColor
                        else if (_mouseArea.containsMouse)
                            return highlightHoverColor
                        else
                            return LingmoUI.Theme.highlightColor
                    } else {
                        if (_mouseArea.pressed)
                            return pressedColor
                        else if (_mouseArea.containsMouse)
                            return hoverColor
                        else
                            return backgroundColor
                    }
                }
            }

            Image {
                id: _image
                width: LingmoUI.Units.iconSizes.smallMedium
                height: width
                anchors.centerIn: parent
                sourceSize: Qt.size(width, height)
                asynchronous: true
                antialiasing: true
                smooth: true
            }
        }

        Label {
            id: _titleLabel
            color: LingmoUI.Theme.textColor
            font.pointSize: LingmoUI.Theme.fontSize * 0.9
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Qt.AlignHCenter
            Layout.fillWidth: true
            elide: Text.ElideMiddle
            visible: text
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
