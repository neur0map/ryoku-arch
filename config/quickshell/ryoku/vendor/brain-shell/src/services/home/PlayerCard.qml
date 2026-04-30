import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"
import "../../components"

StatCard {
  id: root
  padding: 0
  clip: true

  // Source allowlist
  readonly property var _allowed: [
    "spotify", "youtube",
    "firefox", "chromium", "chrome",
    "brave", "edge", "opera", "vivaldi", "safari", "arc"
  ]

  // Explicit count tracker forces filteredPlayers to re-evaluate whenever
  // a player joins or leaves the MPRIS list.
  property int _mprisCount: Mpris.players.values.length

  readonly property var filteredPlayers: {
    var _dep = root._mprisCount
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
    var oldPlayer = root.player
    if (oldPlayer) {
      for (var i = 0; i < root.filteredPlayers.length; i++) {
        if (root.filteredPlayers[i] === oldPlayer) {
          root.selectedPlayerIndex = i
          return
        }
      }
    }
    if (root.selectedPlayerIndex >= root.filteredPlayers.length)
      root.selectedPlayerIndex = Math.max(0, root.filteredPlayers.length - 1)
  }

  // MPRIS
  readonly property var player: root.filteredPlayers.length > 0
                                ? root.filteredPlayers[root.selectedPlayerIndex] : null

  readonly property bool isPlaying: root.player?.playbackState === MprisPlaybackState.Playing ?? false
  readonly property string artUrl: root.player?.trackArtUrl ?? ""

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

  readonly property real length: root.player?.length ?? 0
  readonly property real position: root.player?.position ?? 0

  property real _pos: 0
  onPositionChanged: root._pos = position

  Timer {
    interval: 1000
    running: root.isPlaying
    repeat: true
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

  // Shared Cava signal
  readonly property int _orbitBars: 28
  readonly property int _seekBars: 56
  readonly property int _stripBars: 32
  readonly property real _surfaceAlpha: 0.26
  readonly property var _bars: CavaService.bars
  readonly property bool _barsPlaying: CavaService.isPlaying

  function _barValue(i) {
    if (!root._bars || root._bars.length === 0) return 0
    var idx = Math.min(root._bars.length - 1, Math.floor(i * root._bars.length / Math.max(1, root._orbitBars)))
    return root._bars[idx] || 0
  }

  function _stripValue(i) {
    if (!root._bars || root._bars.length === 0) return 0
    var idx = Math.min(root._bars.length - 1, Math.floor(i * root._bars.length / Math.max(1, root._stripBars)))
    return root._bars[idx] || 0
  }

  function _seekValue(i) {
    if (root._bars && root._bars.length > 0 && root._barsPlaying) {
      var idx = Math.min(root._bars.length - 1, Math.floor(i * root._bars.length / Math.max(1, root._seekBars)))
      return root._bars[idx] || 0
    }
    return 18 + ((i * 17) % 41)
  }

  function _playerIcon(player) {
    if (!player) return "♪"
    var id = (player.identity || "").toLowerCase()
    if (id.indexOf("spotify") !== -1) return "S"
    if (id.indexOf("firefox") !== -1) return "F"
    if (id.indexOf("chromium") !== -1) return "C"
    if (id.indexOf("chrome") !== -1) return "C"
    if (id.indexOf("brave") !== -1) return "B"
    if (id.indexOf("youtube") !== -1) return "Y"
    return "♪"
  }

  function _playerLabel(player) {
    if (!player) return "NO SIGNAL"
    var id = (player.identity || "").toLowerCase()
    if (id.indexOf("spotify") !== -1) return "Spotify"
    if (id.indexOf("firefox") !== -1) return "Firefox"
    if (id.indexOf("chromium") !== -1) return "Chromium"
    if (id.indexOf("chrome") !== -1) return "Chrome"
    if (id.indexOf("brave") !== -1) return "Brave"
    if (id.indexOf("youtube") !== -1) return "YouTube"
    if (id.indexOf("edge") !== -1) return "Edge"
    if (id.indexOf("opera") !== -1) return "Opera"
    if (id.indexOf("vivaldi") !== -1) return "Vivaldi"
    return player.identity || "Player"
  }

  readonly property int _discSize: Math.max(104, Math.min(142, Math.floor(root.height * 0.40)))
  readonly property int _orbitSize: root._discSize + 34
  readonly property int _panelLeft: Math.max(72, Math.floor(root._discSize * 0.58))
  readonly property int _contentLeftInset: Math.max(128, root._orbitSize - root._panelLeft + 24)

  component ChevronMark: Item {
    id: chevron
    property bool pointsLeft: false
    property color strokeColor: Theme.text

    width: 7
    height: 11

    Rectangle {
      width: 2
      height: 8
      radius: 1
      x: chevron.pointsLeft ? 2 : 3
      y: 1
      rotation: chevron.pointsLeft ? 38 : -38
      color: chevron.strokeColor
      antialiasing: true
    }

    Rectangle {
      width: 2
      height: 8
      radius: 1
      x: chevron.pointsLeft ? 2 : 3
      y: 5
      rotation: chevron.pointsLeft ? -38 : 38
      color: chevron.strokeColor
      antialiasing: true
    }
  }

  component TransportGlyph: Item {
    id: glyph
    property string mode: "play"
    property bool playing: false
    property color glyphColor: Theme.text

    width: 20
    height: 18

    Rectangle {
      visible: glyph.mode === "prev"
      x: 2
      y: 4
      width: 2
      height: 10
      radius: 1
      color: glyph.glyphColor
    }

    Rectangle {
      visible: glyph.mode === "next"
      x: 16
      y: 4
      width: 2
      height: 10
      radius: 1
      color: glyph.glyphColor
    }

    ChevronMark {
      visible: glyph.mode === "prev"
      pointsLeft: true
      strokeColor: glyph.glyphColor
      x: 6
      y: 4
    }

    ChevronMark {
      visible: glyph.mode === "prev"
      pointsLeft: true
      strokeColor: glyph.glyphColor
      x: 11
      y: 4
    }

    ChevronMark {
      visible: glyph.mode === "next"
      strokeColor: glyph.glyphColor
      x: 2
      y: 4
    }

    ChevronMark {
      visible: glyph.mode === "next"
      strokeColor: glyph.glyphColor
      x: 7
      y: 4
    }

    Shape {
      visible: glyph.mode === "play" && !glyph.playing
      anchors.centerIn: parent
      width: 15
      height: 16
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: glyph.glyphColor
        strokeWidth: 0
        startX: 4
        startY: 3
        PathLine { x: 4; y: 13 }
        PathLine { x: 12; y: 8 }
        PathLine { x: 4; y: 3 }
      }
    }

    Row {
      visible: glyph.mode === "play" && glyph.playing
      anchors.centerIn: parent
      spacing: 4

      Repeater {
        model: 2

        Rectangle {
          width: 3
          height: 11
          radius: 1
          color: glyph.glyphColor
        }
      }
    }
  }

  Item {
    id: discConsole
    anchors.fill: parent
    clip: true

    Rectangle {
      anchors.fill: parent
      radius: Theme.cornerRadius
      color: Qt.rgba(8 / 255, 12 / 255, 18 / 255, root._surfaceAlpha)
    }

    Rectangle {
      anchors.fill: parent
      radius: Theme.cornerRadius
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.028) }
        GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.010) }
        GradientStop { position: 1.0; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.034) }
      }
    }

    Rectangle {
      id: panelBody
      objectName: "playerOffsetPanel"
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.leftMargin: root._panelLeft
      anchors.rightMargin: 12
      anchors.topMargin: 18
      anchors.bottomMargin: 18
      radius: Math.max(18, Theme.cornerRadius)
      color: Qt.rgba(9 / 255, 14 / 255, 22 / 255, 0.42)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.075)
    }

    Rectangle {
      anchors.left: panelBody.left
      anchors.right: panelBody.right
      anchors.top: panelBody.top
      anchors.leftMargin: 18
      anchors.rightMargin: 18
      anchors.topMargin: 16
      height: 1
      color: Qt.rgba(1, 1, 1, 0.065)
    }

    Rectangle {
      anchors.left: panelBody.left
      anchors.top: panelBody.top
      anchors.leftMargin: 18
      anchors.topMargin: 16
      width: 42
      height: 1
      color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.48)
    }

    Text {
      anchors.left: panelBody.left
      anchors.top: panelBody.top
      anchors.leftMargin: 20
      anchors.topMargin: 22
      text: root.player ? "AUDIO" : "NO SIGNAL"
      font.pixelSize: 8
      font.weight: Font.Bold
      font.family: "JetBrains Mono"
      color: root.player ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.74)
                         : Qt.rgba(1, 1, 1, 0.32)
    }

    Item {
      id: sourcePicker
      anchors.right: panelBody.right
      anchors.top: panelBody.top
      anchors.rightMargin: 18
      anchors.topMargin: 12
      width: 106
      height: sourcePill.height
      visible: root.filteredPlayers.length > 1
      z: 40

      Rectangle {
        id: sourcePill
        anchors.right: parent.right
        width: parent.width
        height: root._dropdownOpen ? Math.min(96, 22 * root.filteredPlayers.length) : 22
        radius: 7
        clip: true
        color: Qt.rgba(1, 1, 1, 0.055)
        border.width: 1
        border.color: root._dropdownOpen
          ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.34)
          : Qt.rgba(1, 1, 1, 0.10)

        Behavior on height {
          enabled: !Theme.staticMode
          NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
        }

        Column {
          anchors.fill: parent
          anchors.margins: 0
          spacing: 0

          Repeater {
            model: root.filteredPlayers

            delegate: Item {
              required property var modelData
              required property int index
              readonly property bool rowVisible: index === root.selectedPlayerIndex || root._dropdownOpen
              width: sourcePill.width
              height: rowVisible ? 22 : 0
              visible: rowVisible

              Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 8
                anchors.rightMargin: 6
                spacing: 5

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root._playerIcon(modelData)
                  font.pixelSize: 9
                  color: index === root.selectedPlayerIndex ? Theme.active : Qt.rgba(1, 1, 1, 0.48)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 18
                  text: root._playerLabel(modelData).toUpperCase()
                  elide: Text.ElideRight
                  font.pixelSize: 8
                  font.weight: Font.DemiBold
                  font.family: "JetBrains Mono"
                  color: rowHit.hovered ? Qt.rgba(1, 1, 1, 0.92)
                                        : Qt.rgba(1, 1, 1, 0.58)
                }
              }

              HoverHandler {
                id: rowHit
                cursorShape: Qt.PointingHandCursor
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  if (index === root.selectedPlayerIndex) {
                    root._dropdownOpen = !root._dropdownOpen
                  } else {
                    root.selectedPlayerIndex = index
                    root._dropdownOpen = false
                  }
                }
              }
            }
          }
        }
      }
    }

    Item {
      id: discStage
      anchors.left: parent.left
      anchors.verticalCenter: panelBody.verticalCenter
      anchors.leftMargin: 8
      anchors.verticalCenterOffset: -12
      width: root._orbitSize
      height: root._orbitSize
      z: 8

      Item {
        id: cavaOrbit
        anchors.fill: parent

        Repeater {
          model: root._orbitBars

          delegate: Rectangle {
            required property int index
            readonly property real amp: root._barsPlaying ? (root._barValue(index) / 100) : 0
            readonly property real angleDeg: -150 + index * (300 / Math.max(1, root._orbitBars - 1))
            readonly property real angleRad: angleDeg * Math.PI / 180
            readonly property real orbitRadius: Math.min(cavaOrbit.width, cavaOrbit.height) / 2 - 9

            width: 3
            height: 7 + amp * 18
            radius: width / 2
            x: cavaOrbit.width / 2 + Math.cos(angleRad) * orbitRadius - width / 2
            y: cavaOrbit.height / 2 + Math.sin(angleRad) * orbitRadius - height / 2
            rotation: angleDeg + 90
            color: Qt.rgba(
              Theme.active.r,
              Theme.active.g,
              Theme.active.b,
              root._barsPlaying ? 0.34 + amp * 0.56 : 0.18
            )

            Behavior on height {
              enabled: !Theme.staticMode
              NumberAnimation { duration: 70; easing.type: Easing.OutCubic }
            }
          }
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: root._discSize + 14
        height: width
        radius: width / 2
        color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.075)
        border.width: 1
        border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.32)
      }

      Item {
        id: albumDisc
        anchors.centerIn: parent
        width: root._discSize
        height: root._discSize

        Rectangle {
          id: albumMask
          anchors.fill: parent
          radius: width / 2
          visible: false
          layer.enabled: true
        }

        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.12)
        }

        Image {
          anchors.fill: parent
          source: root.artUrl
          fillMode: Image.PreserveAspectCrop
          smooth: true
          visible: root.artUrl !== ""
          layer.enabled: true
          layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: albumMask
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
          }
        }

        Text {
          anchors.centerIn: parent
          text: root.player ? "♪" : "--"
          visible: root.artUrl === ""
          font.pixelSize: root.player ? 28 : 22
          font.weight: Font.Bold
          color: Theme.active
        }

        Rectangle {
          anchors.centerIn: parent
          width: 13
          height: 13
          radius: width / 2
          color: Qt.rgba(8 / 255, 12 / 255, 18 / 255, 0.82)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.20)
        }
      }
    }

    Item {
      id: mediaStack
      objectName: "playerSideConsole"
      anchors.left: panelBody.left
      anchors.right: panelBody.right
      anchors.top: panelBody.top
      anchors.bottom: panelBody.bottom
      anchors.leftMargin: root._contentLeftInset
      anchors.rightMargin: 24
      anchors.topMargin: 34
      anchors.bottomMargin: 18
      z: 6

      Text {
        id: titleLabel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        text: root.title
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 18
        font.weight: Font.DemiBold
        color: Theme.text
      }

      Text {
        id: artistLabel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleLabel.bottom
        anchors.topMargin: 2
        text: root.artist !== "" ? root.artist : root._playerLabel(root.player)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 10
        font.family: "JetBrains Mono"
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.46)
      }

      Item {
        id: progressBlock
        objectName: "playerWaveSeek"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: artistLabel.bottom
        anchors.topMargin: 8
        height: 34

        Item {
          id: progressTrack
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: 18

          Row {
            id: seekWaveBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: parent.height
            spacing: 1
            readonly property real barW: Math.max(2, (width - spacing * (root._seekBars - 1)) / root._seekBars)

            Repeater {
              model: root._seekBars

              delegate: Rectangle {
                required property int index
                readonly property real amp: root._seekValue(index) / 100
                readonly property bool played: root.length > 0 && ((index + 0.5) / root._seekBars) <= root._progress
                width: seekWaveBar.barW
                height: Math.max(3, 4 + amp * 10)
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: played
                  ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.50 + amp * 0.34)
                  : Qt.rgba(1, 1, 1, 0.075 + amp * 0.12)

                Behavior on height {
                  enabled: !Theme.staticMode
                  NumberAnimation { duration: 75; easing.type: Easing.OutCubic }
                }
              }
            }
          }

          Rectangle {
            x: Math.max(0, Math.min(parent.width - width, parent.width * root._progress - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: width / 2
            color: Theme.active
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.35)
            visible: root.length > 0
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: function(mouse) {
              if (root.player && root.length > 0) {
                var f = Math.max(0, Math.min(1, mouse.x / width))
                root.player.position = f * root.length
                root._pos = f * root.length
              }
            }
          }
        }

        Row {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom

          Text {
            id: startTime
            text: root._fmt(root._pos)
            font.pixelSize: 9
            font.family: "JetBrains Mono"
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
          }

          Item {
            width: Math.max(0, parent.width - startTime.width - endTime.width)
            height: 1
          }

          Text {
            id: endTime
            text: root._fmt(root.length)
            font.pixelSize: 9
            font.family: "JetBrains Mono"
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
          }
        }
      }

      Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: progressBlock.bottom
        anchors.topMargin: 6
        height: 50

        Row {
          id: playbackControls
          objectName: "playbackDeck"
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.horizontalCenterOffset: -14
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8

          Repeater {
            model: [ { key: "prev" }, { key: "play" }, { key: "next" } ]

            delegate: Rectangle {
              required property var modelData
              readonly property bool isPlay: modelData.key === "play"
              readonly property bool actionEnabled: {
                if (!root.player) return false
                if (modelData.key === "play") return root.player.canTogglePlaying
                if (modelData.key === "prev") return root.player.canGoPrevious
                if (modelData.key === "next") return root.player.canGoNext
                return false
              }

              width: isPlay ? 46 : 38
              height: width
              radius: width / 2
              opacity: actionEnabled ? 1 : 0.42
              color: isPlay
                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, controlHit.hovered ? 0.32 : 0.24)
                : Qt.rgba(18 / 255, 36 / 255, 42 / 255, controlHit.hovered ? 0.46 : 0.34)
              border.width: 1
              border.color: isPlay
                ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, controlHit.hovered ? 0.62 : 0.44)
                : Qt.rgba(1, 1, 1, controlHit.hovered ? 0.16 : 0.08)

              Rectangle {
                anchors.centerIn: parent
                width: parent.width - (parent.isPlay ? 18 : 16)
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, parent.isPlay ? 0.040 : 0.026)
              }

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: parent.isPlay ? 10 : 8
                width: parent.isPlay ? 20 : 16
                height: 1
                color: Qt.rgba(
                  parent.isPlay ? Theme.active.r : 1,
                  parent.isPlay ? Theme.active.g : 1,
                  parent.isPlay ? Theme.active.b : 1,
                  parent.isPlay ? 0.50 : 0.16
                )
              }

              Behavior on color {
                enabled: !Theme.staticMode
                ColorAnimation { duration: 130 }
              }

              TransportGlyph {
                anchors.centerIn: parent
                mode: modelData.key
                playing: root.isPlaying
                glyphColor: isPlay ? Theme.text
                                    : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, controlHit.hovered ? 0.84 : 0.58)
              }

              HoverHandler {
                id: controlHit
                cursorShape: parent.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              }

              MouseArea {
                anchors.fill: parent
                enabled: parent.actionEnabled
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
      }
    }

    Item {
      id: quietCavaStrip
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 14
      opacity: 0.18

      Row {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 2
        readonly property real barW: Math.max(1, (parent.width - spacing * (root._stripBars - 1)) / root._stripBars)

        Repeater {
          model: root._stripBars

          delegate: Rectangle {
            required property int index
            readonly property real amp: root._barsPlaying ? (root._stripValue(index) / 100) : 0
            width: parent.barW
            height: Math.max(2, amp * 13)
            anchors.bottom: parent.bottom
            radius: width / 2
            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.20 + amp * 0.38)

            Behavior on height {
              enabled: !Theme.staticMode
              NumberAnimation { duration: 55; easing.type: Easing.OutCubic }
            }
          }
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: Theme.cornerRadius
      color: "transparent"
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.065)
    }

    TapHandler {
      enabled: root._dropdownOpen
      onTapped: root._dropdownOpen = false
    }
  }
}
