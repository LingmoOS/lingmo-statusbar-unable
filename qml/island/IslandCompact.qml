/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

import LingmoUI.CompatibleModule 3.0 as LingmoUI

// One activity in the capsule: indicator, short title, live value
Item {
    id: control

    property var island
    property var activity: null
    property double now: 0

    readonly property color accent: island.accentFor(activity)
    readonly property string live: island.liveText(activity, now)
    readonly property bool showRing: !!activity && !activity.finishing && activity.progress >= 0
                                     && activity.endTime <= 0 && activity.startTime <= 0

    implicitWidth: _layout.implicitWidth
    implicitHeight: _layout.implicitHeight

    // Cross-fade when the main activity changes
    property int _shownId: activity ? activity.id : 0
    on_ShownIdChanged: _swap.restart()

    SequentialAnimation {
        id: _swap
        NumberAnimation { target: _layout; property: "opacity"; to: 0.0; duration: LingmoUI.Units.veryShortDuration }
        NumberAnimation { target: _layout; property: "opacity"; to: 1.0; duration: LingmoUI.Units.shortDuration }
    }

    RowLayout {
        id: _layout
        anchors.fill: parent
        spacing: LingmoUI.Units.smallSpacing

        // Indicator: recording dot, artwork, or the icon (with a progress ring)
        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: LingmoUI.Units.iconSizes.small
            implicitHeight: implicitWidth

            Rectangle {
                anchors.centerIn: parent
                visible: !!control.activity && control.activity.kind === "recording" && !control.activity.finishing
                width: 8
                height: 8
                radius: 4
                color: control.accent
            }

            Image {
                id: _art
                anchors.fill: parent
                visible: !!control.activity && control.activity.kind === "media"
                         && !!control.activity.artUrl && status === Image.Ready
                source: visible || (control.activity && control.activity.artUrl) ? control.activity.artUrl : ""
                sourceSize: Qt.size(width * 2, height * 2)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }

            LingmoUI.IconItem {
                anchors.centerIn: parent
                width: control.showRing ? parent.width - 6 : parent.width
                height: width
                visible: !!control.activity && control.activity.kind !== "recording" && !_art.visible
                         || (!!control.activity && control.activity.finishing)
                source: control.island.iconFor(control.activity)
                color: control.island.iconTint(control.activity)
            }

            // Progress ring around the icon
            Shape {
                anchors.fill: parent
                visible: control.showRing
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: LingmoUI.Theme.dividerColor
                    strokeWidth: 2
                    PathAngleArc {
                        centerX: 8; centerY: 8
                        radiusX: 7; radiusY: 7
                        startAngle: 0
                        sweepAngle: 360
                    }
                }
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: control.accent
                    strokeWidth: 2
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 8; centerY: 8
                        radiusX: 7; radiusY: 7
                        startAngle: -90
                        sweepAngle: control.activity ? 360 * Math.max(0, Math.min(1, control.activity.progress)) : 0
                    }
                }
            }
        }

        Label {
            Layout.alignment: Qt.AlignVCenter
            Layout.maximumWidth: 150
            text: !control.activity ? ""
                  : control.activity.finishing ? control.activity.finishMessage
                  : control.activity.kind === "media" && control.activity.subtitle
                    ? control.activity.title + " · " + control.activity.subtitle
                    : control.activity.title
            elide: Text.ElideRight
            font.pointSize: LingmoUI.Units.fontCaption
            font.weight: Font.DemiBold
            color: LingmoUI.Theme.textColor
        }

        // Live value: monospaced digits so the capsule doesn't wobble
        Label {
            Layout.alignment: Qt.AlignVCenter
            visible: text !== ""
            text: control.live
            font.pointSize: LingmoUI.Units.fontCaption
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: control.accent
            // Times read left to right in every language
            LayoutMirroring.enabled: false
        }

        // Media: a still "now playing" glyph (no animation: nothing repaints)
        Row {
            Layout.alignment: Qt.AlignVCenter
            visible: !!control.activity && control.activity.kind === "media" && !control.activity.finishing
            spacing: 2
            Repeater {
                model: [0.55, 1.0, 0.75]
                delegate: Rectangle {
                    required property var modelData
                    anchors.bottom: parent.bottom
                    width: 2.5
                    height: 10 * (control.activity && control.activity.playing ? modelData : 0.3)
                    radius: 1.25
                    color: control.accent
                }
            }
            height: 10
        }
    }
}
