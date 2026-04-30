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
active_has "$player" 'id: panelBody' \
  || fail "PlayerCard should render the offset console panel"
active_has "$player" 'objectName: "playerOffsetPanel"' \
  || fail "Offset console panel should be addressable for visual regression checks"
active_has "$player" 'id: mediaStack' \
  || fail "PlayerCard should keep metadata, wavebar, and controls grouped"
active_has "$player" 'objectName: "playerSideConsole"' \
  || fail "Metadata/control stack should use the side-console layout"
active_has "$player" 'anchors.left: panelBody.left' \
  || fail "Side console should be anchored to the offset panel"
active_has "$player" 'anchors.leftMargin: root._contentLeftInset' \
  || fail "Side console should reserve room for the overlapping disc"
active_has "$player" 'component TransportGlyph' \
  || fail "Playback controls should use custom Ryoku transport glyphs"
active_has "$player" 'component ChevronMark' \
  || fail "Previous/next controls should use drawn chevron geometry"
active_has "$player" 'id: playbackControls' \
  || fail "PlayerCard should render explicit playback controls"
active_has "$player" 'objectName: "playbackDeck"' \
  || fail "Playback controls should use the transport deck layout"
active_has "$player" 'width: isPlay ? 46 : 38' \
  || fail "Playback controls should use large round command nodes"
active_has "$player" 'radius: width / 2' \
  || fail "Playback controls should render as circular command nodes"
active_has "$player" 'root.player.canTogglePlaying' \
  || fail "Play button should preserve canTogglePlaying guard"
active_has "$player" 'root.player.canGoPrevious' \
  || fail "Previous button should preserve canGoPrevious guard"
active_has "$player" 'root.player.canGoNext' \
  || fail "Next button should preserve canGoNext guard"
active_has "$player" 'id: progressTrack' \
  || fail "PlayerCard should render a named progress track"
active_has "$player" 'id: seekWaveBar' \
  || fail "Progress track should render as a wave seekbar"
active_has "$player" 'objectName: "playerWaveSeek"' \
  || fail "Wave seekbar should be addressable as part of the side console"
active_has "$player" 'readonly property int _seekBars' \
  || fail "Wave seekbar should define a stable bar count"
active_has "$player" 'root._seekValue(index)' \
  || fail "Wave seekbar should read shared Cava values"
active_has "$player" 'root.player.position = f * root.length' \
  || fail "Progress track should preserve click-to-seek"
active_has "$player" 'font.family: "JetBrains Mono"' \
  || fail "PlayerCard should use JetBrains Mono for console/time details"
active_has "$player" 'NO SIGNAL' \
  || fail "PlayerCard should provide a designed no-player fallback"
active_has "$player" 'readonly property real _surfaceAlpha' \
  || fail "PlayerCard should expose a transparent surface opacity"

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
if active_has "$player" '⏮'; then
  fail "PlayerCard should not use emoji-style previous button glyphs"
fi
if active_has "$player" '⏭'; then
  fail "PlayerCard should not use emoji-style next button glyphs"
fi
if active_has "$player" '⏸'; then
  fail "PlayerCard should not use emoji-style pause button glyphs"
fi
if active_has "$player" '⏵'; then
  fail "PlayerCard should not use emoji-style play button glyphs"
fi
if active_has "$player" 'property bool left'; then
  fail "PlayerCard should not define a Chevron property that collides with Item.left"
fi

if command -v qmllint >/dev/null; then
  lint_log="/tmp/ryoku-player-card-qmllint.$$"
  if ! qmllint -I config/quickshell/ryoku/vendor/brain-shell/src "$player" >"$lint_log" 2>&1; then
    if [[ -s $lint_log ]]; then
      cat "$lint_log" >&2
      rm -f "$lint_log"
      fail "PlayerCard qmllint failed"
    fi
    echo "SKIP: qmllint returned no diagnostics for MPRIS PlayerCard"
  fi
  rm -f "$lint_log"
fi

pass "quickshell player card disc console"
