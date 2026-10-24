/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

import LingmoUI.CompatibleModule 3.0 as LingmoUI

// The card's contents: the main activity in full, its controls, and the
// other activities as a short list
ColumnLayout {
    id: control

    property var island
    property var card

    readonly property var activity: island.primary
    readonly property color accent: island.accentFor(activity)
    readonly property bool finishing: !!activity && activity.finishing
    readonly property bool hasProgress: !!activity && !finishing && (activity.progress >= 0 || activity.indeterminate)

    spacing: LingmoUI.Units.largeSpacing

    // ------------------------------------------------------------------
    // Header: artwork or icon, title, subtitle, live value
    // ------------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: LingmoUI.Units.largeSpacing

        Item {
            id: _tile
            Layout.alignment: Qt.AlignTop
            implicitWidth: 48
            implicitHeight: 48

            readonly property bool hasArt: !!control.activity && !!control.activity.artUrl && !control.finishing
                                           && _artSource.status === Image.Ready

            // Icon on a tile tinted with the activity's colour
            Rectangle {
                anchors.fill: parent
                radius: LingmoUI.Theme.bigRadius
                visible: !_tile.hasArt
                color: Qt.rgba(control.accent.r, control.accent.g, control.accent.b,
                               LingmoUI.Theme.darkMode ? 0.22 : 0.14)

                LingmoUI.IconItem {
                    anchors.centerIn: parent
                    width: LingmoUI.Units.iconSizes.medium - 4
                    height: width
                    source: control.island.iconFor(control.activity)
                    color: control.island.iconTint(control.activity)
                }

                // Recording: the red dot on the tile
                Rectangle {
                    visible: !!control.activity && control.activity.kind === "recording" && !control.finishing
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 5
                    width: 9
                    height: 9
                    radius: 4.5
                    color: LingmoUI.Theme.redColor
                }
            }

            // Artwork with rounded corners (masked once; it only changes with the track)
            Image {
                id: _artSource
                anchors.fill: parent
                visible: false
                source: control.activity && control.activity.artUrl ? control.activity.artUrl : ""
                sourceSize: Qt.size(96, 96)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Rectangle {
                id: _artMask
                anchors.fill: parent
                radius: LingmoUI.Theme.bigRadius
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                visible: _tile.hasArt
                source: _artSource
                maskEnabled: true
                maskSource: _artMask
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Label {
                Layout.fillWidth: true
                text: !control.activity ? "" : control.finishing ? control.activity.finishMessage : control.activity.title
                font.pointSize: LingmoUI.Units.fontSubheading
                font.weight: Font.DemiBold
                color: LingmoUI.Theme.textColor
                elide: Text.ElideRight
            }

            Label {
                Layout.fillWidth: true
                visible: text !== ""
                text: !control.activity ? "" : control.finishing ? control.activity.title : control.activity.subtitle
                font.pointSize: LingmoUI.Units.fontBody
                color: LingmoUI.Theme.secondaryTextColor
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }

            Label {
                Layout.fillWidth: true
                visible: text !== "" && !control.finishing
                text: control.activity ? control.activity.detail : ""
                font.pointSize: LingmoUI.Units.fontCaption
                color: LingmoUI.Theme.secondaryTextColor
                elide: Text.ElideRight
            }
        }

        // Big live value (time or percentage)
        Label {
            Layout.alignment: Qt.AlignVCenter
            visible: text !== ""
            text: control.island.liveText(control.activity, control.island.now)
            font.pointSize: LingmoUI.Units.fontHeading
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: control.accent
            LayoutMirroring.enabled: false
            opacity: control.activity && control.activity.paused ? 0.6 : 1
        }

        // Hide this activity from the Island (its app keeps going)
        LingmoUI.IconButton {
            Layout.alignment: Qt.AlignTop
            visible: !control.finishing
            iconName: "window-close-symbolic"
            size: 22
            iconSize: 12
            round: true
            flat: true
            tipText: qsTr("Hide")
            onClicked: control.island.dismiss(control.activity.id)
        }
    }

    // ------------------------------------------------------------------
    // Progress
    // ------------------------------------------------------------------
    Rectangle {
        id: _track
        Layout.fillWidth: true
        visible: control.hasProgress
        implicitHeight: 6
        radius: 3
        color: LingmoUI.Theme.dividerColor
        clip: true

        Rectangle {
            visible: !control.activity || !control.activity.indeterminate
            height: parent.height
            radius: parent.radius
            width: control.activity ? parent.width * Math.max(0, Math.min(1, control.activity.progress)) : 0
            color: control.accent
            Behavior on width { NumberAnimation { duration: LingmoUI.Units.longDuration; easing.type: LingmoUI.Units.easing } }
        }

        // Busy: a segment sweeping across (only while the card is on screen;
        // a still, faint bar with "reduce motion")
        Rectangle {
            id: _busy
            visible: !!control.activity && control.activity.indeterminate
            height: parent.height
            radius: parent.radius
            width: parent.width * (LingmoUI.Theme.reduceMotion ? 1 : 0.3)
            color: control.accent
            opacity: LingmoUI.Theme.reduceMotion ? 0.45 : 1

            NumberAnimation on x {
                running: _busy.visible && control.visible && !LingmoUI.Theme.reduceMotion
                from: -_busy.width
                to: _track.width
                duration: 1200
                loops: Animation.Infinite
            }
        }
    }

    // ------------------------------------------------------------------
    // Actions
    // ------------------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        visible: !!control.activity && !control.finishing && control.activity.actions.length > 0
        spacing: LingmoUI.Units.largeSpacing

        Item { Layout.fillWidth: true }

        Repeater {
            model: control.activity && !control.finishing ? control.activity.actions : []

            delegate: Loader {
                id: _action
                required property var modelData
                readonly property string icon: control.island.actionIcon(modelData)
                Layout.alignment: Qt.AlignVCenter
                sourceComponent: icon !== "" ? _iconAction : _textAction

                Component {
                    id: _iconAction
                    // A round button on the raised glass
                    Item {
                        implicitWidth: 40
                        implicitHeight: 40

                        readonly property bool danger: _action.modelData.id === "stop" || _action.modelData.id === "hangup"

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: parent.danger
                                   ? Qt.rgba(LingmoUI.Theme.redColor.r, LingmoUI.Theme.redColor.g, LingmoUI.Theme.redColor.b,
                                             LingmoUI.Theme.darkMode ? 0.24 : 0.14)
                                   : LingmoUI.Theme.glassEnabled ? LingmoUI.Theme.glassRaisedColor
                                                                 : LingmoUI.Theme.alternateBackgroundColor
                            border.width: 1
                            border.color: LingmoUI.Theme.glassBorderColor
                        }

                        LingmoUI.IconButton {
                            anchors.fill: parent
                            iconName: _action.icon
                            size: 40
                            iconSize: 18
                            round: true
                            iconColor: parent.danger ? LingmoUI.Theme.redColor : LingmoUI.Theme.textColor
                            tipText: _action.modelData.label
                            Accessible.name: _action.modelData.label
                            onClicked: control.island.invoke(control.activity, _action.modelData.id)
                        }
                    }
                }

                Component {
                    id: _textAction
                    LingmoUI.ActionButton {
                        text: _action.modelData.label
                        onClicked: control.island.invoke(control.activity, _action.modelData.id)
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    // ------------------------------------------------------------------
    // The other activities
    // ------------------------------------------------------------------
    Rectangle {
        Layout.fillWidth: true
        visible: control.island.others.length > 0
        implicitHeight: 1
        color: LingmoUI.Theme.dividerColor
    }

    Repeater {
        model: control.island.others

        delegate: LingmoUI.SideBarItem {
            required property var modelData
            Layout.fillWidth: true
            title: modelData.finishing ? modelData.finishMessage : modelData.title
            iconName: control.island.iconFor(modelData)
            trailing: control.island.liveText(modelData, control.island.now)
            onClicked: control.island.selectedId = modelData.id
        }
    }
}
