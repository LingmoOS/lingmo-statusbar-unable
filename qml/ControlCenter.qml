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
import QtQuick.Window 2.12
import QtQuick.Layouts 1.12
import Qt5Compat.GraphicalEffects

import Lingmo.Accounts 1.0 as Accounts
import Lingmo.Bluez 1.0 as Bluez
import Lingmo.StatusBar 1.0
import Lingmo.Audio 1.0
import Lingmo.NetworkManagement 1.0 as NM
import LingmoUI.CompatibleModule 3.0 as LingmoUI

ControlCenterDialog {
    id: control

    width: 420
    height: _mainLayout.implicitHeight + LingmoUI.Units.largeSpacing * 2

    property var margin: 4 * Screen.devicePixelRatio
    property point position: Qt.point(0, 0)
    property var defaultSink: paSinkModel.defaultSink

    property bool bluetoothDisConnected: Bluez.Manager.bluetoothBlocked
    property var defaultSinkValue: defaultSink ? defaultSink.volume / PulseAudio.NormalVolume * 100.0 : -1

    // Airplane mode: NetworkManager's handler turns Wi-Fi, WWAN and Bluetooth off
    // together; the flag itself lives in lib_lingmo's Configuration (lingmoos/nm)
    property bool airplaneMode: false
    readonly property bool airplaneAvailable: enabledConnections.wirelessHwEnabled
                                              || enabledConnections.wwanHwEnabled
                                              || Bluez.Manager.adapters.length > 0

    property bool showSinkPicker: false

    property var borderColor: windowHelper.compositing ? LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.3)
                                                                  : Qt.rgba(0, 0, 0, 0.2) : LingmoUI.Theme.darkMode ? Qt.rgba(1, 1, 1, 0.15)
                                                                                                                  : Qt.rgba(0, 0, 0, 0.15)

    property var volumeIconName: {
        if (defaultSinkValue <= 0 || (defaultSink && defaultSink.muted))
            return "audio-volume-muted-symbolic"
        else if (defaultSinkValue <= 25)
            return "audio-volume-low-symbolic"
        else if (defaultSinkValue <= 75)
            return "audio-volume-medium-symbolic"
        else
            return "audio-volume-high-symbolic"
    }

    function iconPath(name, onAccent) {
        return "qrc:/images/" + (LingmoUI.Theme.darkMode || onAccent ? "dark/" : "light/") + name
    }

    onBluetoothDisConnectedChanged: {
        bluetoothItem.checked = !bluetoothDisConnected
    }

    onVisibleChanged: {
        if (visible) {
            control.airplaneMode = nmConfiguration.airplaneModeEnabled
        } else {
            control.showSinkPicker = false
        }
    }

    onWidthChanged: adjustCorrectLocation()
    onHeightChanged: adjustCorrectLocation()
    onPositionChanged: adjustCorrectLocation()

    color: "transparent"

    LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
    LayoutMirroring.childrenInherit: true

    Appearance {
        id: appearance
    }

    Notifications {
        id: notifications
    }

    PowerProfiles {
        id: powerProfiles
    }

    NM.Configuration {
        id: nmConfiguration
    }

    SinkModel {
        id: paSinkModel
    }

    function toggleBluetooth() {
        const enable = !control.bluetoothDisConnected
        Bluez.Manager.bluetoothBlocked = enable

        for (var i = 0; i < Bluez.Manager.adapters.length; ++i) {
            var adapter = Bluez.Manager.adapters[i]
            adapter.powered = enable
        }
    }

    function toggleAirplaneMode() {
        const enable = !control.airplaneMode
        nmHandler.enableAirplaneMode(enable)
        nmConfiguration.airplaneModeEnabled = enable
        control.airplaneMode = enable
    }

    function adjustCorrectLocation() {
        var posX = control.position.x
        var posY = control.position.y

        if (posX + control.width >= StatusBar.screenRect.x + StatusBar.screenRect.width)
            posX = StatusBar.screenRect.x + StatusBar.screenRect.width - control.width - control.margin

        posY = rootItem.y + rootItem.height + control.margin

        control.x = posX
        control.y = posY
    }

    Brightness {
        id: brightness
    }

    NightLight {
        id: nightLight
    }

    Accounts.UserAccount {
        id: currentUser
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

    FontMetrics {
        id: _fontMetrics
    }

    ColumnLayout {
        id: _mainLayout
        anchors.fill: parent
        anchors.margins: LingmoUI.Units.largeSpacing
        spacing: LingmoUI.Units.largeSpacing

        Item {
            id: topItem
            Layout.fillWidth: true
            implicitHeight: 32

            RowLayout {
                id: topItemLayout
                anchors.fill: parent
                anchors.rightMargin: LingmoUI.Units.smallSpacing
                spacing: LingmoUI.Units.largeSpacing

                Label {
                    leftPadding: LingmoUI.Units.smallSpacing
                    text: qsTr("Control Center")
                    font.bold: true
                    font.pointSize: LingmoUI.Theme.fontSize * 1.4
                    Layout.fillWidth: true
                }

                IconButton {
                    id: settingsButton
                    implicitWidth: topItem.height
                    implicitHeight: topItem.height
                    Layout.alignment: Qt.AlignVCenter
                    source: control.iconPath("settings.svg")
                    onLeftButtonClicked: {
                        control.visible = false
                        process.startDetached("lingmo-settings")
                    }
                }
            }
        }

        // Quick toggles
        ControlCard {
            id: cardItems
            Layout.fillWidth: true
            padding: 0
            verticalPadding: LingmoUI.Units.smallSpacing

            property real cellWidth: width / 4

            GridLayout {
                id: cardLayout
                width: parent.width
                columnSpacing: 0
                rowSpacing: 0
                columns: 4

                CardItem {
                    id: wirelessItem
                    Layout.preferredHeight: 96
                    Layout.preferredWidth: cardItems.cellWidth
                    icon: control.iconPath("network-wireless-connected-100.svg", checked)
                    visible: enabledConnections.wirelessHwEnabled
                    checked: enabledConnections.wirelessEnabled
                    label: activeConnection.wirelessName ? activeConnection.wirelessName : qsTr("Wi-Fi")
                    onClicked: nmHandler.enableWireless(!checked)
                    onPressAndHold: {
                        control.visible = false
                        process.startDetached("lingmo-settings", ["-m", "wlan"])
                    }
                }

                CardItem {
                    id: bluetoothItem
                    Layout.preferredHeight: 96
                    Layout.preferredWidth: cardItems.cellWidth
                    icon: control.iconPath("bluetooth-symbolic.svg", checked)
                    checked: !control.bluetoothDisConnected
                    label: qsTr("Bluetooth")
                    visible: Bluez.Manager.adapters.length
                    onClicked: control.toggleBluetooth()
                    onPressAndHold: {
                        control.visible = false
                        process.startDetached("lingmo-settings", ["-m", "bluetooth"])
                    }
                }

                CardItem {
                    id: darkModeItem
                    Layout.preferredHeight: 96
                    Layout.preferredWidth: cardItems.cellWidth
                    icon: control.iconPath("dark-mode.svg", checked)
                    checked: LingmoUI.Theme.darkMode
                    label: qsTr("Dark Mode")
                    onClicked: appearance.switchDarkMode(!LingmoUI.Theme.darkMode)
                }

                CardItem {
                    id: nightLightItem
                    Layout.preferredHeight: 96
                    Layout.preferredWidth: cardItems.cellWidth
                    icon: control.iconPath("night-light.svg", checked)
                    visible: nightLight.available
                    checked: nightLight.enabled
                    label: qsTr("Night Light")
                    onClicked: nightLight.enabled = !nightLight.enabled
                    onPressAndHold: {
                        control.visible = false
                        process.startDetached("lingmo-settings", ["-m", "display"])
                    }
                }

                CardItem {
                    Layout.preferredHeight: 96
                    Layout.preferredWidth: cardItems.cellWidth
                    icon: control.iconPath("do-not-disturb.svg", checked)
                    checked: notifications.doNotDisturb
                    label: qsTr("Do Not Disturb")
                    onClicked: notifications.doNotDisturb = !notifications.doNotDisturb
                }

                CardItem {
                    id: airplaneItem
                    Layout.preferredHeight: 96
                    Layout.preferredWidth: cardItems.cellWidth
                    icon: control.iconPath("airplane-mode.svg", checked)
                    visible: control.airplaneAvailable
                    checked: control.airplaneMode
                    label: qsTr("Airplane Mode")
                    onClicked: control.toggleAirplaneMode()
                }

                CardItem {
                    Layout.preferredHeight: 96
                    Layout.preferredWidth: cardItems.cellWidth
                    icon: control.iconPath("screenshot.svg", checked)
                    checked: false
                    label: qsTr("Screenshot")
                    onClicked: {
                        control.visible = false
                        process.startDetached("lingmo-screenshot", ["-d", "500"])
                    }
                }
            }
        }

        // Network: wired and VPN connections with an on/off switch each
        ControlCard {
            id: networkItem
            Layout.fillWidth: true
            visible: _networkRepeater.visibleCount > 0

            NM.NetworkModel {
                id: _networkModel
            }

            Column {
                id: _networkColumn
                width: parent.width
                spacing: 2

                Repeater {
                    id: _networkRepeater
                    model: _networkModel

                    // Number of rows shown (wired + VPN), to hide the card when empty
                    property int visibleCount: 0
                    function recount() {
                        var n = 0
                        for (var i = 0; i < count; ++i)
                            if (itemAt(i) && itemAt(i).shown) ++n
                        visibleCount = n
                    }
                    onItemAdded: recount()
                    onItemRemoved: recount()

                    delegate: RowLayout {
                        readonly property bool isVpn: model.type === NM.Enums.Vpn
                        readonly property bool shown: (model.type === NM.Enums.Wired || isVpn)
                                                      && !model.duplicate && model.connectionPath !== ""
                        readonly property bool active: model.connectionState === NM.Enums.Activated
                        readonly property bool busy: model.connectionState === NM.Enums.Activating
                                                     || model.connectionState === NM.Enums.Deactivating

                        visible: shown
                        width: _networkColumn.width
                        height: shown ? 36 : 0
                        spacing: LingmoUI.Units.largeSpacing

                        Image {
                            Layout.preferredWidth: LingmoUI.Units.iconSizes.small
                            Layout.preferredHeight: LingmoUI.Units.iconSizes.small
                            sourceSize: Qt.size(width, height)
                            source: control.iconPath((parent.isVpn ? "network-wired-activated" : "network-wired") + ".svg")
                            opacity: parent.active ? 1.0 : 0.5
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Label {
                                Layout.fillWidth: true
                                text: model.name
                                elide: Text.ElideRight
                                color: LingmoUI.Theme.textColor
                            }

                            Label {
                                Layout.fillWidth: true
                                text: parent.parent.busy ? qsTr("Connecting…")
                                      : parent.parent.isVpn ? qsTr("VPN") : qsTr("Wired")
                                font.pointSize: LingmoUI.Theme.fontSize * 0.85
                                color: LingmoUI.Theme.disabledTextColor
                            }
                        }

                        Switch {
                            checked: parent.active || parent.busy
                            enabled: !parent.busy
                            onToggled: {
                                if (checked)
                                    nmHandler.activateConnection(model.connectionPath, model.devicePath, model.specificPath)
                                else
                                    nmHandler.deactivateConnection(model.connectionPath, model.devicePath)
                            }
                        }

                        onShownChanged: _networkRepeater.recount()
                    }
                }
            }
        }

        // Media: only while a player has something playing (or paused mid-track)
        MprisItem {
            id: mprisItem
            Layout.fillWidth: true
            Layout.preferredHeight: 84
        }

        // Brightness, night light warmth, volume and output device
        ControlCard {
            id: slidersCard
            Layout.fillWidth: true
            visible: brightness.enabled || control.defaultSink || (nightLight.available && nightLight.enabled)

            ColumnLayout {
                width: parent.width
                spacing: 0

                SliderRow {
                    id: brightnessRow
                    Layout.fillWidth: true
                    visible: brightness.enabled
                    iconSource: control.iconPath("brightness.svg")

                    slider.from: 1
                    slider.to: 100
                    slider.stepSize: 1
                    slider.value: brightness.value
                    slider.onMoved: brightnessTimer.start()

                    Timer {
                        id: brightnessTimer
                        interval: 100
                        repeat: false
                        onTriggered: brightness.setValue(brightnessRow.slider.value)
                    }
                }

                // Night light warmth, while it is on (warmer to the right)
                SliderRow {
                    id: nightLightRow
                    Layout.fillWidth: true
                    visible: nightLight.available && nightLight.enabled
                    iconSource: control.iconPath("night-light.svg")
                    valueText: slider.value.toFixed(0) + " K"

                    slider.from: nightLight.maxTemperature
                    slider.to: nightLight.minTemperature
                    slider.stepSize: 100
                    slider.value: nightLight.temperature
                    slider.onMoved: nightLightTimer.start()

                    Timer {
                        id: nightLightTimer
                        interval: 100
                        repeat: false
                        onTriggered: nightLight.temperature = nightLightRow.slider.value
                    }
                }

                SliderRow {
                    id: volumeRow
                    Layout.fillWidth: true
                    visible: control.defaultSink
                    iconSource: control.iconPath(control.volumeIconName + ".svg")
                    onIconClicked: if (control.defaultSink) control.defaultSink.muted = !control.defaultSink.muted

                    slider.from: PulseAudio.MinimalVolume
                    slider.to: PulseAudio.NormalVolume
                    slider.stepSize: PulseAudio.NormalVolume / 100.0
                    slider.value: control.defaultSink ? control.defaultSink.volume : 0
                    slider.onMoved: {
                        if (!control.defaultSink)
                            return

                        control.defaultSink.volume = volumeRow.slider.value
                        control.defaultSink.muted = (volumeRow.slider.value === 0)
                    }

                    // Output device picker
                    IconButton {
                        id: sinkPickerButton
                        width: 28
                        height: 28
                        visible: _sinkRepeater.realCount > 1
                        rotation: control.showSinkPicker ? 180 : 0
                        source: control.iconPath("down.svg")
                        popupText: qsTr("Output device")
                        onLeftButtonClicked: control.showSinkPicker = !control.showSinkPicker

                        Behavior on rotation { NumberAnimation { duration: 150 } }
                    }
                }

                // Output devices (shown from the picker button)
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: visible ? LingmoUI.Units.smallSpacing : 0
                    visible: control.showSinkPicker && _sinkRepeater.realCount > 1
                    spacing: 2

                    Label {
                        text: qsTr("Output device")
                        color: LingmoUI.Theme.disabledTextColor
                        font.pointSize: LingmoUI.Theme.fontSize * 0.9
                        Layout.topMargin: LingmoUI.Units.smallSpacing / 2
                        Layout.bottomMargin: LingmoUI.Units.smallSpacing / 2
                    }

                    Repeater {
                        id: _sinkRepeater
                        model: paSinkModel

                        // Real (non-virtual) outputs, to know whether there is a choice
                        property int realCount: 0
                        function recount() {
                            var n = 0
                            for (var i = 0; i < count; ++i)
                                if (itemAt(i) && itemAt(i).real) ++n
                            realCount = n
                        }
                        onItemAdded: recount()
                        onItemRemoved: recount()

                        delegate: Item {
                            id: _sinkDelegate
                            readonly property var sink: model.PulseObject
                            readonly property bool isDefault: sink ? sink["default"] : false

                            Layout.fillWidth: true
                            implicitHeight: 32
                            readonly property bool real: sink ? !sink.virtualDevice : false
                            visible: real
                            onRealChanged: _sinkRepeater.recount()

                            Rectangle {
                                anchors.fill: parent
                                radius: LingmoUI.Theme.smallRadius
                                color: _sinkMouse.containsMouse ? Qt.rgba(LingmoUI.Theme.textColor.r,
                                                                          LingmoUI.Theme.textColor.g,
                                                                          LingmoUI.Theme.textColor.b, 0.08)
                                                                : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: LingmoUI.Units.smallSpacing
                                anchors.rightMargin: LingmoUI.Units.smallSpacing
                                spacing: LingmoUI.Units.smallSpacing

                                Rectangle {
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: _sinkDelegate.isDefault ? LingmoUI.Theme.highlightColor : "transparent"
                                    border.width: _sinkDelegate.isDefault ? 0 : 1
                                    border.color: LingmoUI.Theme.disabledTextColor
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: {
                                        if (!_sinkDelegate.sink)
                                            return ""
                                        var port = _sinkDelegate.sink.ports && _sinkDelegate.sink.ports.length > 1
                                                ? _sinkDelegate.sink.ports[_sinkDelegate.sink.activePortIndex] : null
                                        return port ? port.description + " · " + _sinkDelegate.sink.description
                                                    : _sinkDelegate.sink.description
                                    }
                                    elide: Text.ElideRight
                                    font.bold: _sinkDelegate.isDefault
                                    color: LingmoUI.Theme.textColor
                                }
                            }

                            MouseArea {
                                id: _sinkMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (_sinkDelegate.sink)
                                        _sinkDelegate.sink["default"] = true
                                }
                            }
                        }
                    }
                }
            }
        }

        // Battery and power profile
        ControlCard {
            id: powerCard
            Layout.fillWidth: true
            visible: battery.available || powerProfiles.available

            ColumnLayout {
                width: parent.width
                spacing: LingmoUI.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    visible: battery.available
                    spacing: LingmoUI.Units.largeSpacing

                    Image {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 16
                        sourceSize: Qt.size(22, 16)
                        source: control.iconPath(battery.iconSource)
                        asynchronous: true
                        antialiasing: true
                        smooth: false
                    }

                    Label {
                        text: battery.chargePercent + "%"
                        font.bold: true
                        color: LingmoUI.Theme.textColor
                    }

                    Label {
                        Layout.fillWidth: true
                        text: battery.statusString
                        elide: Text.ElideRight
                        color: LingmoUI.Theme.disabledTextColor
                    }

                    IconButton {
                        width: 28
                        height: 28
                        source: control.iconPath("settings.svg")
                        popupText: qsTr("Battery settings")
                        onLeftButtonClicked: {
                            control.visible = false
                            process.startDetached("lingmo-settings", ["-m", "battery"])
                        }
                    }
                }

                // power-profiles-daemon: segmented choice
                Rectangle {
                    id: profileBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    Layout.topMargin: battery.available ? 0 : LingmoUI.Units.smallSpacing
                    Layout.bottomMargin: LingmoUI.Units.smallSpacing
                    visible: powerProfiles.available
                    radius: LingmoUI.Theme.smallRadius
                    color: Qt.rgba(LingmoUI.Theme.textColor.r, LingmoUI.Theme.textColor.g,
                                   LingmoUI.Theme.textColor.b, 0.06)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 2
                        spacing: 2

                        Repeater {
                            model: powerProfiles.profiles

                            delegate: Rectangle {
                                readonly property bool current: powerProfiles.activeProfile === modelData

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: LingmoUI.Theme.smallRadius - 2
                                color: current ? LingmoUI.Theme.highlightColor
                                               : _profileMouse.containsMouse ? Qt.rgba(LingmoUI.Theme.textColor.r,
                                                                                      LingmoUI.Theme.textColor.g,
                                                                                      LingmoUI.Theme.textColor.b, 0.08)
                                                                             : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Label {
                                    anchors.centerIn: parent
                                    text: modelData === "power-saver" ? qsTr("Power Saver")
                                        : modelData === "performance" ? qsTr("Performance")
                                        : qsTr("Balanced")
                                    color: parent.current ? LingmoUI.Theme.highlightedTextColor : LingmoUI.Theme.textColor
                                    font.pointSize: LingmoUI.Theme.fontSize * 0.95
                                }

                                MouseArea {
                                    id: _profileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: powerProfiles.activeProfile = modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
