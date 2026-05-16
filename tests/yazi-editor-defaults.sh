#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_tmp=""

cleanup() {
  [[ -n ${test_tmp:-} ]] && rm -rf "$test_tmp"
  return 0
}

trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_executable() {
  local path="$1"

  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1" pattern="$2" message="$3"

  rg -n -- "$pattern" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

assert_not_contains() {
  local path="$1" pattern="$2" message="$3"

  if rg -n -- "$pattern" "$ROOT_DIR/$path" >/dev/null; then
    fail "$message"
  fi
}

assert_yazi_defaults() {
  assert_file "config/yazi/yazi.toml"
  assert_executable "bin/ryoku-refresh-yazi-editor"
  assert_contains "config/yazi/yazi.toml" "ryoku-launch-editor --in-place %s" \
    "Yazi should route text editing through Ryoku's editor launcher"
  assert_contains "config/yazi/yazi.toml" "block = true" \
    "Yazi editor opener should block so terminal editors can take over the screen"
  assert_contains "config/yazi/yazi.toml" 'mime = .text/\*.' \
    "Yazi should use the editor opener for text files"
  assert_contains "bin/ryoku-launch-editor" "--in-place" \
    "Ryoku editor launcher should support in-place terminal callers"
  assert_contains "bin/ryoku-launch-editor" 'if \(\( in_place == 1 \)\)' \
    "Ryoku editor launcher should run terminal editors directly in-place"
}

assert_session_defaults() {
  assert_contains "shell/dots/.config/fish/config.fish" 'set -gx RYOKU_EDITOR nvim' \
    "Fish defaults should export Ryoku's default editor"
  assert_contains "shell/dots/.config/fish/config.fish" 'set -gx EDITOR \$RYOKU_EDITOR' \
    "Fish defaults should export EDITOR for Yazi"
  assert_contains "shell/sdata/lib/package-installers.sh" 'set -gx RYOKU_EDITOR nvim' \
    "Fallback Fish installer should export Ryoku's default editor"
  assert_contains "shell/sdata/lib/package-installers.sh" 'setup-gtk-config "Bibata-Modern-Classic" "Papirus"' \
    "Fallback installer should keep Papirus as the GTK icon default"
  assert_contains "migrations/1778723612.sh" 'set_env_line "\$HOME/.config/uwsm/default" RYOKU_EDITOR nvim' \
    "Neovim install migration should set RYOKU_EDITOR"
  assert_contains "migrations/1778947544.sh" 'set_env_line "\$HOME/.config/uwsm/default" RYOKU_EDITOR nvim' \
    "Neovim repair migration should set RYOKU_EDITOR"
  assert_contains "migrations/1778949962.sh" "ryoku-refresh-yazi-editor" \
    "Yazi migration should refresh the editor opener"
}

assert_refresh_helper() {
  local missing_home custom_home preserved_home

  cleanup
  test_tmp="$(mktemp -d)"

  missing_home="$test_tmp/missing"
  HOME="$missing_home" \
  XDG_CONFIG_HOME="$missing_home/.config" \
  RYOKU_PATH="$ROOT_DIR" \
    "$ROOT_DIR/bin/ryoku-refresh-yazi-editor"
  grep -q 'ryoku-launch-editor --in-place %s' "$missing_home/.config/yazi/yazi.toml" || \
    fail "Yazi refresh helper should create missing yazi.toml with Ryoku editor opener"

  custom_home="$test_tmp/custom"
  mkdir -p "$custom_home/.config/yazi"
  printf '[mgr]\nshow_hidden = true\n' >"$custom_home/.config/yazi/yazi.toml"
  HOME="$custom_home" \
  XDG_CONFIG_HOME="$custom_home/.config" \
  RYOKU_PATH="$ROOT_DIR" \
    "$ROOT_DIR/bin/ryoku-refresh-yazi-editor"
  grep -q 'show_hidden = true' "$custom_home/.config/yazi/yazi.toml" || \
    fail "Yazi refresh helper should preserve existing unrelated config"
  grep -q 'ryoku-launch-editor --in-place %s' "$custom_home/.config/yazi/yazi.toml" || \
    fail "Yazi refresh helper should extend simple existing config"

  preserved_home="$test_tmp/preserved"
  mkdir -p "$preserved_home/.config/yazi"
  cat >"$preserved_home/.config/yazi/yazi.toml" <<'TOML'
[opener]
edit = [
  { run = 'nvim %s', block = true },
]
TOML
  HOME="$preserved_home" \
  XDG_CONFIG_HOME="$preserved_home/.config" \
  RYOKU_PATH="$ROOT_DIR" \
    "$ROOT_DIR/bin/ryoku-refresh-yazi-editor" >/dev/null
  grep -q "run = 'nvim %s'" "$preserved_home/.config/yazi/yazi.toml" || \
    fail "Yazi refresh helper should preserve custom opener config"
  if grep -q 'ryoku-launch-editor --in-place %s' "$preserved_home/.config/yazi/yazi.toml"; then
    fail "Yazi refresh helper should not override custom opener config"
  fi
}

assert_in_place_launcher() {
  local tmp

  cleanup
  tmp="$(mktemp -d)"
  test_tmp="$tmp"

  mkdir -p "$tmp/bin" "$tmp/user/.config/ryoku-shell"
  cat >"$tmp/user/.config/ryoku-shell/config.json" <<'JSON'
{
  "apps": {
    "editor": "nvim"
  }
}
JSON
  cat >"$tmp/bin/nvim" <<'NVIM'
#!/bin/bash
printf '%s\n' "$@" >"$RYOKU_TEST_EDITOR_LOG"
NVIM
  cat >"$tmp/bin/vi" <<'VI'
#!/bin/bash
printf 'vi should not run\n' >"$RYOKU_TEST_EDITOR_LOG"
VI
  cat >"$tmp/bin/xdg-terminal-exec" <<'TERM'
#!/bin/bash
printf 'terminal should not run\n' >"$RYOKU_TEST_EDITOR_LOG"
TERM
  chmod +x "$tmp/bin/nvim" "$tmp/bin/vi" "$tmp/bin/xdg-terminal-exec"

  HOME="$tmp/user" \
  XDG_CONFIG_HOME="$tmp/user/.config" \
  RYOKU_TEST_EDITOR_LOG="$tmp/editor.log" \
  RYOKU_PATH="$ROOT_DIR" \
  EDITOR=vi \
  PATH="$tmp/bin:$ROOT_DIR/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-launch-editor" --in-place "$tmp/sample.txt"

  grep -qxF "$tmp/sample.txt" "$tmp/editor.log" || \
    fail "in-place editor launch should run configured nvim directly with the selected file"
  assert_not_contains_abs "$tmp/editor.log" "terminal should not run" \
    "in-place editor launch should not spawn a new terminal"
}

assert_not_contains_abs() {
  local path="$1" pattern="$2" message="$3"

  if rg -n -- "$pattern" "$path" >/dev/null; then
    fail "$message"
  fi
}

assert_yazi_defaults
assert_session_defaults
assert_refresh_helper
assert_in_place_launcher

echo "PASS: Yazi editor defaults"
