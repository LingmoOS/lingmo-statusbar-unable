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

import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Layouts

import Lingmo.StatusBar 1.0
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// Month calendar under the clock
ControlCenterDialog {
    id: control

    width: 300
    height: _mainLayout.implicitHeight + LingmoUI.Units.largeSpacing * 2
    color: "transparent"

    property real margin: 4 * Screen.devicePixelRatio
    property date today: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()

    property var borderColor: windowHelper.compositing ? LingmoUI.Theme.darkMode ? Qt.rgba(255, 255, 255, 0.3)
                                                                  : Qt.rgba(0, 0, 0, 0.2) : LingmoUI.Theme.darkMode ? Qt.rgba(255, 255, 255, 0.15)
                                                                                                                  : Qt.rgba(0, 0, 0, 0.15)

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // Opens centred under `item`, kept inside the bar's screen; closes when already open
    function toggle(item) {
        if (control.visible) {
            control.close()
            return
        }

        control.today = new Date()
        control.showToday()

        var pos = item.mapToGlobal(0, 0)
        var screen = StatusBar.screenRect
        var posX = pos.x + item.width / 2 - control.width / 2
        posX = Math.min(posX, screen.x + screen.width - control.width - control.margin)
        posX = Math.max(posX, screen.x + control.margin)

        control.x = posX
        control.y = pos.y + item.height + control.margin
        control.open()
    }

    function showToday() {
        control.month = control.today.getMonth()
        control.year = control.today.getFullYear()
    }

    function shiftMonth(delta) {
        var m = control.month + delta
        control.year += Math.floor(m / 12)
        control.month = (m % 12 + 12) % 12
    }

    LingmoUI.WindowHelper {
        id: windowHelper
    }

    LingmoUI.WindowShadow {
        view: control
        geometry: Qt.rect(control.x, control.y, control.width, control.height)
        radius: _background.radius
    }

    // "Vidro Lingmo" (Settings > Appearance > Glass); solid without glass
    LingmoUI.GlassSurface {
        id: _background
        anchors.fill: parent
        radius: LingmoUI.Theme.compositing ? LingmoUI.Theme.bigRadius * 1.5 : 0
    }

    component NavButton: Item {
        id: navButton
        property alias text: _navLabel.text
        signal clicked

        implicitWidth: 28
        implicitHeight: 28

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: _navArea.containsPress ? (LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(0, 0, 0, 0.2))
                 : _navArea.containsMouse ? (LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(0, 0, 0, 0.1))
                 : "transparent"
        }

        Label {
            id: _navLabel
            anchors.centerIn: parent
            font.pointSize: 14
            color: LingmoUI.Theme.textColor
        }

        MouseArea {
            id: _navArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: navButton.clicked()
        }
    }

    ColumnLayout {
        id: _mainLayout
        x: LingmoUI.Units.largeSpacing
        y: LingmoUI.Units.largeSpacing
        width: control.width - LingmoUI.Units.largeSpacing * 2
        spacing: LingmoUI.Units.smallSpacing

        // e.g. "sábado, 26 de setembro de 2026"
        Label {
            Layout.fillWidth: true
            leftPadding: LingmoUI.Units.smallSpacing
            text: {
                var s = control.today.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                return s.charAt(0).toUpperCase() + s.slice(1)
            }
            font.bold: true
            font.pointSize: 12
            elide: Text.ElideRight
            color: LingmoUI.Theme.textColor
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: LingmoUI.Units.smallSpacing
            spacing: 0

            Label {
                Layout.fillWidth: true
                leftPadding: LingmoUI.Units.smallSpacing
                text: {
                    var name = Qt.locale().standaloneMonthName(control.month, Locale.LongFormat)
                    return name.charAt(0).toUpperCase() + name.slice(1) + " " + control.year
                }
                font.pointSize: 11
                color: LingmoUI.Theme.textColor
            }

            Label {
                id: _todayButton
                text: qsTr("Today")
                visible: control.month !== control.today.getMonth() || control.year !== control.today.getFullYear()
                color: LingmoUI.Theme.highlightColor
                rightPadding: LingmoUI.Units.smallSpacing

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: control.showToday()
                }
            }

            NavButton {
                text: LayoutMirroring.enabled ? "›" : "‹"
                onClicked: control.shiftMonth(-1)
            }

            NavButton {
                text: LayoutMirroring.enabled ? "‹" : "›"
                onClicked: control.shiftMonth(1)
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: Qt.locale()

            delegate: Label {
                text: model.shortName.replace(".", "").charAt(0).toUpperCase() + model.shortName.replace(".", "").slice(1, 3)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pointSize: 9
                color: LingmoUI.Theme.disabledTextColor
            }
        }

        MonthGrid {
            id: _grid
            Layout.fillWidth: true
            Layout.preferredHeight: 6 * 36
            locale: Qt.locale()
            month: control.month
            year: control.year
            spacing: 0

            delegate: Item {
                readonly property bool isToday: model.today
                readonly property bool inMonth: model.month === _grid.month

                implicitWidth: 36
                implicitHeight: 36

                Rectangle {
                    anchors.centerIn: parent
                    width: 30
                    height: 30
                    radius: width / 2
                    color: parent.isToday ? LingmoUI.Theme.highlightColor : "transparent"
                }

                Label {
                    anchors.centerIn: parent
                    text: model.day
                    font.bold: parent.isToday
                    color: parent.isToday ? LingmoUI.Theme.highlightedTextColor : LingmoUI.Theme.textColor
                    opacity: parent.inMonth ? 1.0 : 0.35
                }
            }

            // Wheel over the days changes month
            WheelHandler {
                property int delta: 0
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) {
                    // One month per notch; touchpads send many small steps
                    delta += event.angleDelta.y
                    if (Math.abs(delta) >= 120) {
                        control.shiftMonth(delta > 0 ? -1 : 1)
                        delta = 0
                    }
                }
            }
        }
    }
}
