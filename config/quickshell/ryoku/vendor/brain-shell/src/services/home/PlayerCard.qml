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
  backgroundAlpha: 0
  borderAlpha: 0
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
  readonly property string album: {
    var al = root.player?.trackAlbum
    return (al && al !== "") ? al : ""
  }

  readonly property real length: root.player?.length ?? 0
  readonly property real position: root.player?.position ?? 0

  property var _eqBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  readonly property var _eqBandModel: [
    { idx: 1, label: "32" },
    { idx: 2, label: "64" },
    { idx: 3, label: "125" },
    { idx: 4, label: "250" },
    { idx: 5, label: "500" },
    { idx: 6, label: "1K" },
    { idx: 7, label: "2K" },
    { idx: 8, label: "4K" },
    { idx: 9, label: "8K" },
    { idx: 10, label: "16K" }
  ]
  property bool _effectsOpen: false
  property real _eqLightningProgress: 0
  property real _eqLightningFade: 1

  property real _pos: 0
  onPositionChanged: root._pos = position
  onVisibleChanged: {
    if (!visible) {
      root._dropdownOpen = false
      root._effectsOpen = false
      Popups.playerEqualizerOpen = false
    }
  }

  Process {
    id: audioEffectProc
    command: []
    running: false
  }

  SequentialAnimation {
    id: eqLightningAnim
    running: false

    ScriptAction {
      script: {
        root._eqLightningProgress = 0
        root._eqLightningFade = 0
        eqLightningCanvas.requestPaint()
      }
    }

    NumberAnimation {
      target: root
      property: "_eqLightningProgress"
      from: 0
      to: 10
      duration: 560
      easing.type: Easing.OutSine
    }

    PauseAnimation { duration: 90 }

    NumberAnimation {
      target: root
      property: "_eqLightningFade"
      from: 0
      to: 1
      duration: 700
      easing.type: Easing.OutQuad
    }
  }

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
  readonly property int _orbitBars: 44
  readonly property int _stripBars: 32
  readonly property real _surfaceAlpha: 0.035
  readonly property real _panelAlpha: 0.075
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

  Connections {
    target: Popups
    function onDashboardOpenChanged() {
      if (!Popups.dashboardOpen) {
        root._effectsOpen = false
        Popups.playerEqualizerOpen = false
      }
    }
  }

  function _toggleEffects() {
    root._effectsOpen = !root._effectsOpen
    Popups.playerEqualizerOpen = root._effectsOpen
    if (root._effectsOpen)
      root._triggerEqLightning()
  }

  function _eqNorm(value) {
    return Math.max(0, Math.min(1, (value + 12) / 24))
  }

  function _triggerEqLightning() {
    eqLightningAnim.restart()
  }

  function _rgbaCss(color, alpha) {
    return "rgba("
      + Math.round(color.r * 255) + ","
      + Math.round(color.g * 255) + ","
      + Math.round(color.b * 255) + ","
      + alpha + ")"
  }

  function _setEqBand(index, value) {
    if (index < 1 || index > root._eqBands.length)
      return

    var v = Math.max(-12, Math.min(12, Math.round(value)))
    var next = root._eqBands.slice()
    next[index - 1] = v
    root._eqBands = next
    root._triggerEqLightning()
    audioEffectProc.running = false
    audioEffectProc.command = [
      "ryoku-audio-effects",
      "eq-set",
      String(index),
      String(v)
    ]
    audioEffectProc.running = true
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

  readonly property int _discSize: Math.max(68, Math.min(90, Math.floor(root.height * 0.32)))
  readonly property int _orbitSize: root._discSize + 44

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

  component EqualizerBand: Item {
    id: band
    property int bandIndex: 1
    property string label: "1K"
    property real value: 0
    property color accent: Theme.active
    signal changed(real value)

    width: 20
    height: 96

    function _applyFromY(yPos) {
      var v = 12 - Math.max(0, Math.min(1, yPos / Math.max(1, track.height))) * 24
      band.changed(v)
    }

    Rectangle {
      id: track
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      width: 8
      height: parent.height - freqLabel.height - 10
      radius: 4
      color: Qt.rgba(1, 1, 1, 0.060)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, bandHit.hovered ? 0.16 : 0.08)

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 2
        height: Math.max(3, (parent.height - 4) * root._eqNorm(band.value))
        radius: 3
        color: Qt.rgba(band.accent.r, band.accent.g, band.accent.b, bandHit.hovered ? 0.86 : 0.58)

        Behavior on height {
          enabled: !Theme.staticMode
          NumberAnimation { duration: 120; easing.type: Easing.OutQuart }
        }
      }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(0, Math.min(parent.height - height, (1 - root._eqNorm(band.value)) * (parent.height - height)))
        width: 16
        height: 9
        radius: 4
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, bandHit.hovered ? 0.78 : 0.52)

        Behavior on y {
          enabled: !Theme.staticMode
          NumberAnimation { duration: 120; easing.type: Easing.OutQuart }
        }
      }

      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Qt.rgba(1, 1, 1, 0.20)
      }
    }

    Text {
      id: freqLabel
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      text: band.label
      font.pixelSize: 7
      font.weight: Font.Bold
      font.family: "JetBrains Mono"
      color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.48)
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton
      onPressed: function(mouse) { band._applyFromY(mouse.y) }
      onPositionChanged: function(mouse) {
        if (pressed) band._applyFromY(mouse.y)
      }
      onWheel: function(wheel) {
        var step = wheel.angleDelta.y > 0 ? 1 : -1
        band.changed(band.value + step)
        wheel.accepted = true
      }
    }

    HoverHandler {
      id: bandHit
      cursorShape: Qt.PointingHandCursor
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
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.004) }
        GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.001) }
        GradientStop { position: 1.0; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.006) }
      }
    }

    Rectangle {
      id: panelBody
      objectName: "playerOffsetPanel"
      anchors.fill: parent
      anchors.margins: 10
      radius: Math.max(18, Theme.cornerRadius)
      color: Qt.rgba(9 / 255, 14 / 255, 22 / 255, root._panelAlpha)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.032)
    }

    Rectangle {
      anchors.left: panelBody.left
      anchors.right: panelBody.right
      anchors.top: panelBody.top
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      anchors.topMargin: 13
      height: 1
      color: Qt.rgba(1, 1, 1, 0.055)
    }

    Rectangle {
      anchors.left: panelBody.left
      anchors.top: panelBody.top
      anchors.leftMargin: 14
      anchors.topMargin: 13
      width: 44
      height: 1
      color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.48)
    }

    Item {
      id: sourcePicker
      anchors.right: panelBody.right
      anchors.top: panelBody.top
      anchors.rightMargin: 16
      anchors.topMargin: 10
      width: 96
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

    Text {
      id: titleLabel
      anchors.left: panelBody.left
      anchors.right: panelBody.right
      anchors.top: panelBody.top
      anchors.leftMargin: 18
      anchors.rightMargin: sourcePicker.visible ? 122 : 18
      anchors.topMargin: 22
      text: root.title
      elide: Text.ElideRight
      horizontalAlignment: Text.AlignLeft
      font.pixelSize: 16
      font.weight: Font.DemiBold
      color: Theme.text
    }

    Item {
      id: discStage
      anchors.left: panelBody.left
      anchors.top: titleLabel.bottom
      anchors.leftMargin: 18
      anchors.topMargin: 16
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
            readonly property real orbitRadius: Math.min(cavaOrbit.width, cavaOrbit.height) / 2 - 7

            width: 2.8
            height: 5 + amp * 26
            radius: width / 2
            x: cavaOrbit.width / 2 + Math.cos(angleRad) * orbitRadius - width / 2
            y: cavaOrbit.height / 2 + Math.sin(angleRad) * orbitRadius - height / 2
            rotation: angleDeg + 90
            color: Qt.rgba(
              Theme.active.r,
              Theme.active.g,
              Theme.active.b,
              root._barsPlaying ? 0.34 + amp * 0.66 : 0.22
            )

            Behavior on height {
              enabled: !Theme.staticMode
              NumberAnimation { duration: 45; easing.type: Easing.OutCubic }
            }
          }
        }
      }

      Rectangle {
        anchors.centerIn: parent
        width: root._discSize + 8
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
      anchors.left: discStage.right
      anchors.right: panelBody.right
      anchors.top: titleLabel.bottom
      anchors.bottom: effectDeck.top
      anchors.leftMargin: 42
      anchors.rightMargin: 18
      anchors.topMargin: 10
      anchors.bottomMargin: 12
      z: 6

      Text {
        id: artistLabel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        text: root.artist !== "" ? root.artist : root._playerLabel(root.player)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignLeft
        font.pixelSize: 10
        font.weight: Font.Bold
        font.family: "JetBrains Mono"
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.68)
      }

      Text {
        id: albumLabel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: artistLabel.bottom
        anchors.topMargin: 3
        text: root.album !== "" ? root.album : (root.player ? root._playerLabel(root.player) : "NO SIGNAL")
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignLeft
        font.pixelSize: 8
        font.family: "JetBrains Mono"
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.46)
      }

      Item {
        id: progressBlock
        objectName: "playerWaveSeek"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: albumLabel.bottom
        anchors.topMargin: 9
        height: 28

        Item {
          id: progressTrack
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          height: 16

          WaveBar {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            value: 1
            color: Qt.rgba(1, 1, 1, 0.13)
            wavelength: 14
            amplitude: 2
            strokeWidth: 2
            speed: 5200
          }

          WaveBar {
            id: seekWaveBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            value: root._progress
            color: Theme.active
            wavelength: 14
            amplitude: 2
            strokeWidth: 2
            speed: 4000
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

    }

    Item {
      id: effectDeck
      objectName: "audioEffectDeck"
      anchors.left: root._effectsOpen ? panelBody.left : discStage.right
      anchors.right: panelBody.right
      anchors.bottom: controlsBlock.top
      anchors.leftMargin: root._effectsOpen ? 18 : 42
      anchors.rightMargin: 18
      anchors.bottomMargin: 10
      height: root._effectsOpen ? 132 : 28
      clip: true
      z: 30

      Behavior on height {
        enabled: !Theme.staticMode
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }

      Rectangle {
        anchors.fill: parent
        radius: 9
        color: Qt.rgba(12 / 255, 18 / 255, 24 / 255, root._effectsOpen ? 0.60 : 0.22)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, root._effectsOpen ? 0.12 : 0.07)
      }

      Rectangle {
        id: effectsToggle
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root._effectsOpen ? 24 : parent.height
        radius: 9
        color: Qt.rgba(1, 1, 1, fxHit.hovered ? 0.070 : 0.038)
        border.width: root._effectsOpen ? 0 : 1
        border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, fxHit.hovered ? 0.34 : 0.20)

        Text {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: 10
          text: root._effectsOpen ? "EQ 10" : "FX"
          font.pixelSize: 8
          font.weight: Font.Bold
          font.family: "JetBrains Mono"
          color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.76)
        }

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.rightMargin: 10
          spacing: 2
          visible: !root._effectsOpen

          Repeater {
            model: root._eqBandModel

            Rectangle {
              required property var modelData
              readonly property real bandValue: root._eqBands[modelData.idx - 1] || 0
              width: 5
              height: 4 + Math.abs(bandValue) * 0.35
              radius: 2
              color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.32 + root._eqNorm(bandValue) * 0.24)
            }
          }
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.rightMargin: 10
          visible: root._effectsOpen
          text: "CLOSE"
          font.pixelSize: 7
          font.weight: Font.Bold
          font.family: "JetBrains Mono"
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.44)
        }

        HoverHandler {
          id: fxHit
          cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root._toggleEffects()
        }
      }

      Item {
        id: eqPanel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: effectsToggle.bottom
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 4
        anchors.bottomMargin: 5
        visible: root._effectsOpen

        Canvas {
          id: eqLightningCanvas
          anchors.fill: parent
          opacity: 1 - root._eqLightningFade
          renderTarget: Canvas.FramebufferObject

          onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (root._eqLightningFade >= 1 || root._eqLightningProgress <= 0)
              return

            var points = []
            for (var i = 0; i < root._eqBandModel.length; i++) {
              var value = root._eqBands[i] || 0
              points.push({
                x: (i + 0.5) * (width / root._eqBandModel.length),
                y: 10 + (1 - root._eqNorm(value)) * (height - 28)
              })
            }

            var now = Date.now() / 1000
            var maxSegment = Math.min(points.length - 1, root._eqLightningProgress)
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            for (var strand = 0; strand < 3; strand++) {
              ctx.beginPath()
              ctx.moveTo(points[0].x, points[0].y)

              for (var seg = 0; seg < points.length - 1; seg++) {
                if (seg > maxSegment)
                  break

                var p1 = points[seg]
                var p2 = points[seg + 1]
                var fraction = Math.min(1, Math.max(0, maxSegment - seg))
                if (fraction === 0 && seg === Math.floor(maxSegment))
                  fraction = maxSegment - seg
                if (seg < Math.floor(maxSegment))
                  fraction = 1

                var steps = 6
                for (var step = 1; step <= steps; step++) {
                  var t = step / steps
                  if (t > fraction)
                    break

                  var wave = Math.sin(now * (5 + strand) + seg + step) * (strand + 1) * 3
                  var jitter = Math.cos(now * 7 - seg + step) * (strand + 1) * 2
                  ctx.lineTo(
                    p1.x + (p2.x - p1.x) * t + wave,
                    p1.y + (p2.y - p1.y) * t + jitter
                  )
                }
              }

              ctx.globalAlpha = (strand === 0 ? 0.22 : strand === 1 ? 0.48 : 0.86) * (1 - root._eqLightningFade)
              ctx.lineWidth = strand === 0 ? 11 : strand === 1 ? 4 : 1.4
              ctx.strokeStyle = strand === 0 ? root._rgbaCss(Theme.active, 0.80)
                                             : strand === 1 ? root._rgbaCss(Theme.text, 0.72)
                                                           : "#ffffff"
              ctx.stroke()
            }
          }

          Connections {
            target: root
            function on_EqLightningProgressChanged() { eqLightningCanvas.requestPaint() }
            function on_EqLightningFadeChanged() { eqLightningCanvas.requestPaint() }
          }
        }

        Row {
          anchors.centerIn: parent
          height: parent.height
          spacing: 6

          Repeater {
            model: root._eqBandModel

            EqualizerBand {
              required property var modelData
              bandIndex: modelData.idx
              label: modelData.label
              value: root._eqBands[modelData.idx - 1] || 0
              height: parent.height
              onChanged: function(value) { root._setEqBand(modelData.idx, value) }
            }
          }
        }
      }
    }

    Item {
      id: controlsBlock
      objectName: "playerBottomControls"
      anchors.left: panelBody.left
      anchors.right: panelBody.right
      anchors.bottom: panelBody.bottom
      anchors.leftMargin: 18
      anchors.rightMargin: 18
      anchors.bottomMargin: 16
      height: 32
      z: 34

      Row {
        id: playbackControls
        objectName: "playbackDeck"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

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

            width: isPlay ? 50 : 42
            height: 28
            radius: 8
            opacity: actionEnabled ? 1 : 0.42
            color: isPlay
              ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, controlHit.hovered ? 0.30 : 0.22)
              : Qt.rgba(18 / 255, 30 / 255, 36 / 255, controlHit.hovered ? 0.42 : 0.28)
            border.width: 1
            border.color: isPlay
              ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, controlHit.hovered ? 0.62 : 0.44)
              : Qt.rgba(1, 1, 1, controlHit.hovered ? 0.16 : 0.08)

            Rectangle {
              anchors.fill: parent
              anchors.margins: 4
              radius: 6
              color: Qt.rgba(1, 1, 1, parent.isPlay ? 0.038 : 0.024)
            }

            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.top
              anchors.topMargin: parent.isPlay ? 7 : 6
              width: parent.isPlay ? 14 : 10
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

    Item {
      id: quietCavaStrip
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 14
      opacity: 0.18
      visible: false

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

    TapHandler {
      enabled: root._dropdownOpen
      onTapped: root._dropdownOpen = false
    }
  }
}
