/*
 * SPDX-FileCopyrightText: 2026 LingmoOS Team
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import QtQuick
import Lingmo.Mpris

// "Now playing" for the Island, read from MPRIS: any player, no app changes.
// Shown while a track plays, and for a minute after it is paused.
Item {
    id: control

    property var manager

    readonly property var artUrlTag: Mpris.metadataToString(Mpris.ArtUrl)
    readonly property var titleTag: Mpris.metadataToString(Mpris.Title)
    readonly property var artistTag: Mpris.metadataToString(Mpris.Artist)

    readonly property bool playing: mpris.currentService !== "" && mpris.playbackStatus === Mpris.Playing
    readonly property bool paused: mpris.currentService !== "" && mpris.playbackStatus === Mpris.Paused
    property bool recentlyPaused: false
    property string title: ""
    property string artist: ""
    property string artUrl: ""

    readonly property bool shown: title !== "" && (playing || (paused && recentlyPaused))

    MprisManager {
        id: mpris
        onMetadataChanged: control.readMetadata()
        onCurrentServiceChanged: { control.readMetadata(); control.statusChanged() }
    }

    function readMetadata() {
        const md = mpris.metadata
        const text = (tag) => (tag in md) && md[tag] ? md[tag].toString() : ""
        title = text(titleTag)
        artist = text(artistTag)
        artUrl = text(artUrlTag)
        publish()
    }

    // From the player's status itself (the bindings above may not be updated
    // yet inside a change handler)
    function statusChanged() {
        const hasPlayer = mpris.currentService !== ""
        const isPlaying = hasPlayer && mpris.playbackStatus === Mpris.Playing
        const isPaused = hasPlayer && mpris.playbackStatus === Mpris.Paused
        if (isPlaying) {
            _pauseTimer.stop()
            recentlyPaused = false
        } else if (isPaused && !_pauseTimer.running && !recentlyPaused) {
            recentlyPaused = true
            _pauseTimer.restart()
        } else if (!isPaused) {
            _pauseTimer.stop()
            recentlyPaused = false
        }
        publish()
    }

    Connections {
        target: mpris
        function onPlaybackStatusChanged() { control.statusChanged() }
    }

    Timer {
        id: _pauseTimer
        interval: 60 * 1000
        onTriggered: { control.recentlyPaused = false; control.publish() }
    }

    function publish() {
        if (!manager)
            return
        // Not through `shown`: from a change handler it may not be updated yet
        const hasPlayer = mpris.currentService !== ""
        const isPlaying = hasPlayer && mpris.playbackStatus === Mpris.Playing
        const isPaused = hasPlayer && mpris.playbackStatus === Mpris.Paused
        const show = title !== "" && (isPlaying || (isPaused && recentlyPaused))
        if (!show) {
            manager.removeLocal("media")
            return
        }
        const actions = []
        if (mpris.canGoPrevious)
            actions.push("previous", qsTr("Previous"))
        if (isPlaying && mpris.canPause)
            actions.push("pause", qsTr("Pause"))
        else if (!isPlaying && mpris.canPlay)
            actions.push("play", qsTr("Play"))
        if (mpris.canGoNext)
            actions.push("next", qsTr("Next"))

        manager.setLocal("media", {
            "appId": mpris.desktopEntry,
            "kind": "media",
            "title": title,
            "subtitle": artist !== "" ? artist : mpris.identity,
            "iconName": "",
            "progress": -1,
            "actions": actions,
            "artUrl": artUrl,
            "playing": isPlaying
        })
    }

    function trigger(actionId) {
        if (actionId === "previous")
            mpris.previous()
        else if (actionId === "next")
            mpris.next()
        else if (actionId === "pause" || actionId === "play")
            mpris.playPause()
    }

    Component.onCompleted: readMetadata()
}
