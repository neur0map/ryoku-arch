#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

ipc="bin/ryoku-ipc"

[[ -f $ipc ]] || fail "bin/ryoku-ipc missing"
[[ -x $ipc ]] || fail "bin/ryoku-ipc should be executable"
bash -n "$ipc" || fail "bin/ryoku-ipc should be valid bash"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/config/current/theme/backgrounds" "$tmpdir/config/backgrounds/test"
mkdir -p "$tmpdir/ryoku/bin" "$tmpdir/path" "$tmpdir/state"
printf '%s\n' "test" > "$tmpdir/config/current/theme.name"

cat >"$tmpdir/path/inir" <<'EOF'
#!/bin/bash
mkdir -p "$RYOKU_STATE_PATH"
printf '%s\n' "$@" >"$RYOKU_STATE_PATH/inir.args"
exit 0
EOF
chmod +x "$tmpdir/path/inir"

for helper in ryoku-wallpaper-list ryoku-wallpaper-cache ryoku-theme-list ryoku-font-list ryoku-cursor-list; do
  cat >"$tmpdir/ryoku/bin/$helper" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$tmpdir/ryoku/bin/$helper"
done

for helper in ryoku-theme-set ryoku-wallpaper-apply ryoku-font-set ryoku-font-install ryoku-cursor-set ryoku-cursor-install ryoku-wallhaven-search; do
  cat >"$tmpdir/ryoku/bin/$helper" <<'EOF'
#!/bin/bash
mkdir -p "$RYOKU_STATE_PATH"
printf '%s\n' "$@" >"$RYOKU_STATE_PATH/${0##*/}.args"
EOF
  chmod +x "$tmpdir/ryoku/bin/$helper"
done

assert_has_route() {
  local route="$1"

  "$ipc" --help | grep -Fq "ryoku-ipc $route" \
    || fail "help should document $route"
}

assert_inir_call() {
  local description="$1"
  local expected="$2"
  shift 2
  local actual

  rm -f "$tmpdir/state/inir.args"
  RYOKU_PATH="$PWD" \
  RYOKU_CONFIG_PATH="$tmpdir/config" \
  RYOKU_STATE_PATH="$tmpdir/state" \
  PATH="$tmpdir/path:$PATH" \
    "$ipc" "$@" >/dev/null \
    || fail "$description should be accepted by the parser"

  [[ -f $tmpdir/state/inir.args ]] \
    || fail "$description should invoke inir"
  mapfile -t inir_args < "$tmpdir/state/inir.args"
  actual="${inir_args[*]}"
  [[ $actual == $expected ]] \
    || fail "$description should call: $expected"
}

assert_helper_call() {
  local description="$1"
  local helper="$2"
  local expected="$3"
  shift 3
  local args_file="$tmpdir/state/$helper.args"
  local actual

  rm -f "$args_file"
  RYOKU_PATH="$tmpdir/ryoku" \
  RYOKU_CONFIG_PATH="$tmpdir/config" \
  RYOKU_STATE_PATH="$tmpdir/state" \
  PATH="$tmpdir/path:$PATH" \
    "$ipc" "$@" >/dev/null \
    || fail "$description should be accepted by the parser"

  [[ -f $args_file ]] || fail "$description should invoke $helper"
  mapfile -t helper_args < "$args_file"
  actual="${helper_args[*]}"
  [[ $actual == $expected ]] \
    || fail "$description should call $helper with: $expected"
}

assert_has_route "overview toggle"
assert_has_route "clipboard toggle"
assert_has_route "settings open"
assert_has_route "settings toggle"
assert_has_route "lock activate"
assert_has_route "session toggle"
assert_has_route "launcher toggle"
assert_has_route "region screenshot"
assert_has_route "region ocr"
assert_has_route "region record"
assert_has_route "region record-with-sound"
assert_has_route "theme list --jsonl"
assert_has_route "theme apply THEME"
assert_has_route "font list --jsonl"
assert_has_route "cursor list --jsonl"
assert_has_route "wallpaper settings get --json"
assert_has_route "wallpaper list --jsonl"
assert_has_route "wallpaper cache rebuild"
assert_has_route "wallpaper apply --type image PATH"
assert_has_route "wallpaper wallhaven search"

assert_inir_call "overview toggle" "overview toggle" overview toggle
assert_inir_call "clipboard toggle" "clipboard toggle" clipboard toggle
assert_inir_call "settings open" "settings" settings open
assert_inir_call "settings toggle" "settings toggle" settings toggle
assert_inir_call "lock activate" "lock activate" lock activate
assert_inir_call "session toggle" "session toggle" session toggle
assert_inir_call "launcher toggle" "overview toggle" launcher toggle
assert_inir_call "region screenshot" "region screenshot" region screenshot
assert_inir_call "region ocr" "region ocr" region ocr
assert_inir_call "region record" "region record" region record
assert_inir_call "region record with sound" "region recordWithSound" region record-with-sound

assert_helper_call "theme apply" "ryoku-theme-set" "everforest" theme apply everforest
assert_helper_call "font apply" "ryoku-font-set" "JetBrains Mono" font apply "JetBrains Mono"
assert_helper_call "cursor apply" "ryoku-cursor-set" "Bibata 24" cursor apply Bibata 24
assert_helper_call "wallpaper apply" "ryoku-wallpaper-apply" "--type image /tmp/wall.png" wallpaper apply --type image /tmp/wall.png
assert_helper_call "wallhaven search" "ryoku-wallhaven-search" "search --query forest --page 1 --json" wallpaper wallhaven search --query forest --page 1 --json

settings_json="$(
  RYOKU_PATH="$PWD" \
  RYOKU_CONFIG_PATH="$tmpdir/config" \
  RYOKU_STATE_PATH="$tmpdir/state" \
  PATH="$tmpdir/path:$PATH" \
    "$ipc" wallpaper settings get --json
)" || fail "wallpaper settings should print JSON"

jq -e '.theme_name == "test"' <<<"$settings_json" >/dev/null \
  || fail "wallpaper settings should include current theme name"

if grep -Eq 'qs -c ryoku|popups toggle|settings-menu|toolbox|hyprctl' "$ipc"; then
  fail "ryoku-ipc should not contain old Ryoku Quickshell or Hyprland IPC wiring"
fi

pass "ryoku-ipc Niri/iNiR contract"
