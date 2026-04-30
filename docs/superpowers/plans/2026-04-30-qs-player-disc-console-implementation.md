# QS Player Disc Console Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dashboard `PlayerCard` blurred album-art card with a compact Ryoku disc-console player that keeps MPRIS behavior and integrates Cava as a circular signal ring.

**Architecture:** Keep the change local to the dashboard player. Add one static regression test for the player card, then replace `PlayerCard.qml` with a `StatCard`-backed single-file implementation: existing MPRIS selection/state code stays at the top, while the visual layer becomes a fixed-zone disc console with circular album art, Cava orbit ticks, compact source switching, controls, and progress.

**Tech Stack:** Quickshell QML, QtQuick, QtQuick.Effects, Quickshell.Services.Mpris, existing `Theme`, `StatCard`, and `CavaService`.

---

## File Structure

- Create `tests/quickshell-player-card.sh`: static regression checks for the Ryoku disc-console player design and MPRIS behavior wiring.
- Modify `config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml`: replace the current full-card blurred album-art player with the disc-console implementation.

No dashboard size, `DashHome.qml`, `Dashboard.qml`, `CavaService.qml`, or `qmldir` changes are part of this plan.

Before executing tasks, run `git status --short`. The current worktree may contain unrelated user changes. Stage only files listed in each task and do not revert unrelated changes.

---

### Task 1: Add PlayerCard Regression Test

**Files:**
- Create: `tests/quickshell-player-card.sh`

- [ ] **Step 1: Create the failing static test**

Create `tests/quickshell-player-card.sh` with executable mode:

```bash
#!/bin/bash
# Static regression checks for the dashboard PlayerCard disc-console redesign.

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

active_lines() {
  sed '/^[[:space:]]*\/\//d' "$1"
}

active_has() {
  active_lines "$1" | grep -F -- "$2" >/dev/null
}

player="config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml"

[[ -f $player ]] || fail "$player missing"

active_has "$player" 'StatCard {' \
  || fail "PlayerCard should use the shared StatCard surface"
active_has "$player" 'padding: 0' \
  || fail "PlayerCard should opt into full-surface custom layout inside StatCard"
active_has "$player" 'id: discConsole' \
  || fail "PlayerCard should expose a disc-console root layout"
active_has "$player" 'id: albumDisc' \
  || fail "PlayerCard should render circular album art as a disc"
active_has "$player" 'id: albumMask' \
  || fail "PlayerCard should mask album art to a circle"
active_has "$player" 'maskSource: albumMask' \
  || fail "PlayerCard should apply the circular album-art mask through MultiEffect"
active_has "$player" 'id: cavaOrbit' \
  || fail "PlayerCard should render Cava as a disc orbit"
active_has "$player" 'readonly property int _orbitBars' \
  || fail "PlayerCard should define a stable Cava orbit bar count"
active_has "$player" 'root._barValue(index)' \
  || fail "Cava orbit ticks should read shared Cava values"
active_has "$player" 'CavaService.isPlaying' \
  || fail "PlayerCard should keep shared CavaService playback gating"
active_has "$player" 'id: sourcePicker' \
  || fail "PlayerCard should keep multi-player source switching"
active_has "$player" 'root.filteredPlayers.length > 1' \
  || fail "Source picker should only appear when multiple players exist"
active_has "$player" 'root.selectedPlayerIndex = index' \
  || fail "Source picker should update selectedPlayerIndex"
active_has "$player" 'id: playbackControls' \
  || fail "PlayerCard should render explicit playback controls"
active_has "$player" 'root.player.canTogglePlaying' \
  || fail "Play button should preserve canTogglePlaying guard"
active_has "$player" 'root.player.canGoPrevious' \
  || fail "Previous button should preserve canGoPrevious guard"
active_has "$player" 'root.player.canGoNext' \
  || fail "Next button should preserve canGoNext guard"
active_has "$player" 'id: progressTrack' \
  || fail "PlayerCard should render a named progress track"
active_has "$player" 'root.player.position = f * root.length' \
  || fail "Progress track should preserve click-to-seek"
active_has "$player" 'font.family: "JetBrains Mono"' \
  || fail "PlayerCard should use JetBrains Mono for console/time details"
active_has "$player" 'NO SIGNAL' \
  || fail "PlayerCard should provide a designed no-player fallback"

if active_has "$player" 'id: bgSource'; then
  fail "PlayerCard should not keep the old full-card album-art background source"
fi
if active_has "$player" 'source:       artSource'; then
  fail "PlayerCard should not feed album art into a full-card background effect"
fi
if active_has "$player" 'blurMax:'; then
  fail "PlayerCard should not use full-card album-art blur"
fi
if active_has "$player" 'Cava bars'; then
  fail "PlayerCard should not keep the old bottom Cava wall as the primary visual"
fi

if command -v qmllint >/dev/null; then
  qmllint -I config/quickshell/ryoku/vendor/brain-shell/src "$player"
fi

pass "quickshell player card disc console"
```

- [ ] **Step 2: Make the test executable**

Run:

```bash
chmod +x tests/quickshell-player-card.sh
```

Expected: no output.

- [ ] **Step 3: Run the test and verify it fails against the current player**

Run:

```bash
bash tests/quickshell-player-card.sh
```

Expected: FAIL with `PlayerCard should use the shared StatCard surface`.

---

### Task 2: Replace PlayerCard With Disc Console

**Files:**
- Modify: `config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml`
- Test: `tests/quickshell-player-card.sh`

- [ ] **Step 1: Replace `PlayerCard.qml` with the disc-console implementation**

Replace the full contents of `config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml` with:

```qml
import QtQuick
import QtQuick.Effects
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
  readonly property int _orbitBars: 24
  readonly property int _stripBars: 32
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

  function _controlIcon(key) {
    if (key === "prev") return "⏮"
    if (key === "next") return "⏭"
    return root.isPlaying ? "⏸" : "⏵"
  }

  readonly property int _discSize: Math.max(78, Math.min(92, Math.floor(root.height * 0.38)))
  readonly property int _orbitSize: root._discSize + 34

  Item {
    id: discConsole
    anchors.fill: parent
    clip: true

    Rectangle {
      anchors.fill: parent
      radius: Theme.cornerRadius
      color: Qt.rgba(8 / 255, 12 / 255, 18 / 255, 0.72)
    }

    Rectangle {
      anchors.fill: parent
      radius: Theme.cornerRadius
      gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.06) }
        GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.025) }
        GradientStop { position: 1.0; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.07) }
      }
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 10
      height: 1
      color: Qt.rgba(1, 1, 1, 0.08)
    }

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.leftMargin: 12
      anchors.topMargin: 10
      width: 42
      height: 1
      color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.62)
    }

    Text {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.leftMargin: 14
      anchors.topMargin: 14
      text: root.player ? "AUDIO" : "NO SIGNAL"
      font.pixelSize: 8
      font.weight: Font.Bold
      font.family: "JetBrains Mono"
      color: root.player ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.74)
                         : Qt.rgba(1, 1, 1, 0.32)
    }

    Item {
      id: sourcePicker
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: 10
      anchors.topMargin: 8
      width: 92
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
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: 18
      width: root._orbitSize
      height: root._orbitSize

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
        color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.08)
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

    Column {
      id: metadata
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: discStage.bottom
      anchors.topMargin: -5
      anchors.leftMargin: 18
      anchors.rightMargin: 18
      spacing: 2

      Text {
        width: parent.width
        text: root.title
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: Theme.text
      }

      Text {
        width: parent.width
        text: root.artist !== "" ? root.artist : root._playerLabel(root.player)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 10
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.50)
      }
    }

    Row {
      id: playbackControls
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: progressBlock.top
      anchors.bottomMargin: 7
      spacing: 13

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

          width: isPlay ? 38 : 30
          height: width
          radius: isPlay ? 10 : 8
          color: isPlay
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, controlHit.hovered ? 0.34 : 0.24)
            : Qt.rgba(1, 1, 1, controlHit.hovered ? 0.11 : 0.055)
          border.width: 1
          border.color: isPlay
            ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.46)
            : Qt.rgba(1, 1, 1, 0.10)
          opacity: actionEnabled ? 1 : 0.42

          Behavior on color {
            enabled: !Theme.staticMode
            ColorAnimation { duration: 120 }
          }

          Text {
            anchors.centerIn: parent
            text: root._controlIcon(modelData.key)
            font.pixelSize: isPlay ? 17 : 13
            color: isPlay ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.72)
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

    Item {
      id: progressBlock
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.leftMargin: 18
      anchors.rightMargin: 18
      anchors.bottomMargin: 12
      height: 24

      Item {
        id: progressTrack
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 7

        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: 3
          radius: height / 2
          color: Qt.rgba(1, 1, 1, 0.14)
        }

        Rectangle {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(4, parent.width * root._progress)
          height: 3
          radius: height / 2
          color: Theme.active

          Behavior on width {
            enabled: !Theme.staticMode
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
          }
        }

        Rectangle {
          x: Math.max(0, Math.min(parent.width - width, parent.width * root._progress - width / 2))
          anchors.verticalCenter: parent.verticalCenter
          width: 8
          height: 5
          radius: 2
          color: Qt.rgba(1, 1, 1, 0.70)
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
      id: quietCavaStrip
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 14
      opacity: 0.42

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
      border.color: Qt.rgba(1, 1, 1, 0.08)
    }

    TapHandler {
      enabled: root._dropdownOpen
      onTapped: root._dropdownOpen = false
    }
  }
}
```

- [ ] **Step 2: Run the focused test**

Run:

```bash
bash tests/quickshell-player-card.sh
```

Expected: PASS with `OK: quickshell player card disc console`.

- [ ] **Step 3: Commit the test and player implementation**

Run:

```bash
git add tests/quickshell-player-card.sh config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml
git commit -m "feat: redesign dashboard player card"
```

Expected: commit succeeds with only those two paths staged.

---

### Task 3: Verify Existing Cava And Dashboard Wiring

**Files:**
- Verify: `config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml`
- Verify: `config/quickshell/ryoku/vendor/brain-shell/src/services/CavaService.qml`
- Verify: `tests/brain-shell-spec1.sh`

- [ ] **Step 1: Run the focused player regression**

Run:

```bash
bash tests/quickshell-player-card.sh
```

Expected: PASS with `OK: quickshell player card disc console`.

- [ ] **Step 2: Run the Brain Shell static coverage that includes shared Cava checks**

Run:

```bash
bash tests/brain-shell-spec1.sh
```

Expected: PASS, including these lines:

```text
OK: player bars follow shared MPRIS playback
OK: active Brain_Shell deps are packaged
```

- [ ] **Step 3: Check the player file for removed full-card blur**

Run:

```bash
if rg -n "bgSource|artSource|blurMax|blurEnabled|Cava bars" config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml; then
  echo "FAIL: old full-card player visuals remain" >&2
  exit 1
fi
```

Expected: no output.

- [ ] **Step 4: Check the implementation commit is isolated**

Run:

```bash
git show --stat --oneline --name-only HEAD
```

Expected: the latest implementation commit lists only:

```text
tests/quickshell-player-card.sh
config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml
```

---

### Task 4: Runtime Visual Verification

**Files:**
- Verify runtime copy of `config/quickshell/ryoku/vendor/brain-shell/src/services/home/PlayerCard.qml`

- [ ] **Step 1: Refresh the Quickshell config from the repo**

Run:

```bash
env RYOKU_PATH=/home/omi/prowl/ryoku-arch bin/ryoku-refresh-quickshell
```

Expected: output includes a successful refresh of `/home/omi/.config/quickshell/ryoku`.

- [ ] **Step 2: Restart the Ryoku shell**

Run:

```bash
bin/ryoku-restart-shell
```

Expected: Quickshell restarts without a QML load error.

- [ ] **Step 3: Confirm the shell process is running**

Run:

```bash
pgrep -a quickshell
```

Expected: output includes `quickshell -c ryoku`.

- [ ] **Step 4: Open the dashboard and inspect the player**

Run:

```bash
qs -c ryoku ipc call popups toggleDashboard
```

Expected visual result:

- player uses a dark Ryoku console surface, not blurred full-card album art
- circular album art appears near the top when media exposes art
- fallback disc appears when there is no album art
- Cava orbit ticks animate while any MPRIS source is playing
- title, artist, source chip, elapsed time, and total time do not overlap
- previous/play/next buttons work
- clicking the progress track seeks
- multiple-player source switching still works when more than one allowed MPRIS player exists

---

## Self-Review Checklist

- Spec coverage:
  - Full-card blur removal is covered by Task 1 and Task 3 grep checks.
  - Circular album-art disc is covered by Task 1 and Task 2.
  - Cava orbit and shared `CavaService` behavior are covered by Task 1, Task 2, and Task 3.
  - Existing MPRIS controls, source switching, and seeking are preserved in Task 2 and checked in Task 1.
  - Dashboard footprint stays unchanged because only `PlayerCard.qml` and a test file are modified.
- Placeholder scan: this plan contains no placeholder implementation steps.
- Type consistency: `filteredPlayers`, `selectedPlayerIndex`, `_dropdownOpen`, `_pos`, `_progress`, `_barValue`, `_stripValue`, `_orbitBars`, and `_stripBars` are defined before use in the QML replacement.
