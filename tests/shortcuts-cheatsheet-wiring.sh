#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SHORTCUTS_CONFIG="$ROOT_DIR/shell/modules/settings/CheatsheetConfig.qml"
CHEATSHEET_MENU="$ROOT_DIR/shell/modules/cheatsheet/CheatsheetKeybinds.qml"
NIRI_SCRIPT="$ROOT_DIR/shell/scripts/niri-config.py"
NIRI_PARSER="$ROOT_DIR/shell/scripts/parse_niri_keybinds.py"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$path" || fail "$message"
}

assert_file_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$path"; then
    fail "$message"
  fi
}

assert_file_contains "$SHORTCUTS_CONFIG" 'NiriKeybinds\.configPath' \
  "Shortcuts settings should keep showing the active keybind config path"
assert_file_contains "$SHORTCUTS_CONFIG" 'function openCheatsheet\(\)' \
  "Shortcuts settings should expose one action that opens the Mod+/ cheatsheet"
assert_file_contains "$SHORTCUTS_CONFIG" '"cheatsheet", "open"' \
  "Shortcuts settings should open the same cheatsheet surface used by Mod+/"
assert_file_contains "$SHORTCUTS_CONFIG" 'Translation\.tr\("See all keybinds"\)' \
  "Shortcuts settings should provide a button to view all keybinds"
assert_file_contains "$SHORTCUTS_CONFIG" 'NiriKeybinds\.setBind\(combo, action, addOptionsField\.text\.trim\(\)\)' \
  "Shortcuts settings should keep the Add keybind flow wired to NiriKeybinds"
assert_file_not_contains "$SHORTCUTS_CONFIG" 'model: root\.hasEnrichedData \? NiriKeybinds\.enrichedCategories : \[\]' \
  "Shortcuts settings should not duplicate the full keybind list inline"
assert_file_not_contains "$SHORTCUTS_CONFIG" 'model: root\.categories' \
  "Shortcuts settings should not render the legacy full keybind list inline"
assert_file_not_contains "$SHORTCUTS_CONFIG" 'component KeybindRow:' \
  "Shortcuts settings should leave keybind browsing to the Mod+/ cheatsheet"

assert_file_contains "$CHEATSHEET_MENU" 'Custom Keys' \
  "Mod+/ cheatsheet should have an explicit Custom Keys section"
assert_file_contains "$NIRI_SCRIPT" 'CUSTOM_KEYBINDS_MARKER' \
  "Niri keybind writer should mark user-added custom keybinds"
assert_file_contains "$NIRI_SCRIPT" 'Custom Keys' \
  "Niri keybind reader should categorize user-added binds as Custom Keys"
assert_file_contains "$NIRI_PARSER" 'Custom Keys' \
  "Legacy cheatsheet parser should keep custom keybinds in a Custom Keys section"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/niri/config.d"
cat >"$tmp_dir/niri/config.kdl" <<'KDL'
include "config.d/70-binds.kdl"
KDL
cat >"$tmp_dir/niri/config.d/70-binds.kdl" <<'KDL'
binds {
    Mod+Slash { spawn "ryoku-shell" "cheatsheet" "toggle"; }
}
KDL

XDG_CONFIG_HOME="$tmp_dir" python3 "$NIRI_SCRIPT" set-bind Mod+Alt+K 'spawn "kitty"' >/dev/null

get_binds_json="$(XDG_CONFIG_HOME="$tmp_dir" python3 "$NIRI_SCRIPT" get-binds)"
python3 - "$get_binds_json" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
categories = {category["name"] for category in data["categories"]}
if "Custom Keys" not in categories:
    raise SystemExit("new set-bind entry did not appear under Custom Keys")

custom_indices = next(category["binds"] for category in data["categories"] if category["name"] == "Custom Keys")
custom_binds = [data["binds"][index] for index in custom_indices]
if not any(bind["key_combo"] == "Mod+Alt+K" and bind.get("custom") is True for bind in custom_binds):
    raise SystemExit("custom bind metadata missing for Mod+Alt+K")
PY

parse_json="$(XDG_CONFIG_HOME="$tmp_dir" python3 "$NIRI_PARSER")"
python3 - "$parse_json" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
categories = {category["name"] for category in data["children"]}
if "Custom Keys" not in categories:
    raise SystemExit("legacy parser did not expose Custom Keys")
PY
