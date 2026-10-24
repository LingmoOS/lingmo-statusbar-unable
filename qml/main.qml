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
import QtQuick.Layouts 1.12
import QtQuick.Controls 2.12
import QtQuick.Window 2.12

import Lingmo.StatusBar 1.0
import Lingmo.NetworkManagement 1.0 as NM
import LingmoUI.CompatibleModule 3.0 as LingmoUI

import "island"

Item {
    id: rootItem

    // Every status icon is 16 px and sits in a cell of the same width, so the
    // icons on the right keep an even rhythm whatever they are
    property int iconSize: LingmoUI.Units.iconSizes.small
    property int cellWidth: iconSize + LingmoUI.Units.largeSpacing

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    // Follows the system theme (the wallpaper-driven colour logic was never ported)
    property bool darkMode: LingmoUI.Theme.darkMode
    property color textColor: LingmoUI.Theme.textColor
    property real fontSize: LingmoUI.Theme.fontSize

    property var timeFormat: StatusBar.twentyFourTime ? "HH:mm" : "h:mm ap"

    onTimeFormatChanged: {
        timeTimer.restart()
    }

    // TODO: Fix ME!
    // System.Wallpaper {
    //     id: sysWallpaper

    //     function reload() {
    //         if (sysWallpaper.type === 0)
    //             bgHelper.setBackgound(sysWallpaper.path)
    //         else
    //             bgHelper.setColor(sysWallpaper.color)
    //     }

    //     Component.onCompleted: sysWallpaper.reload()

    //     onTypeChanged: sysWallpaper.reload()
    //     onColorChanged: sysWallpaper.reload()
    //     onPathChanged: sysWallpaper.reload()
    // }

    // BackgroundHelper {
    //     id: bgHelper

    //     onNewColor: {
    //         background.color = color
    //         rootItem.darkMode = darkMode
    //     }
    // }

    // "Vidro Lingmo" (Settings > Appearance > Glass): tint, grain and soft light
    // over KWin's blur of the wallpaper; a solid bar with Glass off or without
    // a compositor. The tint is never thinner than 0.72 here so the text keeps
    // its contrast over any wallpaper.
    LingmoUI.GlassSurface {
        id: background
        anchors.fill: parent
        radius: 0
        borderVisible: false
        highlightVisible: false
        sheenEnabled: false
        tintOpacity: Math.max(LingmoUI.Theme.glassOpacity, rootItem.darkMode ? 0.62 : 0.66)
    }

    // Hairline separating the bar from the desktop
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.rgba(rootItem.textColor.r, rootItem.textColor.g, rootItem.textColor.b,
                       rootItem.darkMode ? 0.1 : 0.08)
    }

    LingmoUI.WindowHelper {
        id: windowHelper
    }

    LingmoUI.PopupTips {
        id: popupTips
    }

    // The app menu: the bold app name at the left opens it
    LingmoUI.DesktopMenu {
        id: acticityMenu

        MenuItem {
            text: qsTr("Minimize")
            icon.name: "window-minimize"
            onTriggered: acticity.minimize()
        }

        MenuItem {
            text: qsTr("Maximize / Restore")
            icon.name: "window-maximize"
            onTriggered: acticity.toggleMaximize()
        }

        MenuSeparator {}

        MenuItem {
            text: acticity.title ? qsTr("Quit %1").arg(acticity.title) : qsTr("Close")
            icon.name: "window-close"
            onTriggered: acticity.close()
        }
    }

    // Main layout
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: LingmoUI.Units.smallSpacing
        anchors.rightMargin: LingmoUI.Units.smallSpacing
        spacing: 0

        // App name (bold) — opens the app menu
        StandardItem {
            id: acticityItem
            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: Math.min(rootItem.width / 3,
                                            acticityLayout.implicitWidth + LingmoUI.Units.largeSpacing)
            visible: acticity.title !== ""
            checked: acticityMenu.visible
            onClicked: function(mouse) {
                if (mouse.button !== Qt.MiddleButton)
                    acticityMenu.open()
            }

            RowLayout {
                id: acticityLayout
                anchors.fill: parent
                anchors.leftMargin: LingmoUI.Units.smallSpacing
                anchors.rightMargin: LingmoUI.Units.smallSpacing
                spacing: LingmoUI.Units.smallSpacing

                Image {
                    id: acticityIcon
                    width: rootItem.iconSize
                    height: rootItem.iconSize
                    sourceSize: Qt.size(rootItem.iconSize,
                                        rootItem.iconSize)
                    source: acticity.icon ? "image://icontheme/" + acticity.icon : ""
                    visible: status === Image.Ready
                    antialiasing: true
                    smooth: false
                }

                Label {
                    id: acticityLabel
                    text: acticity.title
                    Layout.fillWidth: true
                    elide: Qt.ElideRight
                    color: rootItem.textColor
                    visible: text
                    Layout.alignment: Qt.AlignVCenter
                    font.pointSize: rootItem.fontSize
                    font.bold: true
                }
            }
        }

        // App menu
        Item {
            id: appMenuItem
            Layout.fillHeight: true
            Layout.fillWidth: true

            ListView {
                id: appMenuView
                anchors.fill: parent
                // Stop before the Island in the middle of the bar
                // (mirrored with RTL: then it keeps clear of the Island's other side)
                anchors.rightMargin: !island.visible ? 0
                    : rootItem.LayoutMirroring.enabled
                      ? Math.max(0, island.x + island.width + LingmoUI.Units.smallSpacing
                                    - (LingmoUI.Units.smallSpacing + appMenuItem.x))
                      : Math.max(0, LingmoUI.Units.smallSpacing + appMenuItem.x + appMenuItem.width
                                    - island.x + LingmoUI.Units.smallSpacing)
                orientation: Qt.Horizontal
                spacing: LingmoUI.Units.smallSpacing
                visible: appMenuModel.visible
                interactive: false
                clip: true

                model: appMenuModel

                // Initialize the current index
                onVisibleChanged: {
                    if (!visible)
                        appMenuView.currentIndex = -1
                }

                delegate: StandardItem {
                    id: _menuItem
                    width: _actionText.width + LingmoUI.Units.largeSpacing
                    height: ListView.view.height
                    checked: appMenuApplet.currentIndex === index

                    onClicked: {
                        appMenuApplet.trigger(_menuItem, index)

                        checked = Qt.binding(function() {
                            return appMenuApplet.currentIndex === index
                        })
                    }

                    Text {
                        id: _actionText
                        anchors.centerIn: parent
                        color: rootItem.textColor
                        font.pointSize: rootItem.fontSize
                        text: {
                            var text = activeMenu
                            text = text.replace(/([^&]*)&(.)([^&]*)/g, function (match, p1, p2, p3) {
                                return p1.concat(p2, p3)
                            })
                            return text
                        }
                    }

                    // QMenu opens on press, so we'll replicate that here
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: appMenuApplet.currentIndex !== -1
                        onPressed: parent.clicked(null)
                        onEntered: parent.clicked(null)
                    }
                }

                AppMenuModel {
                    id: appMenuModel
                    onRequestActivateIndex: appMenuApplet.requestActivateIndex(appMenuView.currentIndex)
                    Component.onCompleted: {
                        appMenuView.model = appMenuModel
                    }
                }

                AppMenuApplet {
                    id: appMenuApplet
                    model: appMenuModel
                }

                Component.onCompleted: {
                    appMenuApplet.buttonGrid = appMenuView

                    // Handle left and right shortcut keys.
                    appMenuApplet.requestActivateIndex.connect(function (index) {
                        var idx = Math.max(0, Math.min(appMenuView.count - 1, index))
                        var button = appMenuView.itemAtIndex(index)
                        if (button) {
                            button.clicked(null)
                        }
                    });

                    // Handle mouse movement.
                    appMenuApplet.mousePosChanged.connect(function (x, y) {
                        var item = itemAt(x, y)
                        if (item)
                            item.clicked(null)
                    });
                }
            }
        }
        StandardItem {
            id: lyricsItem
            visible: lyricsHelper.lyricsVisible
            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: _lyricsLayout.implicitWidth + LingmoUI.Units.smallSpacing

            RowLayout {
                id: _lyricsLayout
                anchors.fill: parent

                Label {
                    id: lyricsLabel
                    Layout.alignment: Qt.AlignCenter
                    font.pointSize: rootItem.fontSize
                    color: rootItem.textColor
                    text: lyricsHelper.lyrics
                    }
                }
         }
        // System tray(Right)
        SystemTray {}

        StandardItem {
            id: permissionSurveillanceItem
            visible: permissionSurveillance.permissionSurveillanceVisible
            backcolor: "#ee7959"
            backColorEnabled: true
            checked: true
            popupText: permissionSurveillance.cameraUser + " " + qsTr("is using the camera")
            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: rootItem.cellWidth
            Image {
                id: permissionSurveillanceIcon
                anchors.centerIn: parent
                width: rootItem.iconSize
                height: width
                sourceSize: Qt.size(width, height)
                source: "qrc:/images/dark/camera.svg"
                asynchronous: true
                antialiasing: true
                smooth: false
            }
        }

        // Spotlight: click opens it, right click lets the user change its shortcut
        StandardItem {
            id: spotlightItem
            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: rootItem.cellWidth
            popupText: qsTr("Spotlight") + (spotlightShortcut.shortcut ? " (" + spotlightShortcut.shortcut + ")" : "")

            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton)
                    spotlightMenu.open()
                else
                    spotlightShortcut.openSpotlight()
            }

            // Magnifier glyph in the bar's text colour
            Item {
                anchors.centerIn: parent
                width: rootItem.iconSize
                height: width

                Rectangle {
                    x: 1; y: 1
                    width: parent.width * 0.62; height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.6
                    border.color: rootItem.textColor
                }
                Rectangle {
                    width: parent.width * 0.36; height: 1.8; radius: 0.9
                    x: parent.width * 0.52; y: parent.height * 0.70
                    rotation: 45
                    transformOrigin: Item.Left
                    color: rootItem.textColor
                    antialiasing: true
                }
            }
        }

        // Keyboard layout: click switches to the next one, right click lists them
        StandardItem {
            id: keyboardItem
            visible: keyboardLayout.count > 1
            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: Math.max(_layoutLabel.implicitWidth + LingmoUI.Units.largeSpacing, rootItem.cellWidth)
            popupText: keyboardLayout.currentDescription

            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton)
                    keyboardMenu.open()
                else
                    keyboardLayout.next()
            }

            Label {
                id: _layoutLabel
                anchors.centerIn: parent
                text: keyboardLayout.currentName
                font.pointSize: rootItem.fontSize
                font.bold: true
                color: rootItem.textColor
            }
        }

        StandardItem {
            id: controler

            checked: controlCenter.item.visible
            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: _controlerLayout.implicitWidth + LingmoUI.Units.largeSpacing

            onClicked: {
                toggleDialog()
            }

            function toggleDialog() {
                if (controlCenter.item.visible)
                    controlCenter.item.close()
                else {
                    // 先初始化，用户可能会通过Alt鼠标左键移动位置
                    controlCenter.item.position = Qt.point(0, 0)
                    controlCenter.item.position = mapToGlobal(0, 0)
                    controlCenter.item.open()
                }
            }

            RowLayout {
                id: _controlerLayout
                anchors.fill: parent
                anchors.leftMargin: LingmoUI.Units.smallSpacing
                anchors.rightMargin: LingmoUI.Units.smallSpacing

                spacing: LingmoUI.Units.largeSpacing

                Image {
                    id: volumeIcon
                    visible: controlCenter.item.defaultSink
                    source: "qrc:/images/" + (rootItem.darkMode ? "dark/" : "light/") + controlCenter.item.volumeIconName + ".svg"
                    width: rootItem.iconSize
                    height: width
                    sourceSize: Qt.size(width, height)
                    asynchronous: true
                    Layout.alignment: Qt.AlignCenter
                    antialiasing: true
                    smooth: false
                }

                // Network: wired, Wi-Fi (signal strength) or disconnected, plus a VPN badge
                RowLayout {
                    spacing: 3
                    Layout.alignment: Qt.AlignCenter

                    Image {
                        id: networkIcon
                        width: rootItem.iconSize
                        height: width
                        sourceSize: Qt.size(width, height)
                        source: "qrc:/images/" + (rootItem.darkMode ? "dark/" : "light/") + activeConnection.networkIcon + ".svg"
                        asynchronous: true
                        Layout.alignment: Qt.AlignCenter
                        opacity: activeConnection.connectionType === "none" ? 0.45 : 1.0
                        antialiasing: true
                        smooth: false
                    }

                    Rectangle {
                        visible: activeConnection.vpnActive
                        Layout.alignment: Qt.AlignCenter
                        implicitWidth: _vpnLabel.implicitWidth + 8
                        implicitHeight: _vpnLabel.implicitHeight + 2
                        radius: 3
                        color: "transparent"
                        border.width: 1
                        border.color: rootItem.textColor

                        Label {
                            id: _vpnLabel
                            anchors.centerIn: parent
                            text: "VPN"
                            font.pointSize: Math.max(6, rootItem.fontSize - 3)
                            font.bold: true
                            color: rootItem.textColor
                        }
                    }
                }

                // Battery Item
                RowLayout {
                    visible: battery.available

                    Image {
                        id: batteryIcon
                        // Battery glyphs are wider than tall: 16 px high like the others
                        height: rootItem.iconSize
                        width: Math.round(height * 1.375)
                        sourceSize: Qt.size(width, height)
                        source: "qrc:/images/" + (rootItem.darkMode ? "dark/" : "light/") + battery.iconSource
                        Layout.alignment: Qt.AlignCenter
                        antialiasing: true
                        smooth: false
                    }

                    Label {
                        text: battery.chargePercent + "%"
                        font.pointSize: rootItem.fontSize
                        color: rootItem.textColor
                        visible: battery.showPercentage
                    }
                }
            }
        }

        StandardItem {
            id: shutdownItem

            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: rootItem.cellWidth
            checked: shutdownDialog.item.visible

            onClicked: {
                shutdownDialog.item.position = Qt.point(0, 0)
                shutdownDialog.item.position = mapToGlobal(0, 0)
                shutdownDialog.item.open()
            }

            Image {
                id: shutdownIcon
                anchors.centerIn: parent
                width: rootItem.iconSize
                height: width
                sourceSize: Qt.size(width, height)
                source: "qrc:/images/" + (rootItem.darkMode ? "dark/" : "light/") + "system-shutdown-symbolic.svg"
                asynchronous: true
                antialiasing: true
                smooth: false
            }
        }

        // Notification center
        StandardItem {
            id: notificationItem

            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: Math.max(_bellItem.implicitWidth + LingmoUI.Units.largeSpacing, rootItem.cellWidth)

            onClicked: {
                process.startDetached("lingmo-notificationd", ["-s"])
            }

            // Notification bell: count badge, or the do-not-disturb icon
            Item {
                id: _bellItem
                anchors.centerIn: parent
                implicitWidth: rootItem.iconSize + (_badge.visible ? _badge.width / 2 : 0)
                implicitHeight: rootItem.iconSize
                width: implicitWidth
                height: implicitHeight

                Image {
                    id: _bell
                    width: rootItem.iconSize
                    height: width
                    sourceSize: Qt.size(width, height)
                    source: "qrc:/images/" + (rootItem.darkMode ? "dark/" : "light/")
                            + (notificationState.doNotDisturb ? "do-not-disturb.svg"
                               : notificationState.count > 0 ? "notification-new-symbolic.svg"
                               : "notification-symbolic.svg")
                    asynchronous: true
                    antialiasing: true
                    smooth: false
                }

                Rectangle {
                    id: _badge
                    visible: notificationState.count > 0 && !notificationState.doNotDisturb
                    anchors.left: _bell.horizontalCenter
                    anchors.top: _bell.top
                    anchors.topMargin: -3
                    height: 13
                    width: Math.max(height, _badgeText.implicitWidth + 7)
                    radius: height / 2
                    color: LingmoUI.Theme.redColor

                    Label {
                        id: _badgeText
                        anchors.centerIn: parent
                        text: notificationState.count > 99 ? "99+" : notificationState.count
                        font.pointSize: Math.max(6, rootItem.fontSize - 3)
                        font.bold: true
                        color: LingmoUI.Theme.highlightedTextColor
                    }
                }
            }
        }

        // Date and time: click shows the calendar
        StandardItem {
            id: datetimeItem

            animationEnabled: true
            Layout.fillHeight: true
            Layout.preferredWidth: timeLabel.implicitWidth + LingmoUI.Units.largeSpacing
            Layout.leftMargin: LingmoUI.Units.smallSpacing / 2
            checked: calendarPopup.item ? calendarPopup.item.visible : false

            onClicked: {
                if (calendarPopup.item)
                    calendarPopup.item.toggle(datetimeItem)
            }

            Label {
                id: timeLabel
                anchors.centerIn: parent
                font.pointSize: rootItem.fontSize
                font.weight: Font.Medium
                color: rootItem.textColor

                Timer {
                    id: timeTimer
                    interval: 1000
                    repeat: true
                    running: true
                    triggeredOnStart: true
                    onTriggered: {
                        // Date and time in the system language, e.g. "qui 16 out 14:32"
                        const now = new Date()
                        const date = now.toLocaleDateString(Qt.locale(), "ddd d MMM").replace(/\./g, "")
                        const time = now.toLocaleTimeString(Qt.locale(), StatusBar.twentyFourTime ? rootItem.timeFormat
                                                                                                : Locale.ShortFormat)
                        timeLabel.text = date + " " + time
                    }
                }
            }
        }

    }

    // Island: live activities (timers, recording, music, copies...) in the middle
    Island {
        id: island
        anchors.centerIn: parent
        barHeight: rootItem.height
    }

    MouseArea {
        id: _sliding
        anchors.fill: parent
        z: -1

        property int startY: -1
        property bool activated: false

        onActivatedChanged: {
            // TODO
            // if (activated)
            //     acticity.move()
        }

        onPressed: {
            startY = mouse.y
        }

        onReleased: {
            startY = -1
        }

        onDoubleClicked: {
            acticity.toggleMaximize()
        }

        onMouseYChanged: {
            if (startY === parseInt(mouse.y)) {
                activated = false
                return
            }

            // Up
            if (startY > parseInt(mouse.y)) {
                activated = false
                return
            }

            if (mouse.y > rootItem.height)
                activated = true
            else
                activated = false
        }
    }

    // Components
    Loader {
        id: controlCenter
        sourceComponent: ControlCenter {}
        asynchronous: true
    }

    Loader {
        id: calendarPopup
        sourceComponent: CalendarPopup {}
        asynchronous: true
    }

    Loader {
        id: shutdownDialog
        sourceComponent: ShutdownDialog {}
        asynchronous: true
    }

    // Spotlight shortcut (stored in lingmo-chotkeys' config)
    SpotlightShortcut {
        id: spotlightShortcut
    }

    LingmoUI.DesktopMenu {
        id: spotlightMenu

        MenuItem {
            text: qsTr("Open Spotlight")
            icon.name: "system-search"
            onTriggered: spotlightShortcut.openSpotlight()
        }

        MenuItem {
            enabled: false
            text: qsTr("Shortcut: %1").arg(spotlightShortcut.shortcut || qsTr("none"))
        }

        MenuItem {
            text: qsTr("Change shortcut…")
            icon.name: "preferences-desktop-keyboard-shortcuts"
            onTriggered: shortcutDialog.show()
        }
    }

    // Small window that records the next key combination
    Window {
        id: shortcutDialog
        width: 360
        height: 170
        flags: Qt.Dialog | Qt.WindowStaysOnTopHint
        title: qsTr("Spotlight shortcut")
        color: LingmoUI.Theme.backgroundColor

        property string captured: ""
        property string error: ""

        function show() {
            captured = ""
            error = ""
            x = Screen.virtualX + (Screen.width - width) / 2
            y = Screen.virtualY + Screen.height / 3
            visible = true
            requestActivate()
            _capture.forceActiveFocus()
        }

        Item {
            id: _capture
            anchors.fill: parent
            focus: true

            Keys.onPressed: function(event) {
                event.accepted = true
                if (event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier) {
                    shortcutDialog.close()
                    return
                }
                var seq = spotlightShortcut.sequenceFromKey(event.key, event.modifiers)
                if (seq !== "") {
                    shortcutDialog.captured = seq
                    shortcutDialog.error = ""
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 12
                width: parent.width - 40

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: qsTr("Press the new key combination for Spotlight")
                    color: rootItem.textColor
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    font.pointSize: rootItem.fontSize * 1.6
                    font.bold: true
                    text: shortcutDialog.captured || spotlightShortcut.shortcut || "…"
                    color: shortcutDialog.captured ? LingmoUI.Theme.highlightColor : rootItem.textColor
                }

                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: shortcutDialog.error !== ""
                    text: shortcutDialog.error
                    color: LingmoUI.Theme.redColor
                    wrapMode: Text.WordWrap
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Button {
                        text: qsTr("Cancel")
                        onClicked: shortcutDialog.close()
                    }

                    Button {
                        text: qsTr("Save")
                        enabled: shortcutDialog.captured !== ""
                        onClicked: {
                            var err = spotlightShortcut.setShortcut(shortcutDialog.captured)
                            if (err === "")
                                shortcutDialog.close()
                            else
                                shortcutDialog.error = err
                        }
                    }
                }
            }
        }
    }

    KeyboardLayout {
        id: keyboardLayout
    }

    LingmoUI.DesktopMenu {
        id: keyboardMenu

        Repeater {
            model: keyboardLayout.shortNames

            MenuItem {
                text: keyboardLayout.descriptions[index] || modelData
                checkable: true
                checked: index === keyboardLayout.currentIndex
                onTriggered: keyboardLayout.currentIndex = index
            }
        }

        MenuSeparator {}

        MenuItem {
            text: qsTr("Keyboard settings…")
            onTriggered: process.startDetached("lingmo-settings", ["-m", "keyboard"])
        }
    }

    // Notification center state (count, do not disturb) from lingmo-notificationd
    Notifications {
        id: notificationState
    }

    // NetworkManager state (Lingmo.NetworkManagement from lib_lingmo)
    NM.ActiveConnection {
        id: activeConnection
    }

    NM.EnabledConnections {
        id: enabledConnections
    }

    NM.Handler {
        id: nmHandler
    }
}
