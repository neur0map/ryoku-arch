#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
HELPER="$ROOT_DIR/shell/scripts/ryoku-keybinds"
SHELL_LAUNCHER="$ROOT_DIR/shell/scripts/ryoku-shell"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "missing $path"
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_file shell/scripts/ryoku-keybinds
assert_file shell/services/Keybinds.qml
assert_file shell/modules/keybinds/KeybindsWindow.qml
assert_file shell/modules/keybinds/Content.qml

[[ -x $HELPER ]] || fail "keybind helper should be executable"
bash -n "$HELPER" "$SHELL_LAUNCHER" || fail "keybind scripts should be valid bash"

assert_contains config/hypr/hyprland.conf '^source = ~/.config/hypr/ryoku-user-binds\.conf$' \
  "Hyprland config should source user-managed keybinds"
# shellcheck disable=SC2016
assert_contains config/hypr/hyprland.conf '[$]keybinds = sh -lc '"'"'\$HOME/.local/bin/ryoku-shell keybinds'"'" \
  "Hyprland config should route the keybind legend through ryoku-shell"
assert_contains config/hypr/hyprland.conf '^bind = SUPER, slash, exec, [$]keybinds$' \
  "Super+/ should open the keybind legend"
assert_contains config/hypr/hyprland.conf 'windowrule = match:title \^\(Ryoku Keybinds\)\$, float true' \
  "keybind legend should open as a floating window"
assert_contains shell/scripts/ryoku-shell 'ipc_call keybinds toggle' \
  "ryoku-shell should expose a keybinds IPC command"
# shellcheck disable=SC2016
assert_contains shell/setup 'scripts/ryoku-keybinds" "\$bin_dir/ryoku-keybinds' \
  "setup should install the keybind helper"
assert_contains shell/shell.qml 'KeybindsWindow' \
  "shell root should load the keybind legend window"
assert_contains shell/services/Keybinds.qml 'target: "keybinds"' \
  "keybind service should expose IPC"
assert_contains shell/services/Keybinds.qml 'FileView' \
  "keybind service should watch config files for live reload"

command -v jq >/dev/null 2>&1 || fail "jq is required for keybind helper tests"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
test_home="$tmp_dir/user"

mkdir -p "$test_home/.config/hypr" "$tmp_dir/bin"
cat >"$test_home/.config/hypr/hyprland.conf" <<'HYPR'
source = ~/.config/hypr/ryoku-user-binds.conf
$terminal = kitty
bind = SUPER, Return, exec, $terminal
bind = SUPER, slash, exec, $keybinds
bind = SUPER, Q, killactive,
HYPR

cat >"$test_home/.config/hypr/ryoku-user-binds.conf" <<'HYPR'
# Ryoku Keybind: Notes
bind = SUPER SHIFT, N, exec, obsidian
HYPR

cat >"$tmp_dir/bin/hyprctl" <<'SH'
#!/bin/bash
if [[ $1 == "binds" && ${2:-} == "-j" ]]; then
  cat <<'JSON'
[
  {"modmask":64,"submap":"","key":"Return","dispatcher":"exec","arg":"kitty"},
  {"modmask":64,"submap":"","key":"slash","dispatcher":"exec","arg":"$HOME/.local/bin/ryoku-shell keybinds"},
  {"modmask":65,"submap":"","key":"N","dispatcher":"exec","arg":"obsidian"}
]
JSON
elif [[ $1 == "reload" ]]; then
  printf 'reload\n' >>"$RYOKU_TEST_RELOAD_LOG"
else
  exit 1
fi
SH
chmod +x "$tmp_dir/bin/hyprctl"

list_json=$(
  HOME="$test_home" \
  PATH="$tmp_dir/bin:/usr/bin" \
  "$HELPER" list
)

jq -e '.[] | select(.combo == "Super+/") | select(.description == "Keybinds")' <<<"$list_json" >/dev/null || \
  fail "list should normalize Super+/ from live Hyprland binds"
jq -e '.[] | select(.combo == "Super+Shift+N") | select(.arg == "obsidian")' <<<"$list_json" >/dev/null || \
  fail "list should include user keybinds from live Hyprland binds"

add_output=$(
  RYOKU_TEST_RELOAD_LOG="$tmp_dir/reload.log" \
  HOME="$test_home" \
  PATH="$tmp_dir/bin:/usr/bin" \
    "$HELPER" add --mods "SUPER ALT" --key "B" --dispatcher exec --arg "brave" --description "Browser"
)

[[ $add_output == "ok" ]] || fail "add should emit a success marker for the shell service"

grep -Fq '# Ryoku Keybind: Browser' "$test_home/.config/hypr/ryoku-user-binds.conf" || \
  fail "add should annotate user keybinds"
grep -Fq 'bind = SUPER ALT, B, exec, brave' "$test_home/.config/hypr/ryoku-user-binds.conf" || \
  fail "add should append a Hyprland bind"
grep -Fq "\$keybinds = sh -lc '\$HOME/.local/bin/ryoku-shell keybinds'" "$test_home/.config/hypr/hyprland.conf" || \
  fail "ensure should add the keybind legend command to existing configs"
grep -Fq "bind = SUPER, slash, exec, \$keybinds" "$test_home/.config/hypr/hyprland.conf" || \
  fail "ensure should add the Super+/ bind to existing configs"
grep -Fq 'reload' "$tmp_dir/reload.log" || \
  fail "add should reload Hyprland when hyprctl is available"

echo "PASS: rebirth keybind legend reads and edits Hyprland binds"
