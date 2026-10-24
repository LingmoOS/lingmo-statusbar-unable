/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Lingmo.StatusBar 1.0
import LingmoUI.CompatibleModule 3.0 as LingmoUI

// The Island: live activities in the middle of the status bar
// (docs/island-api.md). A glass capsule as tall as the bar shows the main
// activity; the others wait next to it as small pills with a count. Hover or
// click and the capsule springs open into a card with controls (IslandCard).
Item {
    id: island

    // Bar metrics from main.qml
    property int barHeight: parent ? parent.height : 28
    property color textColor: LingmoUI.Theme.textColor

    readonly property var activities: islandManager.activities
    readonly property int count: islandManager.count

    // The user picked one in the card's list (0 = the most important)
    property int selectedId: 0

    readonly property var primary: {
        const list = activities
        if (list.length === 0)
            return null
        if (selectedId > 0) {
            for (let i = 0; i < list.length; ++i)
                if (list[i].id === selectedId)
                    return list[i]
        }
        return list[0]
    }

    readonly property var others: {
        const list = activities
        const out = []
        for (let i = 0; i < list.length; ++i)
            if (!primary || list[i].id !== primary.id)
                out.push(list[i])
        return out
    }

    // Wall clock for the live times: ticks once a second, and only while some
    // activity shows a running time (nothing repaints while idle)
    property double now: Date.now()
    readonly property bool needsClock: {
        const list = activities
        for (let i = 0; i < list.length; ++i) {
            const a = list[i]
            if (!a.paused && !a.finishing && (a.startTime > 0 || a.endTime > 0))
                return true
        }
        return false
    }

    Timer {
        interval: 1000
        repeat: true
        running: island.needsClock
        triggeredOnStart: true
        onTriggered: island.now = Date.now()
    }

    implicitWidth: _row.implicitWidth
    implicitHeight: barHeight
    width: implicitWidth
    height: barHeight
    visible: count > 0 || _card.visible

    // ------------------------------------------------------------------
    // Helpers shared with the compact and expanded views
    // ------------------------------------------------------------------

    function formatDuration(ms) {
        let s = Math.max(0, Math.floor(ms / 1000))
        const h = Math.floor(s / 3600)
        s -= h * 3600
        const m = Math.floor(s / 60)
        s -= m * 60
        const pad = (n) => (n < 10 ? "0" : "") + n
        return h > 0 ? h + ":" + pad(m) + ":" + pad(s) : m + ":" + pad(s)
    }

    // The live value: time left, time elapsed or percentage ("" if none)
    function liveText(a, now) {
        if (!a || a.finishing)
            return ""
        if (a.endTime > 0)
            return formatDuration(a.paused ? a.frozenTime : a.endTime - now)
        if (a.startTime > 0)
            return formatDuration(a.paused ? a.frozenTime : now - a.startTime)
        if (a.progress >= 0)
            return Math.round(Math.min(1, a.progress) * 100) + "%"
        return ""
    }

    function accentFor(a) {
        if (!a)
            return LingmoUI.Theme.highlightColor
        if (a.finishing)
            return LingmoUI.Theme.successColor
        if (a.accent)
            return a.accent
        switch (a.kind) {
        case "call": return LingmoUI.Theme.greenColor
        case "recording": return LingmoUI.Theme.redColor
        case "timer":
        case "stopwatch": return LingmoUI.Theme.orangeColor
        case "render": return LingmoUI.Theme.purpleColor
        case "workflow": return LingmoUI.Theme.pinkColor
        default: return LingmoUI.Theme.highlightColor
        }
    }

    function iconFor(a) {
        if (!a)
            return ""
        if (a.finishing)
            return "emblem-ok-symbolic"
        if (a.iconName)
            return a.iconName
        switch (a.kind) {
        case "call": return "call-start"
        case "recording": return "media-record"
        case "timer":
        case "stopwatch": return "chronometer"
        case "media": return "audio-x-generic"
        case "transfer": return "folder-download"
        case "render": return "video-x-generic"
        case "mail": return "mail-send"
        case "workflow": return "system-run"
        default: return "dialog-information"
        }
    }

    // Tint for the activity's icon: our own and symbolic icons take the
    // accent colour; an app's full-colour icon stays as it is
    function iconTint(a) {
        if (!a)
            return "transparent"
        if (a.finishing || !a.iconName || a.iconName.endsWith("-symbolic"))
            return accentFor(a)
        return "transparent"
    }

    function actionIcon(action) {
        if (action.icon)
            return action.icon
        switch (action.id) {
        case "pause": return "media-playback-pause"
        case "resume":
        case "play": return "media-playback-start"
        case "stop": return "media-playback-stop"
        case "next": return "media-skip-forward"
        case "previous": return "media-skip-backward"
        case "cancel": return "dialog-cancel"
        case "open": return "document-open"
        case "reply": return "mail-reply-sender"
        case "mute": return "microphone-sensitivity-muted"
        case "hangup": return "call-stop"
        case "answer": return "call-start"
        default: return ""
        }
    }

    function dismiss(id) {
        islandManager.dismiss(id)
    }

    function invoke(a, actionId) {
        if (a)
            islandManager.invokeAction(a.id, actionId)
    }

    // ------------------------------------------------------------------

    IslandManager {
        id: islandManager

        onLocalActionInvoked: (key, actionId) => {
            if (key === "media")
                _media.trigger(actionId)
        }

        onActivitiesChanged: {
            // The picked one is gone: back to automatic
            if (island.selectedId > 0) {
                const list = islandManager.activities
                let found = false
                for (let i = 0; i < list.length; ++i)
                    found = found || list[i].id === island.selectedId
                if (!found)
                    island.selectedId = 0
            }
            if (islandManager.count === 0)
                _card.collapse()
        }
    }

    // What's playing, from MPRIS (any player)
    IslandMedia {
        id: _media
        manager: islandManager
    }

    // ------------------------------------------------------------------
    // Compact: the capsule and the pills of the other activities
    // ------------------------------------------------------------------

    Row {
        id: _row
        anchors.verticalCenter: parent.verticalCenter
        spacing: LingmoUI.Units.smallSpacing / 2
        // The card covers the capsule while it is open
        opacity: _card.surfaceShown ? 0 : 1

        LingmoUI.GlassSurface {
            id: capsule
            anchors.verticalCenter: parent.verticalCenter
            height: island.barHeight - 6
            width: Math.min(_compact.implicitWidth + height * 0.5, 300)
            radius: height / 2
            // The bar behind is already glass: no blur of its own
            blurMode: 2 // GlassSurface.Never
            backdropBlurred: true
            // A raised pane on the bar's glass; solid without glass
            tint: LingmoUI.Theme.glassEnabled ? Qt.rgba(1, 1, 1, 1)
                                              : (LingmoUI.Theme.darkMode ? LingmoUI.Theme.alternateBackgroundColor
                                                                         : LingmoUI.Theme.secondBackgroundColor)
            tintOpacity: LingmoUI.Theme.glassRaisedColor.a
            sheenEnabled: false

            Behavior on width {
                enabled: LingmoUI.Units.springEnabled
                SpringAnimation {
                    spring: LingmoUI.Units.spring
                    damping: LingmoUI.Units.springDamping
                    epsilon: LingmoUI.Units.springEpsilon
                }
            }

            IslandCompact {
                id: _compact
                anchors.fill: parent
                anchors.leftMargin: capsule.height * 0.25
                anchors.rightMargin: capsule.height * 0.25
                island: island
                activity: island.primary
                now: island.now
            }
        }

        // The others: a small pill each (up to two), then "+N"
        Repeater {
            model: island.others.length > 0 ? island.others.slice(0, 2) : []

            delegate: LingmoUI.GlassSurface {
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                height: island.barHeight - 8
                width: height
                radius: height / 2
                blurMode: 2 // Never
                backdropBlurred: true
                tint: capsule.tint
                tintOpacity: capsule.tintOpacity
                sheenEnabled: false
                highlightVisible: false

                LingmoUI.IconItem {
                    anchors.centerIn: parent
                    width: LingmoUI.Units.iconSizes.small - 4
                    height: width
                    source: island.iconFor(modelData)
                    color: island.iconTint(modelData)
                }
            }
        }

        Label {
            anchors.verticalCenter: parent.verticalCenter
            visible: island.others.length > 2
            text: qsTr("+%1").arg(island.others.length - 2)
            font.pointSize: LingmoUI.Units.fontCaption
            font.weight: Font.DemiBold
            color: LingmoUI.Theme.secondaryTextColor
        }
    }

    // Hover opens the card after a moment; a click opens it and keeps it
    // open (pinned) until the next click
    HoverHandler {
        id: _capsuleHover
        onHoveredChanged: {
            if (hovered && !_card.expanded)
                _openTimer.restart()
            else
                _openTimer.stop()
            _card.pointerMoved()
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: {
            _openTimer.stop()
            if (_card.expanded && _card.pinned)
                _card.collapse()
            else
                _card.expand(true)
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton
        // Middle click dismisses the main activity (its app keeps running)
        onTapped: if (island.primary) islandManager.dismiss(island.primary.id)
    }

    Timer {
        id: _openTimer
        interval: 350
        onTriggered: if (_capsuleHover.hovered) _card.expand(false)
    }

    readonly property alias capsuleHovered: _capsuleHover.hovered

    IslandCard {
        id: _card
        island: island
        manager: islandManager
        capsuleItem: capsule
    }

    Accessible.role: Accessible.Button
    Accessible.name: primary ? primary.title + " " + liveText(primary, now) : ""
}
