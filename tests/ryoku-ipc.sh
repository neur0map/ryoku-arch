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
apply_bin="bin/ryoku-wallpaper-apply"

[[ -f $ipc ]] || fail "bin/ryoku-ipc missing"
[[ -x $ipc ]] || fail "bin/ryoku-ipc should be executable"
[[ -f $apply_bin ]] || fail "bin/ryoku-wallpaper-apply missing"
[[ -x $apply_bin ]] || fail "bin/ryoku-wallpaper-apply should be executable"

assert_has_route() {
  local route="$1"

  "$ipc" --help | grep -Fq "ryoku-ipc $route" \
    || fail "help should document $route"
}

"$ipc" --help | grep -q "ryoku-ipc shell toggle wallpaper" \
  || fail "help should document shell wallpaper toggle"
"$ipc" --help | grep -q "ryoku-ipc wallpaper list --jsonl" \
  || fail "help should document wallpaper list JSONL"
"$ipc" --help | grep -q "ryoku-ipc wallpaper wallhaven search" \
  || fail "help should document wallhaven search"
"$ipc" --help | grep -q "ryoku-ipc shell toggle themes" \
  || fail "help should document shell themes toggle"
"$ipc" --help | grep -q "ryoku-ipc shell toggle fonts" \
  || fail "help should document shell fonts toggle"
"$ipc" --help | grep -q "ryoku-ipc shell toggle cursors" \
  || fail "help should document shell cursors toggle"
"$ipc" --help | grep -q "ryoku-ipc shell toggle system-menu" \
  || fail "help should document shell system-menu toggle"
"$ipc" --help | grep -q "ryoku-ipc shell toggle settings-menu" \
  || fail "help should document shell settings-menu toggle"
assert_has_route "shell toggle settings-menu"
assert_has_route "shell toggle legacy-settings-menu"
assert_has_route "shell settings-menu wifi"
assert_has_route "shell settings-menu bluetooth"
assert_has_route "shell settings-menu color-scheme"
assert_has_route "shell settings-menu wallpaper"
assert_has_route "shell settings-menu display"
assert_has_route "shell settings-menu audio"
"$ipc" --help | grep -q "ryoku-ipc shell command settings-menu-home" \
  || fail "help should document shell command settings-menu-home"
"$ipc" --help | grep -q "ryoku-ipc shell command settings-menu-share" \
  || fail "help should document shell command settings-menu-share"
"$ipc" --help | grep -q "ryoku-ipc shell command settings-menu-hardware" \
  || fail "help should document shell command settings-menu-hardware"
"$ipc" --help | grep -q "ryoku-ipc shell settings-menu home" \
  || fail "help should document shell settings-menu home route"
"$ipc" --help | grep -q "ryoku-ipc shell settings-menu share" \
  || fail "help should document shell settings-menu share route"
"$ipc" --help | grep -q "ryoku-ipc shell settings-menu hardware" \
  || fail "help should document shell settings-menu hardware route"
"$ipc" --help | grep -q "ryoku-ipc theme list --jsonl" \
  || fail "help should document theme list"
"$ipc" --help | grep -q "ryoku-ipc theme apply THEME" \
  || fail "help should document theme apply"
"$ipc" --help | grep -q "ryoku-ipc font list --jsonl" \
  || fail "help should document font list"
"$ipc" --help | grep -q "ryoku-ipc cursor list --jsonl" \
  || fail "help should document cursor list"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/config/current/theme/backgrounds" "$tmpdir/config/backgrounds/test"
mkdir -p "$tmpdir/ryoku/bin" "$tmpdir/path"
wallpaper_dir="$tmpdir/Pictures/Wallpapers"
printf '%s\n' "test" > "$tmpdir/config/current/theme.name"

cat >"$tmpdir/path/qs" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$tmpdir/path/qs"

for helper in ryoku-wallpaper-list ryoku-wallpaper-cache ryoku-theme-list ryoku-font-list ryoku-cursor-list; do
  cat >"$tmpdir/ryoku/bin/$helper" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$tmpdir/ryoku/bin/$helper"
done

cat >"$tmpdir/ryoku/bin/ryoku-theme-set" <<'EOF'
#!/bin/bash
mkdir -p "$RYOKU_STATE_PATH"
printf '%s\n' "$@" >"$RYOKU_STATE_PATH/theme.args"
EOF
chmod +x "$tmpdir/ryoku/bin/ryoku-theme-set"

cat >"$tmpdir/ryoku/bin/ryoku-wallpaper-apply" <<'EOF'
#!/bin/bash
mkdir -p "$RYOKU_STATE_PATH"
printf '%s\n' "$@" >"$RYOKU_STATE_PATH/apply.args"
EOF
chmod +x "$tmpdir/ryoku/bin/ryoku-wallpaper-apply"

cat >"$tmpdir/ryoku/bin/ryoku-font-set" <<'EOF'
#!/bin/bash
mkdir -p "$RYOKU_STATE_PATH"
printf '%s\n' "$@" >"$RYOKU_STATE_PATH/font.args"
EOF
chmod +x "$tmpdir/ryoku/bin/ryoku-font-set"

cat >"$tmpdir/ryoku/bin/ryoku-font-install" <<'EOF'
#!/bin/bash
mkdir -p "$RYOKU_STATE_PATH"
printf '%s\n' "$@" >"$RYOKU_STATE_PATH/font-install.args"
EOF
chmod +x "$tmpdir/ryoku/bin/ryoku-font-install"

cat >"$tmpdir/ryoku/bin/ryoku-cursor-set" <<'EOF'
#!/bin/bash
mkdir -p "$RYOKU_STATE_PATH"
printf '%s\n' "$@" >"$RYOKU_STATE_PATH/cursor.args"
EOF
chmod +x "$tmpdir/ryoku/bin/ryoku-cursor-set"

cat >"$tmpdir/ryoku/bin/ryoku-cursor-install" <<'EOF'
#!/bin/bash
mkdir -p "$RYOKU_STATE_PATH"
printf '%s\n' "$@" >"$RYOKU_STATE_PATH/cursor-install.args"
EOF
chmod +x "$tmpdir/ryoku/bin/ryoku-cursor-install"

rejects_trailing_args() {
  local description="$1"
  shift

  if RYOKU_PATH="$tmpdir/ryoku" \
    RYOKU_CONFIG_PATH="$tmpdir/config" \
    RYOKU_STATE_PATH="$tmpdir/state" \
    PATH="$tmpdir/path:$PATH" \
    "$ipc" "$@" >/dev/null 2>&1; then
    fail "$description should reject trailing arguments"
  fi
}

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
RYOKU_WALLPAPER_DIR="$wallpaper_dir" \
  "$ipc" wallpaper settings get --json \
  | jq -e --arg wallpaper_dir "$wallpaper_dir" \
      '.wallpaper_dirs == [$wallpaper_dir]' >/dev/null \
  || fail "settings get should emit wallpaper dirs as JSON"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command wallpaper \
  | grep -q 'qs -c ryoku ipc call popups toggleWallpaper' \
  || fail "shell command wallpaper should print the Quickshell IPC command"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command themes \
  | grep -q 'qs -c ryoku ipc call popups toggleThemes' \
  || fail "shell command themes should print the shared selector IPC command"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command fonts \
  | grep -q 'qs -c ryoku ipc call popups toggleFonts' \
  || fail "shell command fonts should print the shared selector IPC command"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command cursors \
  | grep -q 'qs -c ryoku ipc call popups toggleCursors' \
  || fail "shell command cursors should print the shared selector IPC command"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command system-menu \
  | grep -q 'qs -c ryoku ipc call popups toggleSystemMenu' \
  || fail "shell command system-menu should print the Quickshell IPC command"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command settings-menu \
  | grep -q 'qs -c ryoku ipc call popups toggleSettingsMenu' \
  || fail "shell command settings-menu should print the Quickshell IPC command"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command settings-menu-home \
  | grep -q 'qs -c ryoku ipc call popups openSettingsMenuHome' \
  || fail "shell command settings-menu-home should print the Quickshell IPC command"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command settings-menu-share \
  | grep -q 'qs -c ryoku ipc call popups openSettingsMenuShare' \
  || fail "shell command settings-menu-share should print the Quickshell IPC command"

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" shell command settings-menu-hardware \
  | grep -q 'qs -c ryoku ipc call popups openSettingsMenuHardware' \
  || fail "shell command settings-menu-hardware should print the Quickshell IPC command"

rejects_trailing_args "shell command wallpaper" shell command wallpaper extra
rejects_trailing_args "shell command themes" shell command themes extra
rejects_trailing_args "shell command fonts" shell command fonts extra
rejects_trailing_args "shell command cursors" shell command cursors extra
rejects_trailing_args "shell command system-menu" shell command system-menu extra
rejects_trailing_args "shell command settings-menu" shell command settings-menu extra
rejects_trailing_args "shell command settings-menu-home" shell command settings-menu-home extra
rejects_trailing_args "shell command settings-menu-share" shell command settings-menu-share extra
rejects_trailing_args "shell command settings-menu-hardware" shell command settings-menu-hardware extra
rejects_trailing_args "shell toggle wallpaper" shell toggle wallpaper extra
rejects_trailing_args "shell toggle themes" shell toggle themes extra
rejects_trailing_args "shell toggle fonts" shell toggle fonts extra
rejects_trailing_args "shell toggle cursors" shell toggle cursors extra
rejects_trailing_args "shell toggle system-menu" shell toggle system-menu extra
rejects_trailing_args "shell toggle settings-menu" shell toggle settings-menu extra
rejects_trailing_args "shell settings-menu home" shell settings-menu home extra
rejects_trailing_args "shell settings-menu share" shell settings-menu share extra
rejects_trailing_args "shell settings-menu hardware" shell settings-menu hardware extra
rejects_trailing_args "wallpaper settings get --json" wallpaper settings get --json extra
rejects_trailing_args "wallpaper list --jsonl" wallpaper list --jsonl extra
rejects_trailing_args "wallpaper cache rebuild" wallpaper cache rebuild extra
rejects_trailing_args "font list --jsonl" font list --jsonl extra
rejects_trailing_args "font apply" font apply
rejects_trailing_args "font install" font install
rejects_trailing_args "cursor list --jsonl" cursor list --jsonl extra

assert_apply_args() {
  local description="$1"
  local expected_type="$2"
  local expected_path="$3"
  local line_count

  line_count=$(wc -l < "$tmpdir/state/apply.args")
  (( line_count == 3 )) || fail "$description should pass exactly three arguments"
  mapfile -t apply_args < "$tmpdir/state/apply.args"

  [[ ${apply_args[0]} == "--type" ]] \
    || fail "$description should pass --type as the first argument"
  [[ ${apply_args[1]} == "$expected_type" ]] \
    || fail "$description should pass $expected_type as the second argument"
  [[ ${apply_args[2]} == "$expected_path" ]] \
    || fail "$description should preserve the wallpaper path as one argument"
}

sample_image="$tmpdir/wallpaper with spaces.jpg"
: >"$sample_image"

RYOKU_PATH="$tmpdir/ryoku" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" wallpaper apply --type image "$sample_image" >/dev/null \
  || fail "wallpaper image apply should route to ryoku-wallpaper-apply"

assert_apply_args "wallpaper image apply" "image" "$sample_image"

sample_video="$tmpdir/video wallpaper with spaces.mp4"
: >"$sample_video"

RYOKU_PATH="$tmpdir/ryoku" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" wallpaper apply --type video "$sample_video" >/dev/null \
  || fail "wallpaper video apply should route to ryoku-wallpaper-apply"

assert_apply_args "wallpaper video apply" "video" "$sample_video"

RYOKU_PATH="$tmpdir/ryoku" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" theme list --jsonl >/dev/null \
  || fail "theme list should route to ryoku-theme-list"

RYOKU_PATH="$tmpdir/ryoku" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" theme apply "tokyo-night" >/dev/null \
  || fail "theme apply should route to ryoku-theme-set"

mapfile -t theme_args < "$tmpdir/state/theme.args"
(( ${#theme_args[@]} == 1 )) || fail "theme apply should pass exactly one argument"
[[ ${theme_args[0]} == "tokyo-night" ]] || fail "theme apply should preserve theme name"

RYOKU_PATH="$tmpdir/ryoku" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" font list --jsonl >/dev/null \
  || fail "font list should route to ryoku-font-list"

RYOKU_PATH="$tmpdir/ryoku" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" font apply "CaskaydiaMono Nerd Font" >/dev/null \
  || fail "font apply should route to ryoku-font-set"

mapfile -t font_args < "$tmpdir/state/font.args"
(( ${#font_args[@]} == 1 )) || fail "font apply should pass exactly one argument"
[[ ${font_args[0]} == "CaskaydiaMono Nerd Font" ]] || fail "font apply should preserve spaces"

RYOKU_PATH="$tmpdir/ryoku" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" font install "cascadia-mono" >/dev/null \
  || fail "font install should route to ryoku-font-install"

mapfile -t font_install_args < "$tmpdir/state/font-install.args"
(( ${#font_install_args[@]} == 1 )) || fail "font install should pass exactly one argument"
[[ ${font_install_args[0]} == "cascadia-mono" ]] || fail "font install should preserve font id"

RYOKU_PATH="$tmpdir/ryoku" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" cursor list --jsonl >/dev/null \
  || fail "cursor list should route to ryoku-cursor-list"

RYOKU_PATH="$tmpdir/ryoku" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" cursor apply "Bibata-Modern-Ice" 24 >/dev/null \
  || fail "cursor apply should route to ryoku-cursor-set"

mapfile -t cursor_args < "$tmpdir/state/cursor.args"
(( ${#cursor_args[@]} == 2 )) || fail "cursor apply should pass theme and size"
[[ ${cursor_args[0]} == "Bibata-Modern-Ice" ]] || fail "cursor apply should preserve cursor theme"
[[ ${cursor_args[1]} == "24" ]] || fail "cursor apply should preserve cursor size"

RYOKU_PATH="$tmpdir/ryoku" \
RYOKU_CONFIG_PATH="$tmpdir/config" \
RYOKU_STATE_PATH="$tmpdir/state" \
  "$ipc" cursor install "Bibata-Modern-Ice" >/dev/null \
  || fail "cursor install should route to ryoku-cursor-install"

mapfile -t cursor_install_args < "$tmpdir/state/cursor-install.args"
(( ${#cursor_install_args[@]} == 1 )) || fail "cursor install should pass the theme when size is omitted"
[[ ${cursor_install_args[0]} == "Bibata-Modern-Ice" ]] || fail "cursor install should preserve cursor theme"

make_core_path() {
  local core_path="$1"
  local cmd

  mkdir -p "$core_path"
  for cmd in dirname mkdir ln sleep; do
    ln -s "$(command -v "$cmd")" "$core_path/$cmd"
  done
}

write_stub() {
  local path="$1"
  local body="$2"

  printf '%s\n' "#!/bin/bash" "$body" >"$path"
  chmod +x "$path"
}

theme_test_dir="$tmpdir/theme-bg-set"
theme_core_path="$theme_test_dir/core"
theme_stub_path="$theme_test_dir/stubs"
mkdir -p "$theme_stub_path"
make_core_path "$theme_core_path"

theme_image="$theme_test_dir/wallpaper with spaces.jpg"
mkdir -p "$(dirname "$theme_image")"
: >"$theme_image"

write_stub "$theme_stub_path/uwsm-app" 'exit 0'

if RYOKU_PATH="$PWD" \
  RYOKU_CONFIG_PATH="$theme_test_dir/config-missing-swaybg" \
  RYOKU_STATE_PATH="$theme_test_dir/state-missing-swaybg" \
  PATH="$theme_stub_path:$theme_core_path:$PWD/bin" \
  bin/ryoku-theme-bg-set "$theme_image" >/dev/null 2>&1; then
  fail "ryoku-theme-bg-set should fail when swaybg is missing"
fi

write_stub "$theme_stub_path/swaybg" 'exit 0'
write_stub "$theme_stub_path/pkill" 'exit 0'
write_stub "$theme_stub_path/setsid" 'exit 7'

if RYOKU_PATH="$PWD" \
  RYOKU_CONFIG_PATH="$theme_test_dir/config-launch-failure" \
  RYOKU_STATE_PATH="$theme_test_dir/state-launch-failure" \
  PATH="$theme_stub_path:$theme_core_path:$PWD/bin" \
  bin/ryoku-theme-bg-set "$theme_image" >/dev/null 2>&1; then
  fail "ryoku-theme-bg-set should fail when swaybg launcher exits nonzero"
fi

write_stub "$theme_stub_path/setsid" 'exit 0'

RYOKU_PATH="$PWD" \
RYOKU_CONFIG_PATH="$theme_test_dir/config-zero-handoff" \
RYOKU_STATE_PATH="$theme_test_dir/state-zero-handoff" \
PATH="$theme_stub_path:$theme_core_path:$PWD/bin" \
  bin/ryoku-theme-bg-set "$theme_image" >/dev/null \
  || fail "ryoku-theme-bg-set should accept a quick zero-status launcher handoff"

pass "ryoku-ipc contract"
