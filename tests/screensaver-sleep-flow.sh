#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: screensaver sleep flow"
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

  ! grep -Eq "$pattern" "$file" || fail "$message"
}

assert_order() {
  local file="$1"
  local first_pattern="$2"
  local second_pattern="$3"
  local message="$4"
  local first_line
  local second_line

  first_line="$(grep -nE "$first_pattern" "$file" | head -n1 | cut -d: -f1)"
  second_line="$(grep -nE "$second_pattern" "$file" | head -n1 | cut -d: -f1)"

  [[ -n $first_line ]] || fail "$message: missing first pattern"
  [[ -n $second_line ]] || fail "$message: missing second pattern"
  (( first_line < second_line )) || fail "$message"
}

assert_launcher_prefers_ryoku_terminal_setting() {
  local temp_dir home_dir bin_dir log_file

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  bin_dir="$temp_dir/bin"
  log_file="$temp_dir/screensaver-spawn.log"

  mkdir -p "$home_dir/.config/ryoku-shell" "$bin_dir"

  cat >"$home_dir/.config/ryoku-shell/config.json" <<'JSON'
{
  "apps": {
    "terminal": "kitty"
  }
}
JSON

  cat >"$bin_dir/tte" <<'EOF'
#!/bin/bash
exit 0
EOF

  cat >"$bin_dir/xdg-terminal-exec" <<'EOF'
#!/bin/bash
if [[ ${1:-} == "--print-id" ]]; then
  echo "Alacritty.desktop"
fi
EOF

  cat >"$bin_dir/pgrep" <<'EOF'
#!/bin/bash
exit 1
EOF

  cat >"$bin_dir/kitty" <<EOF
#!/bin/bash
printf 'kitty %s\n' "\$*" >> "$log_file"
EOF

  chmod +x "$bin_dir/tte" "$bin_dir/xdg-terminal-exec" "$bin_dir/pgrep" "$bin_dir/kitty"

  HOME="$home_dir" \
    PATH="$bin_dir:/usr/bin:/bin" \
    RYOKU_PATH="$PWD" \
    RYOKU_STATE_PATH="$temp_dir/state" \
    bash bin/ryoku-launch-screensaver force

  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -f $log_file ]] && break
    sleep 0.1
  done

  if ! grep -q '^kitty ' "$log_file"; then
    rm -rf "$temp_dir"
    fail "screensaver launcher should prefer Ryoku terminal setting over xdg-terminal-exec"
  fi

  rm -rf "$temp_dir"
}

assert_contains bin/ryoku-launch-screensaver 'ryoku-cmd-screensaver' \
  "screensaver launcher should run the TTE screensaver command"
# shellcheck disable=SC2016
assert_contains bin/ryoku-launch-screensaver '\$RYOKU_PATH/bin/ryoku-cmd-screensaver' \
  "screensaver launcher should pass an absolute command path to terminal children"
assert_contains bin/ryoku-launch-screensaver '\$\{1:-\} != "force"' \
  "screensaver launcher should handle no-argument idle launches under set -u"
assert_not_contains bin/ryoku-launch-screensaver 'niri msg|ryoku-cmd-present niri' \
  "screensaver launcher should not call retired Niri commands"
# shellcheck disable=SC2016
assert_contains bin/ryoku-cmd-screensaver 'tte -i "\$RYOKU_CONFIG_PATH/branding/screensaver\.txt"' \
  "screensaver command should render the configured ASCII branding with TTE"
assert_not_contains bin/ryoku-cmd-screensaver 'niri msg' \
  "screensaver command should not inspect retired Niri windows"

assert_contains config/hypr/hypridle.conf 'ryoku-launch-screensaver' \
  "idle config should launch the preserved ASCII screensaver before monitor-off"
assert_contains config/hypr/hypridle.conf 'pkill -f org\.ryoku\.screensaver' \
  "idle resume should close stale screensaver windows"
assert_not_contains config/hypr/hypridle.conf 'on-timeout = .*power-off-monitors' \
  "idle config should not black the display while the screensaver is running"

assert_contains config/hypr/hyprland.conf 'match:class \^\(org\.ryoku\.screensaver\)\$.*fullscreen true' \
  "Hyprland config should open screensaver windows fullscreen"

bash -n bin/ryoku-launch-screensaver bin/ryoku-cmd-screensaver tests/screensaver-sleep-flow.sh

assert_launcher_prefers_ryoku_terminal_setting

pass
