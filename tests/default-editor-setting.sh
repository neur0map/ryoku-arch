#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local file="$1"
  [[ -f $ROOT_DIR/$file ]] || fail "$file should exist"
}

assert_executable() {
  local file="$1"
  assert_file "$file"
  [[ -x $ROOT_DIR/$file ]] || fail "$file should be executable"
}

assert_contains() {
  local file="$1"
  local needle="$2"
  assert_file "$file"
  grep -qF -- "$needle" "$ROOT_DIR/$file" || fail "$file should contain: $needle"
}

assert_contains_abs() {
  local file="$1"
  local needle="$2"
  [[ -f $file ]] || fail "$file should exist"
  grep -qF -- "$needle" "$file" || fail "$file should contain: $needle"
}

assert_executable "bin/ryoku-update-default-editor"
assert_executable "bin/ryoku-refresh-editor-desktop"
assert_contains "shell/services/AppLauncher.qml" 'id: "editor"'
assert_contains "shell/services/AppLauncher.qml" 'label: Translation.tr("Text editor")'
assert_contains "shell/services/AppLauncher.qml" 'defaultCommand: "nvim"'
assert_contains "shell/services/AppLauncher.qml" '{ id: "zed", label: "Zed", command: "zed" }'
assert_contains "shell/services/AppLauncher.qml" 'Quickshell.execDetached(["ryoku-update-default-editor", preset.command])'
assert_contains "shell/modules/common/Config.qml" 'property string editor: "nvim"'
assert_contains "shell/defaults/config.json" '"editor": "nvim"'
assert_contains "shell/settings.qml" "neovim"
assert_contains "shell/modules/settings/SettingsOverlay.qml" "zed"
assert_contains "bin/ryoku-update-default-editor" "dev.zed.Zed.desktop"
assert_contains "bin/ryoku-update-default-editor" "xdg-mime default"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/bin" "$tmp_dir/config/ryoku-shell" "$tmp_dir/data/applications"
cat >"$tmp_dir/config/ryoku-shell/config.json" <<'JSON'
{
  "apps": {
    "browser": "helium"
  }
}
JSON

cat >"$tmp_dir/bin/xdg-mime" <<'XDGMIME'
#!/bin/bash
printf '%s\n' "$*" >>"$TMPDIR/xdg-mime.log"
XDGMIME
cat >"$tmp_dir/bin/update-desktop-database" <<'UPDATEDB'
#!/bin/bash
printf '%s\n' "$*" >>"$TMPDIR/update-desktop-database.log"
UPDATEDB
chmod +x "$tmp_dir/bin/xdg-mime" "$tmp_dir/bin/update-desktop-database"

TMPDIR="$tmp_dir" \
HOME="$tmp_dir/home" \
XDG_CONFIG_HOME="$tmp_dir/config" \
XDG_DATA_HOME="$tmp_dir/data" \
RYOKU_PATH="$ROOT_DIR" \
PATH="$tmp_dir/bin:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-default-editor" zed >/dev/null

jq -e '.apps.editor == "zed"' "$tmp_dir/config/ryoku-shell/config.json" >/dev/null \
  || fail "default editor helper should update shell config"
grep -qxF "export RYOKU_EDITOR=zed" "$tmp_dir/config/uwsm/default" \
  || fail "default editor helper should set RYOKU_EDITOR=zed"
grep -qxF "export EDITOR=zed" "$tmp_dir/config/uwsm/default" \
  || fail "default editor helper should set EDITOR=zed"
grep -qxF "default dev.zed.Zed.desktop text/plain" "$tmp_dir/xdg-mime.log" \
  || fail "Zed preset should become the text/plain MIME default"

rm -f "$tmp_dir/xdg-mime.log"
TMPDIR="$tmp_dir" \
HOME="$tmp_dir/home" \
XDG_CONFIG_HOME="$tmp_dir/config" \
XDG_DATA_HOME="$tmp_dir/data" \
RYOKU_PATH="$ROOT_DIR" \
PATH="$tmp_dir/bin:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-update-default-editor" nvim >/dev/null

assert_contains_abs "$tmp_dir/data/applications/ryoku-editor.desktop" "Exec=$ROOT_DIR/bin/ryoku-launch-editor %F"
grep -qxF "default ryoku-editor.desktop text/plain" "$tmp_dir/xdg-mime.log" \
  || fail "Neovim preset should use the Ryoku terminal-aware desktop entry"

cat >"$tmp_dir/bin/setsid" <<'SETSID'
#!/bin/bash
printf '%s\n' "$@" >"$TMPDIR/editor-launch.log"
SETSID
cat >"$tmp_dir/bin/zed" <<'ZED'
#!/bin/bash
exit 0
ZED
cat >"$tmp_dir/bin/vi" <<'VI'
#!/bin/bash
exit 0
VI
chmod +x "$tmp_dir/bin/setsid" "$tmp_dir/bin/zed" "$tmp_dir/bin/vi"
jq '.apps.editor = "zed"' "$tmp_dir/config/ryoku-shell/config.json" >"$tmp_dir/config/ryoku-shell/config.tmp"
mv "$tmp_dir/config/ryoku-shell/config.tmp" "$tmp_dir/config/ryoku-shell/config.json"
printf 'sample\n' >"$tmp_dir/sample.txt"

TMPDIR="$tmp_dir" \
HOME="$tmp_dir/home" \
XDG_CONFIG_HOME="$tmp_dir/config" \
RYOKU_PATH="$ROOT_DIR" \
EDITOR=vi \
PATH="$tmp_dir/bin:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-launch-editor" "$tmp_dir/sample.txt"

grep -qxF "zed" "$tmp_dir/editor-launch.log" \
  || fail "Ryoku editor launcher should use apps.editor from shell config"
! grep -qxF "vi" "$tmp_dir/editor-launch.log" \
  || fail "Ryoku editor launcher should ignore inherited EDITOR when apps.editor is set"
grep -qxF "$tmp_dir/sample.txt" "$tmp_dir/editor-launch.log" \
  || fail "Ryoku editor launcher should pass the selected file to the configured editor"
