import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"
import "../../components"

Item {
    id: root

    // ── Source allowlist ──────────────────────────────────────────────────────
    readonly property var _allowed: [
        "spotify", "youtube",
        "firefox", "chromium", "chrome",
        "brave", "edge", "opera", "vivaldi", "safari", "arc"
    ]

    // Explicit count tracker — forces filteredPlayers to re-evaluate whenever
    // a player joins or leaves the MPRIS list.
    property int _mprisCount: Mpris.players.values.length

    readonly property var filteredPlayers: {
        var _dep = root._mprisCount  // explicit dependency on list size changes
        var result = []
        var vals = Mpris.players.values
        for (var i = 0; i < vals.length; i++) {
            var id = (vals[i].identity || "").toLowerCase()
            for (var j = 0; j < root._allowed.length; j++) {
                if (id.indexOf(root._allowed[j]) !== -1) {
                    result.push(vals[i])
                    break
                }
            }
        }
        return result
    }

    property int selectedPlayerIndex: 0
    property bool _dropdownOpen: false

    onVisibleChanged: if (!visible) root._dropdownOpen = false

    onFilteredPlayersChanged: {
        // Prefer keeping the same player object selected after list change.
        var oldPlayer = root.player
        if (oldPlayer) {
            for (var i = 0; i < root.filteredPlayers.length; i++) {
                if (root.filteredPlayers[i] === oldPlayer) {
                    root.selectedPlayerIndex = i
                    return
                }
            }
        }
        // Fallback: clamp to valid range
        if (root.selectedPlayerIndex >= root.filteredPlayers.length)
            root.selectedPlayerIndex = Math.max(0, root.filteredPlayers.length - 1)
    }

    // ── MPRIS ─────────────────────────────────────────────────────────────────
    readonly property var player: root.filteredPlayers.length > 0
                                  ? root.filteredPlayers[root.selectedPlayerIndex] : null

    readonly property bool   isPlaying: root.player?.playbackState === MprisPlaybackState.Playing ?? false
    readonly property string artUrl:    root.player?.trackArtUrl ?? ""

    readonly property string title: {
        var t = root.player?.trackTitle
        return (t && t !== "") ? t : "Nothing Playing"
    }
    readonly property string artist: {
        var a = root.player?.trackArtists
        if (!a) return ""
        if (typeof a === "string") return a
        if (typeof a.join === "function") return a.join(", ")
        return a.toString()
    }

    readonly property real length:   root.player?.length   ?? 0
    readonly property real position: root.player?.position ?? 0

    property real _pos: 0
    onPositionChanged: root._pos = position

    Timer {
        interval: 1000; running: root.isPlaying; repeat: true
        onTriggered: {
            if (root.length > 0)
                root._pos = Math.min(root._pos + 1, root.length)
        }
    }

    function _fmt(sec) {
        var s = Math.floor(sec)
        return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + (s % 60)
    }

    readonly property real _progress: root.length > 0 ? root._pos / root.length : 0

    // ── Shared cava bars (32 bars from CavaService) ───────────────────────────
    readonly property int _cavaBars: 32
    readonly property var _bars: CavaService.bars

    // ── Player icon helper ────────────────────────────────────────────────────
    function _playerIcon(player) {
        if (!player) return "♪"
        var id = (player.identity || "").toLowerCase()
        if (id.indexOf("spotify")  !== -1) return ""
        if (id.indexOf("firefox")  !== -1) return ""
        if (id.indexOf("chromium") !== -1) return ""
        if (id.indexOf("chrome")   !== -1) return ""
        if (id.indexOf("brave")    !== -1) return ""
        if (id.indexOf("youtube")  !== -1) return ""
        return "♪"
    }

    // ── Player label helper ───────────────────────────────────────────────────
    function _playerLabel(player) {
        if (!player) return "—"
        var id = (player.identity || "").toLowerCase()
        if (id.indexOf("spotify")  !== -1) return "Spotify"
        if (id.indexOf("firefox")  !== -1) return "Firefox"
        if (id.indexOf("chromium") !== -1) return "Chromium"
        if (id.indexOf("chrome")   !== -1) return "Chrome"
        if (id.indexOf("brave")    !== -1) return "Brave"
        if (id.indexOf("youtube")  !== -1) return "YouTube"
        if (id.indexOf("edge")     !== -1) return "Edge"
        if (id.indexOf("opera")    !== -1) return "Opera"
        if (id.indexOf("vivaldi")  !== -1) return "Vivaldi"
        return player.identity || "Player"
    }

    // ── Background visuals ────────────────────────────────────────────────────
    Item {
        id: bgSource
        anchors.fill:  parent
        opacity:       0
        layer.enabled: true

        Item {
            id: artSource
            anchors.fill:  parent
            layer.enabled: true
            Image {
                anchors.fill: parent
                source:   root.artUrl
                fillMode: Image.PreserveAspectCrop
                smooth:   true
            }
        }

        MultiEffect {
            source:       artSource
            anchors.fill: parent
            visible:      root.artUrl !== ""
            opacity:      root.artUrl !== "" ? 1 : 0
            blurEnabled:  true
            blur:         0.5
            blurMax:      32
            saturation:   0.2
            Behavior on opacity { NumberAnimation { duration: 400 } }
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.38) }
                GradientStop { position: 0.4; color: Qt.rgba(0,0,0,0.50) }
                GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.88) }
            }
        }
    }

    Rectangle {
        id: bgMask
        anchors.fill:  parent
        radius:        Theme.cornerRadius
        visible:       false
        layer.enabled: true
    }

    MultiEffect {
        source:           bgSource
        anchors.fill:     parent
        maskEnabled:      true
        maskSource:       bgMask
        maskThresholdMin: 0.5
        maskSpreadAtMin:  1.0
    }

    // ── Track name + artist ───────────────────────────────────────────────────
    Column {
        anchors {
            left:  parent.left;  leftMargin:  14
            right: parent.right; rightMargin: 14
            top:   parent.top;   topMargin:   16
        }
        spacing: 4
        Text {
            width: parent.width
            text:  root.title
            font.pixelSize: 18; font.weight: Font.Bold
            color: "#ffffff"; elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            width:   parent.width
            text:    root.artist
            visible: root.artist !== ""
            font.pixelSize: 13
            color: Qt.rgba(1,1,1,0.55); elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ── Bottom stack: controls + progress (raised to give room for picker) ──────
    Column {
        anchors {
            left:   parent.left;   leftMargin:   14
            right:  parent.right;  rightMargin:  14
            bottom: parent.bottom; bottomMargin: 54
        }
        spacing: 6

        // Controls
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 28
            Repeater {
                model: [ { key: "prev" }, { key: "play" }, { key: "next" } ]
                delegate: Rectangle {
                    required property var  modelData
                    required property int  index
                    readonly property bool isPlay: modelData.key === "play"
                    readonly property string dispIcon: {
                        if (modelData.key === "prev") return "\u23EE"
                        if (modelData.key === "next") return "\u23ED"
                        return root.isPlaying ? "\u23F8" : "\u23F5"
                    }
                    width:  isPlay ? 44 : 36; height: isPlay ? 44 : 36
                    radius: height / 2
                    color: isPlay
                           ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                           : cH.hovered ? Qt.rgba(1,1,1,0.14) : Qt.rgba(1,1,1,0.06)
                    border.color: isPlay ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.3) : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors.centerIn: parent
                        text: parent.dispIcon
                        font.pixelSize: isPlay ? 18 : 14
                        color: isPlay ? Theme.active : Qt.rgba(1,1,1,0.7)
                    }
                    HoverHandler { id: cH; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!root.player) return
                            switch (modelData.key) {
                                case "play":
                                    if (root.player.canTogglePlaying)
                                        root.player.isPlaying = !root.player.isPlaying
                                    break
                                case "prev":
                                    if (root.player.canGoPrevious) root.player.previous()
                                    break
                                case "next":
                                    if (root.player.canGoNext) root.player.next()
                                    break
                            }
                        }
                    }
                }
            }
        }

        // Progress bar + timestamps
        Column {
            width: parent.width; spacing: 3
            Item {
                width: parent.width; height: 6
                Rectangle {
                    anchors.fill: parent; radius: height / 2
                    color: Qt.rgba(1,1,1,0.2)
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if (root.player && root.length > 0) {
                                var f = mouse.x / width
                                root.player.position = f * root.length
                                root._pos = f * root.length
                            }
                        }
                    }
                    Rectangle {
                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                        width:  Math.max(radius * 2, parent.width * root._progress)
                        radius: parent.radius; color: Theme.active
                        Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                }
            }
            Item {
                width: parent.width; height: 14

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: root._fmt(root._pos)
                    font.pixelSize: 9; font.family: "JetBrains Mono"
                    color: Qt.rgba(1,1,1,0.4)
                }

                Text {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    text: root._fmt(root.length)
                    font.pixelSize: 9; font.family: "JetBrains Mono"
                    color: Qt.rgba(1,1,1,0.4)
                }
            }
        }
    }

    // ── Source picker — upward-expanding pill ─────────────────────────────────
    // Sits in the gap between the controls and the card bottom; expands upward.
    Item {
        id: sourcePicker
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom:           parent.bottom
            bottomMargin:     12
        }
        visible: root.filteredPlayers.length > 1
        z:       30
        // Footprint tracks the animated pill so hit-testing always matches
        width:  pill.width
        height: pill.height

        Rectangle {
            id: pill
            anchors.bottom:           parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter

            // Width is driven only by the always-visible active row — no circular dep
            width: activeRow.implicitWidth + 28

            readonly property int _rowH: 26
            height: root._dropdownOpen
                    ? (_rowH * root.filteredPlayers.length)
                    : _rowH
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            radius:       _rowH / 2
            clip:         true
            color:        Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
            border.color: root._dropdownOpen
                          ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30)
                          : "transparent"
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 150 } }

            // Column anchored to pill bottom — children stack upward on expand
            Column {
                id: pillCol
                anchors {
                    bottom: parent.bottom
                    left:   parent.left
                    right:  parent.right
                }
                spacing: 0

                // ── Other player rows (appear above the active row) ─────────
                Repeater {
                    model: root.filteredPlayers

                    delegate: Item {
                        required property var modelData
                        required property int index
                        readonly property bool isCurrent: index === root.selectedPlayerIndex

                        // Fixed width = pill; breaks the old circular dep on otherRow.implicitWidth
                        width:   pill.width
                        height:  isCurrent ? 0 : (root._dropdownOpen ? pill._rowH : 0)
                        visible: !isCurrent
                        opacity: root._dropdownOpen ? 1 : 0
                        Behavior on height  { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 140 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text:           root._playerIcon(modelData)
                                font.pixelSize: 11
                                color:          rowH.hovered
                                                ? Qt.rgba(1,1,1,0.90)
                                                : Qt.rgba(1,1,1,0.55)
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text:           root._playerLabel(modelData)
                                font.pixelSize: 10
                                color:          rowH.hovered
                                                ? Qt.rgba(1,1,1,0.90)
                                                : Qt.rgba(1,1,1,0.55)
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }

                        HoverHandler { id: rowH; cursorShape: Qt.PointingHandCursor }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.selectedPlayerIndex = index
                                root._dropdownOpen = false
                            }
                        }
                    }
                }

                // ── Active player row (always visible, anchored at pill bottom) ─
                Item {
                    height: pill._rowH
                    width:  pill.width

                    Row {
                        id: activeRow
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text:           root._playerIcon(root.player)
                            font.pixelSize: 11
                            color:          Theme.active
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text:           root._playerLabel(root.player)
                            font.pixelSize: 10
                            font.weight:    Font.Medium
                            color:          Qt.rgba(1,1,1,0.92)
                        }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        onClicked:    root._dropdownOpen = !root._dropdownOpen
                    }
                }
            }
        }
    }

    // ── Cava bars — independent, always flush with the card bottom ────────────
    Item {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 32
        Row {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            spacing: 2
            readonly property real barW: Math.max(1, (parent.width - spacing * (root._cavaBars - 1)) / root._cavaBars)
            Repeater {
                model: root._bars
                delegate: Item {
                    required property int modelData
                    required property int index
                    width: parent.barW; height: 32
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width:  parent.width
                        readonly property real _amp: root.isPlaying ? (modelData / 100) : 0
                        height: Math.max(2, _amp * 32)
                        radius: width / 2
                        color:  Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.25 + _amp * 0.65)
                        Behavior on height { NumberAnimation { duration: 50; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    // Border
    Rectangle {
        anchors.fill: parent
        radius:       Theme.cornerRadius
        color:        "transparent"
        border.color: Qt.rgba(1,1,1,0.08)
        border.width: 1
    }

    // Close dropdown on click outside
    TapHandler {
        enabled: root._dropdownOpen
        onTapped: root._dropdownOpen = false
    }
}
