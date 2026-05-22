#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
NIRI_CONFIG="$ROOT_DIR/shell/modules/settings/NiriConfig.qml"
DISPLAY_CONFIGURATOR="$ROOT_DIR/shell/modules/settings/NiriDisplayConfigurator.qml"
NIRI_SCRIPT="$ROOT_DIR/shell/scripts/niri-config.py"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$file"; then
    fail "$message"
  fi
}

[[ -f $DISPLAY_CONFIGURATOR ]] || fail "NiriDisplayConfigurator.qml should exist"

assert_contains "$NIRI_CONFIG" 'property var displayPendingChanges: \(\{\}\)' \
  "NiriConfig should keep staged display changes separate from live output data"
assert_contains "$NIRI_CONFIG" 'function applyDisplayDraft\(\)' \
  "NiriConfig should expose a staged apply path for the visual monitor UI"
assert_contains "$NIRI_CONFIG" '"apply-outputs"' \
  "NiriConfig should preview multiple display changes through niri-config.py"
assert_contains "$NIRI_CONFIG" '"persist-outputs"' \
  "NiriConfig should persist multiple display changes through niri-config.py"
assert_contains "$NIRI_CONFIG" 'NiriDisplayConfigurator[[:space:]]*\{' \
  "The Displays section should use the visual monitor configurator"
assert_contains "$NIRI_CONFIG" 'pendingPreviewKind === "display-draft"' \
  "The display confirmation flow should support visual layout previews"

assert_contains "$DISPLAY_CONFIGURATOR" 'component MonitorRect:' \
  "The display configurator should render draggable monitor rectangles"
assert_contains "$DISPLAY_CONFIGURATOR" 'import qs\.services' \
  "The display configurator should import services before using Translation"
assert_contains "$DISPLAY_CONFIGURATOR" 'component OutputCard:' \
  "The display configurator should render per-output setting cards"
assert_contains "$DISPLAY_CONFIGURATOR" 'stageDisplayChange\(.*"position"' \
  "Dragging monitors should stage position changes"
assert_contains "$DISPLAY_CONFIGURATOR" 'Apply changes' \
  "The display configurator should expose an apply button for pending changes"
assert_contains "$DISPLAY_CONFIGURATOR" 'visible: root\.pageRoot\.displayPendingChangeCount > 0' \
  "Inactive display action buttons should not render blank disabled pills"
assert_contains "$DISPLAY_CONFIGURATOR" 'SettingsMaterialPreset\.groupColor' \
  "Display monitor/card surfaces should inherit the active settings style"
assert_contains "$DISPLAY_CONFIGURATOR" 'SettingsMaterialPreset\.titleExpandedColor' \
  "Display primary labels should use settings text tokens"
assert_contains "$DISPLAY_CONFIGURATOR" 'Resolution' \
  "The display configurator should preserve resolution controls"
assert_contains "$DISPLAY_CONFIGURATOR" 'Refresh rate' \
  "The display configurator should preserve refresh-rate controls"
assert_contains "$DISPLAY_CONFIGURATOR" 'Scale' \
  "The display configurator should preserve scale controls"
assert_contains "$DISPLAY_CONFIGURATOR" 'Rotation' \
  "The display configurator should preserve transform controls"
assert_contains "$DISPLAY_CONFIGURATOR" 'VRR' \
  "The display configurator should preserve VRR controls"
assert_contains "$DISPLAY_CONFIGURATOR" 'component DisplayToggle:' \
  "The display configurator should use a display-local toggle that cannot collapse labels"
assert_contains "$DISPLAY_CONFIGURATOR" 'Layout\.minimumWidth: 140' \
  "Display toggles should reserve enough width for visible labels"
assert_contains "$DISPLAY_CONFIGURATOR" 'text: displayToggle\.text' \
  "Display toggles should render their text label"
assert_contains "$DISPLAY_CONFIGURATOR" 'ColorUtils\.ensureReadable\(.*SettingsMaterialPreset\.groupColor' \
  "Display toggle labels should stay readable on the display card surface"

assert_not_contains "$DISPLAY_CONFIGURATOR" 'DMSService|WlrOutputService|Dank' \
  "Ryoku should not depend on the DMS runtime services for this port"
assert_not_contains "$DISPLAY_CONFIGURATOR" 'colSecondaryContainer|colPrimaryContainer' \
  "Display selection should use borders/accent, not purple material container fills"

assert_contains "$NIRI_SCRIPT" '"apply-outputs": lambda: cmd_apply_outputs\(args\)' \
  "niri-config.py should register the batch apply command"
assert_contains "$NIRI_SCRIPT" '"persist-outputs": lambda: cmd_persist_outputs\(args\)' \
  "niri-config.py should register the batch persist command"

printf 'PASS: tests/niri-display-configurator-ui.sh\n'
