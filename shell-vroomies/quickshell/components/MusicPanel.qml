import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
    id: musicPanel
    visible: true
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true }
    margins {
        top: root.musicVisible ? 65 : -400
        left: 0
        right: 0
    }
    implicitWidth: 460
    implicitHeight: musicPanel.gifSelectorOpen ? 500 : 210
    color: "transparent"
    focusable: true
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.musicVisible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    Behavior on margins.top { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

    // ── Renk aliasları (zyuTheme'den) ──
    readonly property color walBackground: zyuTheme.bar_bg
    readonly property color walForeground: zyuTheme.bar_fg
    readonly property color walColor5:     zyuTheme.accent
    readonly property color walColor8:     Qt.rgba(zyuTheme.bar_fg.r, zyuTheme.bar_fg.g, zyuTheme.bar_fg.b, 0.5)
    readonly property color walColor1:     Qt.rgba(1, 0.3, 0.3, 1)

    // ── MPRIS ──
    readonly property var player: {
        var players = Mpris.players.values
        if (!players || players.length === 0) return null
        for (var i = 0; i < players.length; i++) {
            if (players[i].isPlaying) return players[i]
        }
        return players[0]
    }

    readonly property bool hasTrack:     player !== null && (player.playbackState === MprisPlaybackState.Playing || player.playbackState === MprisPlaybackState.Paused)
    readonly property bool isPlaying:    player !== null && player.playbackState === MprisPlaybackState.Playing
    readonly property string trackTitle:  player ? (player.trackTitle  || "") : ""
    readonly property string trackArtist: player ? (player.trackArtist || "") : ""
    readonly property string trackAlbum:  player ? (player.trackAlbum  || "") : ""
    readonly property string artUrl:      player ? (player.trackArtUrl || "") : ""
    readonly property real trackLength:   player ? (player.length || 0) : 0
    property real trackPosition: 0

    // ── GIF state ──
    readonly property string configPath: (Quickshell.env("RYOKU_VROOMIES_SHELL_DIR") || (Quickshell.env("HOME") + "/.config/quickshell/ryoku-vroomies-shell")) + "/components/"
    readonly property string gifPath:    configPath + "/assets/gifs"
    readonly property string statePath:  (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/vroomies-shell"

    property var    gifFiles:          []
    property int    currentGifIndex:   0
    property int    previewGifIndex:   0
    property bool   gifSelectorOpen:   false
    property bool   gifsLoaded:        false
    property int    gifReloadCounter:  0
    property bool   isApplyingGif:     false
    property string currentGifSource:  "file://" + gifPath + "/current.gif"
    property int    pendingGifIndex:   -1

    // ── Helpers ──
    function formatTime(seconds) {
        if (seconds < 0) return "0:00"
        var mins = Math.floor(seconds / 60)
        var secs = Math.floor(seconds % 60)
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }
    function nextGif() { if (gifFiles.length > 0) previewGifIndex = (previewGifIndex + 1) % gifFiles.length }
    function prevGif() { if (gifFiles.length > 0) previewGifIndex = (previewGifIndex - 1 + gifFiles.length) % gifFiles.length }
    function applyGif() {
        if (isApplyingGif) return
        if (gifFiles.length > 0 && previewGifIndex < gifFiles.length) {
            isApplyingGif = true
            pendingGifIndex = previewGifIndex
            danceGifLoader.active = false
            setGifProc.selFile = gifFiles[previewGifIndex]
            setGifProc.running = true
        }
    }
    function loadGifs() {
        if (gifListProc.running) return
        musicPanel.gifFiles = []
        musicPanel.gifsLoaded = false
        musicPanel.previewGifIndex = 0
        gifListProc.running = true
    }
    function gifFileName(path) {
        var parts = path.split("/")
        return parts[parts.length - 1].replace(".gif", "")
    }
    function reloadMainGif() {
        musicPanel.gifReloadCounter++
        musicPanel.currentGifSource = "file://" + gifPath + "/current.gif?v=" + musicPanel.gifReloadCounter + "&t=" + Date.now()
        danceGifLoader.active = true
        musicPanel.isApplyingGif = false
        musicPanel.pendingGifIndex = -1
    }
    function saveGifIndex() {
        saveStateProc.command = ["bash", "-c", "mkdir -p '" + statePath + "' && echo '" + currentGifIndex + "' > '" + statePath + "/gif-index'"]
        saveStateProc.running = true
    }

    onGifSelectorOpenChanged: {
        if (!gifSelectorOpen) previewGifIndex = currentGifIndex
    }

    Component.onCompleted: {
        loadGifIndexProc.running = true
        stateDirProc.running = true
    }

    // ── Timers ──
    Timer {
        id: gifReloadTimer
        interval: 250; repeat: false
        onTriggered: musicPanel.reloadMainGif()
    }
    Timer {
        interval: 1000
        running: root.musicVisible && musicPanel.isPlaying
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (musicPanel.player) {
                musicPanel.player.positionChanged()
                musicPanel.trackPosition = musicPanel.player.position
            }
        }
    }

    // ── Focus handling ──
    Connections {
        target: root
        function onMusicVisibleChanged() {
            if (root.musicVisible) focusTimer.start()
        }
    }
    Timer { id: focusTimer;   interval: 50;  repeat: false; onTriggered: { musicPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive; releaseTimer.start() } }
    Timer { id: releaseTimer; interval: 100; repeat: false; onTriggered: musicPanel.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand }

    // ── UI ──
    Item {
        anchors.fill: parent
        focus: root.musicVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (musicPanel.gifSelectorOpen) musicPanel.gifSelectorOpen = false
                else root.musicVisible = false
                event.accepted = true
            } else if (event.key === Qt.Key_Space && !musicPanel.gifSelectorOpen) {
                if (musicPanel.player && musicPanel.player.canTogglePlaying) musicPanel.player.togglePlaying()
                event.accepted = true
            } else if (event.key === Qt.Key_N && !musicPanel.gifSelectorOpen) {
                if (musicPanel.player && musicPanel.player.canGoNext) musicPanel.player.next()
                event.accepted = true
            } else if (event.key === Qt.Key_P && !musicPanel.gifSelectorOpen) {
                if (musicPanel.player && musicPanel.player.canGoPrevious) musicPanel.player.previous()
                event.accepted = true
            } else if (event.key === Qt.Key_Left && musicPanel.gifSelectorOpen) {
                musicPanel.prevGif(); event.accepted = true
            } else if (event.key === Qt.Key_Right && musicPanel.gifSelectorOpen) {
                musicPanel.nextGif(); event.accepted = true
            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && musicPanel.gifSelectorOpen) {
                if (musicPanel.previewGifIndex !== musicPanel.currentGifIndex) musicPanel.applyGif()
                event.accepted = true
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            // ═══════════════════════════════════════
            // MAIN CARD
            // ═══════════════════════════════════════
            Rectangle {
                width: 460
                height: 200
                color: Qt.rgba(musicPanel.walBackground.r, musicPanel.walBackground.g, musicPanel.walBackground.b, 0.92)
                radius: 18
                border.color: Qt.rgba(musicPanel.walForeground.r, musicPanel.walForeground.g, musicPanel.walForeground.b, 0.1)
                border.width: 1
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    // Album Art
                    Rectangle {
                        Layout.preferredWidth: 130
                        Layout.preferredHeight: 130
                        Layout.alignment: Qt.AlignVCenter
                        radius: 14
                        color: Qt.rgba(musicPanel.walColor5.r, musicPanel.walColor5.g, musicPanel.walColor5.b, 0.1)
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            visible: albumArt.status !== Image.Ready
                            text: "󰎆"
                            color: Qt.rgba(musicPanel.walColor5.r, musicPanel.walColor5.g, musicPanel.walColor5.b, 0.3)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 40
                        }
                        Image {
                            id: albumArt
                            anchors.fill: parent
                            visible: musicPanel.artUrl !== ""
                            source: musicPanel.artUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 130
                            sourceSize.height: 130
                        }
                    }

                    // Details + Controls
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4

                        Text {
                            text: musicPanel.trackTitle || "Nothing Playing"
                            color: musicPanel.hasTrack ? musicPanel.walColor5 : musicPanel.walForeground
                            font.pixelSize: 15; font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: musicPanel.trackArtist !== ""
                            text: musicPanel.trackArtist
                            color: musicPanel.walForeground
                            font.pixelSize: 12
                            font.family: "JetBrainsMono Nerd Font"
                            opacity: 0.7
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: musicPanel.trackAlbum !== ""
                            text: musicPanel.trackAlbum
                            color: musicPanel.walColor8
                            font.pixelSize: 10
                            font.family: "JetBrainsMono Nerd Font"
                            opacity: 0.5
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Item { Layout.fillHeight: true }

                        // Progress Bar
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: musicPanel.hasTrack

                            Text {
                                text: musicPanel.formatTime(musicPanel.trackPosition)
                                color: musicPanel.walColor8
                                font.pixelSize: 10
                                font.family: "JetBrainsMono Nerd Font"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                height: 5; radius: 3
                                color: Qt.rgba(musicPanel.walForeground.r, musicPanel.walForeground.g, musicPanel.walForeground.b, 0.15)
                                Rectangle {
                                    width: musicPanel.trackLength > 0 ? parent.width * (musicPanel.trackPosition / musicPanel.trackLength) : 0
                                    height: parent.height; radius: 3
                                    color: musicPanel.walColor5
                                    Behavior on width { NumberAnimation { duration: 300 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        if (musicPanel.trackLength > 0 && musicPanel.player && musicPanel.player.canSeek)
                                            musicPanel.player.position = (mouse.x / parent.width) * musicPanel.trackLength
                                    }
                                }
                            }
                            Text {
                                text: musicPanel.formatTime(musicPanel.trackLength)
                                color: musicPanel.walColor8
                                font.pixelSize: 10
                                font.family: "JetBrainsMono Nerd Font"
                            }
                        }

                        // Controls
                        Row {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12
                            opacity: musicPanel.hasTrack ? 1.0 : 0.4

                            Rectangle {
                                width: 34; height: 34; radius: 8
                                color: prevBtnMa.containsMouse ? Qt.rgba(musicPanel.walForeground.r, musicPanel.walForeground.g, musicPanel.walForeground.b, 0.1) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: "󰒮"; color: musicPanel.walForeground; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
                                MouseArea { id: prevBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (musicPanel.player && musicPanel.player.canGoPrevious) musicPanel.player.previous() } }
                            }
                            Rectangle {
                                width: 44; height: 44; radius: 22
                                color: musicPanel.walColor5
                                Text { anchors.centerIn: parent; text: musicPanel.isPlaying ? "󰏤" : "󰐊"; color: musicPanel.walBackground; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font" }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (musicPanel.player && musicPanel.player.canTogglePlaying) musicPanel.player.togglePlaying() } }
                            }
                            Rectangle {
                                width: 34; height: 34; radius: 8
                                color: nextBtnMa.containsMouse ? Qt.rgba(musicPanel.walForeground.r, musicPanel.walForeground.g, musicPanel.walForeground.b, 0.1) : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: "󰒭"; color: musicPanel.walForeground; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
                                MouseArea { id: nextBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (musicPanel.player && musicPanel.player.canGoNext) musicPanel.player.next() } }
                            }
                        }
                    }

                    // GIF Display
                    Item {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 130
                        Layout.alignment: Qt.AlignBottom

                        Item {
                            id: gifContainer
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 140; height: 160

                            Loader {
                                id: danceGifLoader
                                anchors.fill: parent
                                active: true
                                sourceComponent: AnimatedImage {
                                    anchors.centerIn: parent
                                    width: parent.width; height: parent.height
                                    source: musicPanel.currentGifSource
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    playing: musicPanel.isPlaying
                                    paused: !musicPanel.isPlaying
                                    cache: false
                                    asynchronous: true
                                }
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top; anchors.right: parent.right
                            anchors.topMargin: 3; anchors.rightMargin: -5
                            width: 24; height: 24; radius: 12
                            color: gifEditMa.containsMouse ? Qt.rgba(1,1,1,0.2) : Qt.rgba(0,0,0,0.3)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "󰏫"; color: musicPanel.walForeground; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font" }
                            MouseArea {
                                id: gifEditMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!musicPanel.gifSelectorOpen) { musicPanel.loadGifs(); musicPanel.gifSelectorOpen = true }
                                    else musicPanel.gifSelectorOpen = false
                                }
                            }
                        }
                    }
                }
            }

            // ═══════════════════════════════════════
            // GIF SELECTOR DROPDOWN
            // ═══════════════════════════════════════
            Rectangle {
                width: 440
                height: 260
                anchors.horizontalCenter: parent.horizontalCenter
                radius: 14
                color: Qt.rgba(musicPanel.walBackground.r, musicPanel.walBackground.g, musicPanel.walBackground.b, 0.92)
                border.color: Qt.rgba(musicPanel.walForeground.r, musicPanel.walForeground.g, musicPanel.walForeground.b, 0.1)
                border.width: 1
                visible: musicPanel.gifSelectorOpen
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 20
                        Text {
                            text: "Select Animation"
                            color: musicPanel.walColor5
                            font.pixelSize: 12; font.bold: true
                            font.family: "JetBrainsMono Nerd Font"
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: musicPanel.gifFiles.length > 0
                            text: (musicPanel.previewGifIndex + 1) + " / " + musicPanel.gifFiles.length
                            color: musicPanel.walColor8
                            font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; opacity: 0.6
                        }
                        Item { width: 6 }
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: dropCloseMa.containsMouse ? Qt.rgba(musicPanel.walColor1.r, musicPanel.walColor1.g, musicPanel.walColor1.b, 0.5) : Qt.rgba(1,1,1,0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "󰅖"; color: dropCloseMa.containsMouse ? musicPanel.walColor1 : musicPanel.walForeground; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                            MouseArea { id: dropCloseMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: musicPanel.gifSelectorOpen = false }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.06) }

                    Item {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Rectangle {
                            anchors.fill: parent; radius: 12
                            color: Qt.rgba(0,0,0,0.2)
                            border.color: Qt.rgba(1,1,1,0.08); border.width: 1; clip: true

                            Item {
                                anchors.fill: parent; anchors.margins: 12
                                Loader {
                                    id: previewGifLoader
                                    anchors.fill: parent
                                    active: musicPanel.gifSelectorOpen && musicPanel.gifsLoaded && musicPanel.gifFiles.length > 0
                                    sourceComponent: AnimatedImage {
                                        anchors.centerIn: parent
                                        width: parent.width; height: parent.height
                                        source: (musicPanel.gifFiles.length > 0 && musicPanel.previewGifIndex < musicPanel.gifFiles.length) ? "file://" + musicPanel.gifFiles[musicPanel.previewGifIndex] : ""
                                        fillMode: Image.PreserveAspectFit; smooth: true
                                        playing: musicPanel.gifSelectorOpen; cache: false; asynchronous: true
                                    }
                                }
                            }
                            Text { anchors.centerIn: parent; visible: musicPanel.gifFiles.length === 0 && musicPanel.gifsLoaded; text: "No gifs found"; color: musicPanel.walColor8; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; opacity: 0.5 }
                            Text { anchors.centerIn: parent; visible: !musicPanel.gifsLoaded && musicPanel.gifSelectorOpen; text: "Loading..."; color: musicPanel.walColor8; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; opacity: 0.5 }
                            Rectangle {
                                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 8
                                visible: musicPanel.gifFiles.length > 0 && musicPanel.gifsLoaded
                                width: nameLabel.implicitWidth + 16; height: 20; radius: 10; color: Qt.rgba(0,0,0,0.6)
                                Text { id: nameLabel; anchors.centerIn: parent; text: (musicPanel.gifFiles.length > 0 && musicPanel.previewGifIndex < musicPanel.gifFiles.length) ? musicPanel.gifFileName(musicPanel.gifFiles[musicPanel.previewGifIndex]) : ""; color: musicPanel.walForeground; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"; opacity: 0.9 }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; Layout.preferredHeight: 32; spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 32; radius: 8
                            color: prevGifMa.containsMouse ? Qt.rgba(musicPanel.walColor5.r, musicPanel.walColor5.g, musicPanel.walColor5.b, 0.25) : Qt.rgba(1,1,1,0.08)
                            opacity: musicPanel.gifFiles.length > 1 ? 1.0 : 0.3
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "󰅁"; color: prevGifMa.containsMouse ? musicPanel.walColor5 : musicPanel.walForeground; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                            MouseArea { id: prevGifMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: musicPanel.gifFiles.length > 1 && !musicPanel.isApplyingGif; onClicked: musicPanel.prevGif() }
                        }
                        Rectangle {
                            Layout.preferredWidth: 36; Layout.preferredHeight: 32; radius: 8
                            color: nextGifMa.containsMouse ? Qt.rgba(musicPanel.walColor5.r, musicPanel.walColor5.g, musicPanel.walColor5.b, 0.25) : Qt.rgba(1,1,1,0.08)
                            opacity: musicPanel.gifFiles.length > 1 ? 1.0 : 0.3
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "󰅂"; color: nextGifMa.containsMouse ? musicPanel.walColor5 : musicPanel.walForeground; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font" }
                            MouseArea { id: nextGifMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: musicPanel.gifFiles.length > 1 && !musicPanel.isApplyingGif; onClicked: musicPanel.nextGif() }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: 85; Layout.preferredHeight: 32; radius: 8
                            color: {
                                if (musicPanel.isApplyingGif) return Qt.rgba(1,1,1,0.03)
                                if (musicPanel.previewGifIndex === musicPanel.currentGifIndex) return Qt.rgba(1,1,1,0.05)
                                return applyGifMa.pressed ? musicPanel.walColor5 : applyGifMa.containsMouse ? Qt.rgba(musicPanel.walColor5.r, musicPanel.walColor5.g, musicPanel.walColor5.b, 0.35) : Qt.rgba(musicPanel.walColor5.r, musicPanel.walColor5.g, musicPanel.walColor5.b, 0.18)
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                anchors.centerIn: parent
                                text: musicPanel.isApplyingGif ? "Applying..." : musicPanel.previewGifIndex === musicPanel.currentGifIndex ? "󰄬 Current" : "󰸞 Apply"
                                color: {
                                    if (musicPanel.isApplyingGif) return Qt.rgba(musicPanel.walForeground.r, musicPanel.walForeground.g, musicPanel.walForeground.b, 0.4)
                                    if (musicPanel.previewGifIndex === musicPanel.currentGifIndex) return Qt.rgba(musicPanel.walForeground.r, musicPanel.walForeground.g, musicPanel.walForeground.b, 0.3)
                                    return applyGifMa.pressed ? musicPanel.walBackground : musicPanel.walColor5
                                }
                                font.pixelSize: 11; font.bold: true; font.family: "JetBrainsMono Nerd Font"
                            }
                            MouseArea { id: applyGifMa; anchors.fill: parent; hoverEnabled: true; cursorShape: (musicPanel.previewGifIndex !== musicPanel.currentGifIndex && !musicPanel.isApplyingGif) ? Qt.PointingHandCursor : Qt.ArrowCursor; enabled: musicPanel.previewGifIndex !== musicPanel.currentGifIndex && !musicPanel.isApplyingGif; onClicked: musicPanel.applyGif() }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 22
                        color: Qt.rgba(0,0,0,0.2); radius: 6
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            Text { text: "←→ nav";  color: musicPanel.walColor8; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"; opacity: 0.6 }
                            Item { Layout.fillWidth: true }
                            Text { text: "↵ apply"; color: musicPanel.walColor8; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"; opacity: 0.6 }
                            Item { Layout.fillWidth: true }
                            Text { text: "esc close"; color: musicPanel.walColor8; font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"; opacity: 0.6 }
                        }
                    }
                }
            }
        }
    }

    // ── Processes ──
    Process { id: stateDirProc;     command: ["mkdir", "-p", musicPanel.statePath] }
    Process { id: saveStateProc }
    Process {
        id: loadGifIndexProc
        command: ["bash", "-c", "cat '" + musicPanel.statePath + "/gif-index' 2>/dev/null || echo '0'"]
        stdout: SplitParser {
            onRead: data => {
                var idx = parseInt(data.trim())
                musicPanel.currentGifIndex = isNaN(idx) ? 0 : idx
                musicPanel.previewGifIndex = musicPanel.currentGifIndex
            }
        }
    }
    Process {
        id: gifListProc
        command: ["sh", "-c", "find '" + musicPanel.gifPath + "' -maxdepth 1 -name '*.gif' ! -name 'current.gif' -type f 2>/dev/null | sort"]
        stdout: SplitParser {
            onRead: data => {
                var file = data.trim()
                if (file.length > 0) {
                    var current = musicPanel.gifFiles.slice()
                    current.push(file)
                    musicPanel.gifFiles = current
                }
            }
        }
        onExited: {
            musicPanel.gifsLoaded = true
            if (musicPanel.gifFiles.length > 0)
                musicPanel.previewGifIndex = Math.min(musicPanel.currentGifIndex, musicPanel.gifFiles.length - 1)
        }
    }
    Process {
        id: setGifProc
        property string selFile: ""
        command: ["cp", selFile, musicPanel.gifPath + "/current.gif"]
        onExited: code => {
            if (code === 0 && musicPanel.pendingGifIndex >= 0) {
                musicPanel.currentGifIndex = musicPanel.pendingGifIndex
                musicPanel.gifSelectorOpen = false
                musicPanel.saveGifIndex()
                gifReloadTimer.start()
            } else {
                musicPanel.isApplyingGif = false
                musicPanel.pendingGifIndex = -1
                danceGifLoader.active = true
            }
        }
    }
}
