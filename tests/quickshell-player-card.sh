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
dashboard="config/quickshell/ryoku/vendor/brain-shell/src/popups/Dashboard.qml"
popups="config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml"
audio_helper="bin/ryoku-audio-effects"

[[ -f $player ]] || fail "$player missing"
[[ -f $dashboard ]] || fail "$dashboard missing"
[[ -f $popups ]] || fail "$popups missing"
[[ -x $audio_helper ]] || fail "$audio_helper should be executable"

active_has "$player" 'StatCard {' \
  || fail "PlayerCard should use the shared StatCard surface"
active_has "$player" 'padding: 0' \
  || fail "PlayerCard should opt into full-surface custom layout inside StatCard"
active_has "$player" 'backgroundAlpha: 0' \
  || fail "PlayerCard should disable the shared StatCard fill so only the audio card is see-through"
active_has "$player" 'borderAlpha: 0' \
  || fail "PlayerCard should disable the shared StatCard border and use its own transparent border"
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
active_has "$player" 'readonly property int _orbitBars: 44' \
  || fail "PlayerCard Cava orbit should have enough samples to read as a synthesizer"
active_has "$player" 'root._barValue(index)' \
  || fail "Cava orbit ticks should read shared Cava values"
active_has "$player" 'height: 5 + amp * 26' \
  || fail "Cava orbit ticks should visibly react to audio amplitude"
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
active_has "$player" 'id: titleLabel' \
  || fail "PlayerCard should put the track title across the top of the card"
active_has "$player" 'anchors.rightMargin: sourcePicker.visible ? 122 : 18' \
  || fail "Top title should reserve room for the source picker only when needed"
active_has "$player" 'anchors.left: discStage.right' \
  || fail "Side console should sit to the right of the album disc"
active_has "$player" 'anchors.bottom: effectsToggle.top' \
  || fail "Side console should reserve space above the compact FX entry button"
active_has "$player" 'anchors.leftMargin: 42' \
  || fail "Side console should clear the Cava orbit around the album disc"
active_has "$player" 'id: albumLabel' \
  || fail "Side console should expose album/source metadata below the artist"
active_has "$player" 'root.album' \
  || fail "PlayerCard should read album metadata when MPRIS provides it"
active_has "$player" 'property bool _effectsOpen: false' \
  || fail "PlayerCard equalizer should start closed when the dashboard opens"
active_has "$player" 'root._effectsOpen = false' \
  || fail "PlayerCard should collapse the equalizer when hidden"
active_has "$player" 'id: audioEffectStateProc' \
  || fail "PlayerCard should load persisted audio effect state"
active_has "$player" 'root._loadEqState()' \
  || fail "PlayerCard should refresh persisted EQ state when shown"
active_has "$player" 'root._applyEqState(JSON.parse(text))' \
  || fail "PlayerCard should parse helper EQ state JSON"
active_has "$player" 'root._eqBands = next' \
  || fail "PlayerCard should sync sliders from persisted EQ bands"
active_has "$player" 'function _syncTimeline(trackChanged)' \
  || fail "PlayerCard should normalize MPRIS progress into an internal timeline"
active_has "$player" 'if ((trackChanged || root.isPlaying) && p >= len - 0.25)' \
  || fail "PlayerCard should recover when a playing MPRIS source reports stale end-of-track progress"
active_has "$player" 'onTitleChanged: root._syncTimeline(true)' \
  || fail "PlayerCard should reset stale progress when the track changes"
active_has "$player" 'onPositionChanged: root._syncTimeline(false)' \
  || fail "PlayerCard should keep progress synced with MPRIS updates"
active_has "$player" 'component TransportGlyph' \
  || fail "Playback controls should use custom Ryoku transport glyphs"
active_has "$player" 'component EqualizerGlyph' \
  || fail "FX entry should use a recognizable equalizer glyph instead of dot indicators"
active_has "$player" 'id: playbackControls' \
  || fail "PlayerCard should render explicit playback controls"
active_has "$player" 'objectName: "playbackDeck"' \
  || fail "Playback controls should use the transport deck layout"
active_has "$player" 'objectName: "playerBottomControls"' \
  || fail "Playback controls should be pinned in a named bottom deck"
active_has "$player" 'anchors.left: discStage.right' \
  || fail "Playback controls should stay in the right-side column and clear the disc orbit"
active_has "$player" 'anchors.bottom: panelBody.bottom' \
  || fail "Playback controls should sit at the bottom of the audio card"
active_has "$player" 'width: isPlay ? 34 : 24' \
  || fail "Playback controls should use compact command keys that fit in the side console"
if ! awk '
  /id: controlsBlock/ { in_block = 1 }
  in_block && /anchors\.leftMargin: 42/ { left_margin = 1 }
  in_block && /anchors\.rightMargin: 18/ { right_margin = 1 }
  in_block && /id: quietCavaStrip/ { exit }
  END { exit left_margin && right_margin ? 0 : 1 }
' "$player"; then
  fail "Playback controls should align to the same side column as metadata and EQ"
fi
if ! awk '
  /id: playbackControls/ { in_block = 1 }
  in_block && /spacing: 5/ { spacing = 1 }
  in_block && /height: 22/ { height = 1 }
  in_block && /radius: 8/ { radius = 1 }
  in_block && /MouseArea/ { exit }
  END { exit spacing && height && radius ? 0 : 1 }
' "$player"; then
  fail "Playback controls should use slim tightly-spaced rounded buttons"
fi
active_has "$player" 'opacity: actionEnabled ? 1 : 0.74' \
  || fail "Unavailable playback controls should remain legible"
active_has "$player" 'ShapePath {' \
  || fail "Transport glyphs should use clean vector shapes"
active_has "$player" 'root.player.canTogglePlaying' \
  || fail "Play button should preserve canTogglePlaying guard"
active_has "$player" 'root.player.canGoPrevious' \
  || fail "Previous button should preserve canGoPrevious guard"
active_has "$player" 'root.player.canGoNext' \
  || fail "Next button should preserve canGoNext guard"
active_has "$player" 'id: progressTrack' \
  || fail "PlayerCard should render a named progress track"
active_has "$player" 'id: seekWaveBar' \
  || fail "Progress track should render a named wave seekbar"
active_has "$player" 'objectName: "playerWaveSeek"' \
  || fail "Wave seekbar should be addressable as part of the side console"
active_has "$player" 'WaveBar {' \
  || fail "PlayerCard seekbar should reuse the TelemetryRail WaveBar component"
active_has "$player" 'value: root._progress' \
  || fail "Wave seekbar should bind to MPRIS playback progress"
active_has "$player" 'valueDuration: 180' \
  || fail "Wave seekbar should update quickly enough to show active song progress"
active_has "$player" 'root.player.position = f * root.length' \
  || fail "Progress track should preserve click-to-seek"
active_has "$player" 'font.family: "JetBrains Mono"' \
  || fail "PlayerCard should use JetBrains Mono for console/time details"
active_has "$player" 'NO SIGNAL' \
  || fail "PlayerCard should provide a designed no-player fallback"
active_has "$player" 'readonly property real _surfaceAlpha' \
  || fail "PlayerCard should expose a transparent surface opacity"
active_has "$player" 'readonly property real _panelAlpha' \
  || fail "PlayerCard should expose a separate transparent panel opacity"
active_has "$player" 'root._panelAlpha' \
  || fail "PlayerCard panel background should use its opacity without fading UI components"
active_has "$player" 'readonly property real _panelAlpha: 0.075' \
  || fail "PlayerCard inner panel should stay low-opacity"
active_has "$player" 'component EqualizerBand' \
  || fail "PlayerCard should expose proper equalizer band controls"
active_has "$player" 'objectName: "audioEffectDeck"' \
  || fail "PlayerCard should expose a compact FX entry button"
active_has "$player" 'objectName: "playerEqualizerScreen"' \
  || fail "PlayerCard should render equalizer as a second in-card screen"
active_has "$player" 'anchors.fill: panelBody' \
  || fail "Equalizer screen should stay inside the audio card panel"
active_has "$player" 'id: effectsToggle' \
  || fail "Audio effects should expose a dedicated FX expand button"
active_has "$player" 'EqualizerGlyph {' \
  || fail "Audio effects button should render a clear equalizer icon"
active_has "$player" 'onClicked: root._toggleEffects()' \
  || fail "FX button should switch between player and equalizer screens"
active_has "$player" 'visible: !root._effectsOpen' \
  || fail "Player UI should disappear when the equalizer screen is open"
active_has "$player" 'visible: root._effectsOpen' \
  || fail "Equalizer screen should appear only after clicking FX"
active_has "$player" 'model: root._eqBandModel' \
  || fail "Expanded equalizer should render the full 10-band model"
active_has "$player" 'id: eqLightningCanvas' \
  || fail "Expanded equalizer should include the lightning animation canvas"
active_has "$player" 'id: eqLightningAnim' \
  || fail "Expanded equalizer should animate lightning on equalizer changes"
active_has "$player" 'root._setEqBand(modelData.idx, value)' \
  || fail "Equalizer bands should be wired to the helper"
active_has "$player" 'ryoku-audio-effects' \
  || fail "PlayerCard effect bars should call the Ryoku audio effects helper"
active_has "$player" '"eq-set",' \
  || fail "Equalizer bands should call the helper per band"
active_has "$audio_helper" 'EasyEffectsServer' \
  || fail "Audio helper should target the EasyEffects local server socket"
active_has "$audio_helper" 'plugins_order' \
  || fail "Audio helper should generate an EasyEffects output preset"
active_has "$audio_helper" 'equalizer' \
  || fail "Audio helper should wire the expanded controls to EasyEffects equalizer"
active_has "$audio_helper" 'eq-set)' \
  || fail "Audio helper should expose per-band equalizer control"
grep -qx 'easyeffects' install/ryoku-base.packages \
  || fail "install/ryoku-base.packages should include easyeffects for dashboard sound controls"

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
if active_has "$player" 'component ChevronMark'; then
  fail "PlayerCard should not keep the old crowded chevron glyph component"
fi
if active_has "$player" 'root._effectsOpen = true'; then
  fail "PlayerCard should not force the equalizer open when the dashboard appears"
fi
if active_has "$player" 'parent.isPlay ? 0.038'; then
  fail "Playback controls should not keep the old nested stripe treatment"
fi
if active_has "$player" 'component EffectSlider'; then
  fail "PlayerCard should not keep the cramped mini FX sliders"
fi
if active_has "$player" 'height: 4 + Math.abs(bandValue)'; then
  fail "FX entry should not render the equalizer as tiny dot bars"
fi
if active_has "$player" 'Popups.playerEqualizerOpen'; then
  fail "PlayerCard equalizer should not resize the dashboard"
fi
if active_has "$player" 'anchors.bottom: effectDeck.top'; then
  fail "PlayerCard should not anchor player UI to the removed effectDeck"
fi
if ! awk '
  /id: controlsBlock/ { in_block = 1 }
  in_block && /visible: !root\._effectsOpen/ { found = 1 }
  in_block && /id: quietCavaStrip/ { exit }
  END { exit found ? 0 : 1 }
' "$player"; then
  fail "Playback controls should disappear on the in-card equalizer screen"
fi
if awk '
  /id: controlsBlock/ { in_block = 1 }
  in_block && /anchors\.left: panelBody\.left/ { found = 1 }
  in_block && /id: quietCavaStrip/ { exit }
  END { exit found ? 0 : 1 }
' "$player"; then
  fail "Playback controls should not span the full card under the album disc"
fi
if active_has "$dashboard" 'equalizerExtraHeight'; then
  fail "Dashboard should not grow for the audio-card equalizer screen"
fi
if active_has "$popups" 'playerEqualizerOpen'; then
  fail "Popups should not track player equalizer expansion globally"
fi
if active_has "$player" 'border.color: Qt.rgba(1, 1, 1, 0.035)'; then
  fail "PlayerCard should not keep the duplicate full-card border box"
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
