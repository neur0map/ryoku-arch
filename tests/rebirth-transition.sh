#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TRANSITION="$ROOT_DIR/bin/ryoku-rebirth-transition"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Fq "$pattern" "$path" || fail "$message"
}

write_stub() {
  local path="$1"
  local body="$2"

  mkdir -p "$(dirname "$path")"
  {
    printf '%s\n' '#!/bin/bash'
    printf '%s\n' "$body"
  } >"$path"
  chmod +x "$path"
}

[[ -f $TRANSITION ]] || fail "missing transition script"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home="$tmp_dir/home"
canonical_ryoku="$home/.local/share/ryoku"
ryoku="$home/.local/share/omarchy"
state="$home/.local/state/ryoku"
runtime="$home/.config/quickshell/ryoku-shell"
legacy_runtime="$home/.config/quickshell/legacy-host-shell"
bin_dir="$tmp_dir/bin"
log_file="$tmp_dir/calls.log"

mkdir -p \
  "$home" \
  "$ryoku/bin" \
  "$ryoku/install/config" \
  "$ryoku/lib" \
  "$ryoku/config/hypr" \
  "$ryoku/wallpapers" \
  "$runtime" \
  "$legacy_runtime" \
  "$bin_dir"

printf '# test runtime env\n' >"$ryoku/lib/runtime-env.sh"
printf 'wallpaper\n' >"$ryoku/wallpapers/new-ryoku-walls-v0-jk6dv9e00s2h1.webp"
touch \
  "$ryoku/config/hypr/colors.conf" \
  "$ryoku/config/hypr/hypridle-rebirth.conf" \
  "$ryoku/config/hypr/hyprland.conf" \
  "$ryoku/config/hypr/hyprland-gui.conf"

write_stub "$bin_dir/sudo" 'exit 0'
write_stub "$bin_dir/hyprctl" 'printf "[]\n"'
write_stub "$bin_dir/systemctl" 'printf "systemctl:%s\n" "$*" >> "$RYOKU_TEST_LOG"'
cat >"$bin_dir/qs" <<'SH'
#!/bin/bash
if [[ ${1:-} == "list" ]]; then
  cat <<EOF
Instance ryoku:
  Process ID: 123
  Config path: $RYOKU_TEST_RUNTIME/shell.qml
  Display connection: wayland/wayland-test
Instance stale:
  Process ID: 456
  Config path: $RYOKU_TEST_LEGACY_RUNTIME/shell.qml
  Display connection: wayland/wayland-test
EOF
  exit 0
fi

if [[ ${1:-} == "kill" ]]; then
  printf "qs:%s\n" "$*" >> "$RYOKU_TEST_LOG"
  exit 0
fi

exit 0
SH
chmod +x "$bin_dir/qs"
write_stub "$ryoku/bin/ryoku-update-git" 'printf "update-git:%s\n" "${RYOKU_UPDATE_BRANCH:-}" >> "$RYOKU_TEST_LOG"'
write_stub "$ryoku/bin/ryoku-rebirth-prepare-live" 'printf "prepare:%s\n" "$*" >> "$RYOKU_TEST_LOG"'
write_stub "$ryoku/bin/ryoku-snapshot" 'printf "snapshot:%s\n" "$*" >> "$RYOKU_TEST_LOG"'
write_stub "$ryoku/bin/ryoku-update-perform" 'printf "perform\n" >> "$RYOKU_TEST_LOG"'
write_stub "$ryoku/bin/ryoku-refresh-config" 'printf "refresh:%s\n" "$1" >> "$RYOKU_TEST_LOG"'
write_stub "$ryoku/install/config/config.sh" 'printf "config-setup\n" >> "$RYOKU_TEST_LOG"'
write_stub "$ryoku/install/config/ryoku-audio-restore-mixers.sh" 'printf "audio-service\n" >> "$RYOKU_TEST_LOG"'
write_stub "$ryoku/bin/ryoku-wallpaper-apply" 'printf "wallpaper:%s\n" "$*" >> "$RYOKU_TEST_LOG"'
write_stub "$ryoku/bin/ryoku-install-qylock" 'printf "qylock:%s\n" "$*" >> "$RYOKU_TEST_LOG"'
write_stub "$ryoku/bin/ryoku-restart-ui" 'printf "restart-ui:%s\n" "$*" >> "$RYOKU_TEST_LOG"'
write_stub "$ryoku/bin/ryoku-rebirth-purge-niri-live" 'printf "purge:%s\n" "$*" >> "$RYOKU_TEST_LOG"; exit "${RYOKU_TEST_PURGE_STATUS:-0}"'

output="$tmp_dir/transition.out"
set +e
HOME="$home" \
RYOKU_PATH="" \
RYOKU_STATE_PATH="$state" \
RYOKU_TEST_LOG="$log_file" \
RYOKU_TEST_RUNTIME="$runtime" \
RYOKU_TEST_LEGACY_RUNTIME="$legacy_runtime" \
RYOKU_TEST_PURGE_STATUS=77 \
PATH="$bin_dir:/usr/bin:/bin" \
  "$TRANSITION" --allow-auth-prompt >"$output" 2>&1
status=$?
set -e

if (( status != 0 )); then
  cat "$output" >&2
  fail "transition should complete the bootstrap and defer purge when Hyprland is not active"
fi

[[ -L $canonical_ryoku ]] \
  || fail "transition should expose legacy installs at ~/.local/share/ryoku for new defaults"
[[ $(readlink "$canonical_ryoku") == "$ryoku" ]] \
  || fail "canonical Ryoku path should point at the legacy installed checkout"
[[ -L $home/.local/lib/runtime-env.sh ]] \
  || fail "transition should create the legacy ~/.local/lib/runtime-env.sh bridge"
[[ $(readlink "$home/.local/lib/runtime-env.sh") == "$ryoku/lib/runtime-env.sh" ]] \
  || fail "legacy runtime-env bridge should point to the installed checkout"
[[ $(<"$state/channel") == "unstable-dev" ]] \
  || fail "transition should persist the unstable-dev channel"
assert_contains "$home/.config/ryoku-shell/config.json" '"channel": "unstable-dev"' \
  "transition should persist the shell update channel"
assert_contains "$log_file" 'update-git:unstable-dev' \
  "transition should update the checkout through the selected branch"
assert_contains "$log_file" 'config-setup' \
  "transition should run default config and wallpaper seeding for full-install parity"
assert_contains "$log_file" 'audio-service' \
  "transition should install rebirth user services for full-install parity"
assert_contains "$log_file" 'prepare:--allow-auth-prompt' \
  "transition should pass auth prompt permission to rebirth preparation"
assert_contains "$log_file" 'wallpaper:--type image' \
  "transition should apply a default rebirth wallpaper when shell wallpaper state is empty"
assert_contains "$log_file" 'qylock:--theme clockwork' \
  "transition should install the default qylock clockwork lockscreen"
assert_contains "$log_file" 'snapshot:create' \
  "transition should create a snapshot before update stages"
assert_contains "$log_file" 'perform' \
  "transition should run the normal update stages"
assert_contains "$log_file" 'refresh:hypr/hyprland.conf' \
  "transition should refresh the rebirth Hyprland config"
assert_contains "$log_file" 'restart-ui:--quiet' \
  "transition should refresh the running desktop UI after config/runtime convergence"
assert_contains "$log_file" 'systemctl:--user stop niri.service xdg-desktop-portal-gnome.service' \
  "transition should stop stale Niri/GNOME portal services after purge"
assert_contains "$log_file" 'systemctl:--user start xdg-desktop-portal-hyprland.service xdg-desktop-portal.service' \
  "transition should start the Hyprland portal after purge"
assert_contains "$log_file" "qs:kill -p $legacy_runtime --any-display" \
  "transition should stop stale host-shell Quickshell runtimes during rebirth cleanup"
assert_contains "$log_file" 'purge:--confirm-niri-free --allow-auth-prompt' \
  "transition should call the guarded Niri purge"
assert_contains "$output" 'Choose the Hyprland session.' \
  "transition should explain the second run when purge is deferred"
assert_contains "$output" 'After that second run finishes, reboot once more' \
  "transition should explain the required final reboot after the second Hyprland run"
[[ -s $home/.local/state/ryoku-shell/wallpaper/path.txt ]] \
  || fail "transition should write the Ryoku shell wallpaper state"
[[ $(<"$home/.config/qylock/theme") == "clockwork/orbital" ]] \
  || fail "transition should write qylock's clockwork/orbital lockscreen theme"

echo "PASS: ryoku rebirth transition bootstraps stuck legacy installs"
