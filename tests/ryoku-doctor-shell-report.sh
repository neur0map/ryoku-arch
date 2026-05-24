#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local text="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" <<<"$text" || fail "$message"
}

assert_not_contains() {
  local text="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq -- "$pattern" <<<"$text"; then
    fail "$message"
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
runtime="$home/.config/quickshell/ryoku-shell"
legacy_runtime="$home/.config/quickshell/legacy-host-shell"
bin_dir="$tmp/bin"
report_tmp="$tmp/reports"
systemctl_log="$tmp/systemctl.log"
qs_kill_log="$tmp/qs-kill.log"
qs_killed_marker="$tmp/qs-stale-killed"
gum_log="$tmp/gum.log"
current_user="$(id -un)"
current_host="$(hostname 2>/dev/null || true)"

mkdir -p \
  "$home/.config/hypr" \
  "$home/.config/ryoku-shell" \
  "$home/.local/bin" \
  "$home/.local/state" \
  "$home/.local/lib/qt6/qml/Ryoku/Services" \
  "$runtime/assets/systemd" \
  "$runtime/modules" \
  "$runtime/scripts" \
  "$runtime/services" \
  "$legacy_runtime" \
  "$bin_dir" \
  "$report_tmp"

touch \
  "$runtime/shell.qml" \
  "$legacy_runtime/shell.qml" \
  "$runtime/modules/Shortcuts.qml" \
  "$runtime/services/Hypr.qml" \
  "$runtime/assets/systemd/ryoku-shell.service" \
  "$runtime/scripts/ryoku-shell" \
  "$home/.local/lib/qt6/qml/Ryoku/Services/libryoku-services.so"
chmod 755 "$runtime/scripts/ryoku-shell"
ln -s "$runtime/scripts/ryoku-shell" "$home/.local/bin/ryoku-shell"

cat >"$home/.config/ryoku-shell/config.json" <<'JSON'
{
  "gameMode": {
    "disableNiriAnimations": false,
    "niriWindowListUpdateIntervalMs": 100,
    "niriWindowListUpdateIntervalMsGameMode": 500
  },
  "overlay": {
    "recorder": {
      "disableNiriAnims": false
    }
  },
  "shellUpdates": {
    "channel": "unstable-dev"
  }
}
JSON
printf '%s\n' '~/.config/niri/config.kdl' >"$home/.config/ryoku-shell/installed_listfile"
printf '%s\n' '{"applied":["018-modularize-niri-config"]}' >"$home/.config/ryoku-shell/migrations.json"
cat >"$home/.config/hypr/hyprland.conf" <<'HYPR'
exec-once = sh -lc 'systemctl --user reset-failed ryoku-shell.service >/dev/null 2>&1 || true; exec systemctl --user start ryoku-shell.service'
bind = SUPER, comma, exec, $systemPanel
HYPR

cat >"$bin_dir/systemctl" <<'SH'
#!/bin/bash
if [[ -n ${RYOKU_SYSTEMCTL_LOG:-} ]]; then
  printf '%s\n' "$*" >> "$RYOKU_SYSTEMCTL_LOG"
fi

if [[ ${1:-} == "--user" && ${2:-} == "is-active" && ${3:-} == "ryoku-shell.service" ]]; then
  printf '%s\n' "active"
  exit 0
fi
if [[ ${1:-} == "--user" && ${2:-} == "cat" && ${3:-} == "ryoku-shell.service" ]]; then
  printf '%s\n' "[Service]"
  printf '%s\n' "ExecStart=%h/.local/bin/ryoku-shell run --session"
  exit 0
fi
if [[ ${1:-} == "--user" && ${2:-} == "show-environment" ]]; then
  printf '%s\n' "XDG_CURRENT_DESKTOP=Hyprland"
  exit 0
fi
# Stubs for the audio-restore-mixers check (added with the rebirth doctor pass).
if [[ ${1:-} == "--user" && ${2:-} == "list-unit-files" && ${3:-} == "ryoku-audio-restore-mixers.service" ]]; then
  if [[ -f $HOME/.config/systemd/user/ryoku-audio-restore-mixers.service ]]; then
    printf '%s\n' "ryoku-audio-restore-mixers.service enabled enabled"
    exit 0
  fi
  exit 1
fi
if [[ ${1:-} == "--user" && ${2:-} == "is-enabled" && ${3:-} == "ryoku-audio-restore-mixers.service" ]]; then
  printf '%s\n' "enabled"
  exit 0
fi
exit 0
SH

# Fake ldd that reports the Ryoku Services plugin links libcava - exercises
# the rebirth doctor's native-plugin check without needing a real .so on disk.
cat >"$bin_dir/ldd" <<'SH'
#!/bin/bash
if [[ ${1:-} == *Ryoku/Services/libryoku-services.so ]]; then
  printf '\tlibcava.so.0 => /usr/lib/libcava.so.0 (0x00007f0000000000)\n'
  printf '\tlibQt6Core.so.6 => /usr/lib/libQt6Core.so.6 (0x00007f0000000000)\n'
  printf '\tlibc.so.6 => /usr/lib/libc.so.6 (0x00007f0000000000)\n'
  exit 0
fi
exit 0
SH

cat >"$bin_dir/hyprctl" <<'SH'
#!/bin/bash
case "${1:-}" in
  version)
    printf '%s\n' "Hyprland 0.55.2"
    ;;
  configerrors)
    ;;
  *)
    ;;
esac
SH

cat >"$bin_dir/qs" <<'SH'
#!/bin/bash
if [[ -n ${QS_CONFIG_NAME:-} || -n ${QS_CONFIG_PATH:-} || -n ${QS_MANIFEST:-} ]]; then
  echo "stale quickshell config environment leaked into qs" >&2
  exit 9
fi

if [[ ${1:-} == "kill" ]]; then
  printf '%s\n' "$*" >> "$RYOKU_QS_KILL_LOG"
  touch "$RYOKU_QS_KILLED_MARKER"
  exit 0
fi

if [[ ${1:-} == "list" ]]; then
  cat <<EOF
Instance test:
  Process ID: 123
  Config path: $RYOKU_TEST_RUNTIME/shell.qml
  Display connection: wayland/wayland-test
Instance duplicate:
  Process ID: 789
  Config path: $RYOKU_TEST_RUNTIME/shell.qml
  Display connection: wayland/wayland-test
EOF
  if [[ -n ${RYOKU_TEST_LEGACY_RUNTIME:-} && ! -f $RYOKU_QS_KILLED_MARKER ]]; then
    cat <<EOF
Instance stale:
  Process ID: 456
  Config path: $RYOKU_TEST_LEGACY_RUNTIME/shell.qml
  Display connection: wayland/wayland-test
EOF
  fi
  exit 0
fi

exit 0
SH

cat >"$bin_dir/gum" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >> "$RYOKU_GUM_LOG"

if [[ ${1:-} == "style" ]]; then
  shift
  skip=false
  for arg in "$@"; do
    if [[ $skip == true ]]; then
      skip=false
      continue
    fi
    case "$arg" in
      --border | --border-foreground | --foreground | --padding | --margin)
        skip=true
        ;;
      --*)
        ;;
      *)
        printf '%s\n' "$arg"
        ;;
    esac
  done
fi
SH
chmod 755 "$bin_dir/gum"

for cmd in rsync git wl-copy wl-paste cliphist fuzzel grim slurp gradia wpctl nmcli notify-send journalctl pgrep pkill; do
  cat >"$bin_dir/$cmd" <<'SH'
#!/bin/bash
exit 0
SH
done
chmod 755 "$bin_dir/"*

cat >"$bin_dir/pgrep" <<'SH'
#!/bin/bash
[[ ${RYOKU_TEST_STALE_HYPRIDLE_RUNNING:-0} == "1" ]]
SH
chmod 755 "$bin_dir/pgrep"

run_shell_doctor() {
  HOME="$home" \
  XDG_CONFIG_HOME="$home/.config" \
  XDG_STATE_HOME="$home/.local/state" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_SHELL_RUNTIME_DIR="$runtime" \
  RYOKU_TEST_RUNTIME="$runtime" \
  RYOKU_TEST_LEGACY_RUNTIME="$legacy_runtime" \
  RYOKU_QS_KILL_LOG="$qs_kill_log" \
  RYOKU_QS_KILLED_MARKER="$qs_killed_marker" \
  RYOKU_SYSTEMCTL_LOG="$systemctl_log" \
  RYOKU_DOCTOR_PRETTY=1 \
  RYOKU_DOCTOR_FORCE_GUM_REPAIR="${RYOKU_DOCTOR_FORCE_GUM_REPAIR:-0}" \
  RYOKU_DOCTOR_GUM_INSTALLER="${RYOKU_DOCTOR_GUM_INSTALLER:-ryoku-pkg-add}" \
  RYOKU_PKG_ADD_LOG="${RYOKU_PKG_ADD_LOG:-}" \
  RYOKU_GUM_LOG="$gum_log" \
  RYOKU_TEST_STALE_HYPRIDLE_RUNNING="${RYOKU_TEST_STALE_HYPRIDLE_RUNNING:-0}" \
  QS_CONFIG_NAME="ryoku-rebirth-shell" \
  TMPDIR="$report_tmp" \
  PATH="$bin_dir:$home/.local/bin:/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-doctor" 2>&1
}

output="$(run_shell_doctor)" || fail "ryoku-doctor shell should pass on a healthy Hyprland runtime: $output"

assert_contains "$output" 'Ryoku Doctor' \
  "public doctor should show the gum-styled title when interactive styling is available"
assert_contains "$output" 'Expected: .*/bin/ryoku-doctor' \
  "public doctor should show which installed doctor path should be active"
assert_contains "$output" 'Shell health \+ automatic repair' \
  "public doctor should describe the useful repair mode instead of looking like raw logs"
assert_contains "$output" 'Hyprland shell health \+ automatic repair' \
  "shell doctor should expose the styled shell diagnostics mode"
assert_contains "$output" 'Checking Hyprland compositor' \
  "doctor should check the current Hyprland compositor path"
assert_contains "$output" 'Checking Ryoku shell runtime' \
  "doctor should check the Ryoku shell runtime payload"
assert_contains "$output" 'FIX: Stopped duplicate/stale Quickshell runtime' \
  "doctor should repair duplicate Quickshell runtimes instead of allowing two bars"
assert_contains "$output" 'FIX: Restarted ryoku-shell.service to collapse duplicate Ryoku bars' \
  "doctor should repair duplicate canonical Ryoku shell runtimes instead of allowing two bars"
assert_not_contains "$output" 'Checking Niri|iNiR|inir' \
  "doctor should not advertise stale Niri/iNiR shell checks"
assert_contains "$output" 'Doctor report:' \
  "doctor should print a shareable report path"
assert_contains "$output" 'Repaired rebirth audio mixer self-heal service' \
  "doctor should install the rebirth audio restore service before shell diagnostics"
assert_contains "$output" 'OK: ryoku-audio-restore-mixers.service is enabled' \
  "doctor should clear the pre-rebirth audio restore service failure"
assert_contains "$output" 'Removed stale Niri-era shell config metadata' \
  "doctor should remove stale Niri-era user config and installer metadata"
if grep -Eq 'disableNiri|niriWindow|disableNiriAnims' "$home/.config/ryoku-shell/config.json"; then
  fail "doctor should remove stale Niri-era keys from active shell config"
fi
[[ ! -e $home/.config/ryoku-shell/installed_listfile ]] || \
  fail "doctor should remove stale shell installer list metadata"
[[ ! -e $home/.config/ryoku-shell/migrations.json ]] || \
  fail "doctor should remove stale shell migration metadata"
gum_output="$(<"$gum_log")"
assert_contains "$gum_output" 'style .*Ryoku Doctor' \
  "public doctor should invoke gum for the entrypoint UI"
assert_contains "$gum_output" 'style .*Summary: passed=' \
  "shell doctor should render the final summary through gum instead of raw fallback text"

pkg_add_log="$tmp/pkg-add.log"
cat >"$bin_dir/ryoku-pkg-add" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >> "$RYOKU_PKG_ADD_LOG"
SH
chmod 755 "$bin_dir/ryoku-pkg-add"
rm -f "$gum_log"
export RYOKU_PKG_ADD_LOG="$pkg_add_log"
export RYOKU_DOCTOR_FORCE_GUM_REPAIR=1
export RYOKU_DOCTOR_GUM_INSTALLER="$bin_dir/ryoku-pkg-add"

output="$(run_shell_doctor)" || fail "ryoku-doctor should repair gum before rendering: $output"
assert_contains "$output" 'Ryoku Doctor: installing missing UI dependency: gum' \
  "doctor should explain when it self-heals the missing gum UI dependency"
assert_contains "$output" 'Ryoku Doctor' \
  "doctor should render the styled title after repairing gum"
grep -Fxq 'gum' "$pkg_add_log" || \
  fail "doctor should install gum through ryoku-pkg-add when the UI dependency is missing"
unset RYOKU_DOCTOR_FORCE_GUM_REPAIR
unset RYOKU_DOCTOR_GUM_INSTALLER

qs_kill_output="$(<"$qs_kill_log")"
assert_contains "$qs_kill_output" "kill -p $legacy_runtime --any-display" \
  "doctor should kill the stale host-shell Quickshell runtime"
assert_contains "$qs_kill_output" "kill -p $runtime --any-display" \
  "doctor should restart duplicate canonical Ryoku shell runtimes"

systemctl_output="$(<"$systemctl_log")"
assert_contains "$systemctl_output" '--user enable --now ryoku-audio-restore-mixers.service' \
  "doctor should enable the rebirth audio restore service"
assert_contains "$systemctl_output" '--user import-environment .*XDG_CURRENT_DESKTOP.*HYPRLAND_INSTANCE_SIGNATURE.*PATH' \
  "doctor should import the active Hyprland session environment into user systemd"
assert_contains "$systemctl_output" '--user stop niri.service xdg-desktop-portal-gnome.service' \
  "doctor should stop stale Niri/GNOME portal user services after rebirth"
assert_contains "$systemctl_output" '--user start xdg-desktop-portal-hyprland.service xdg-desktop-portal.service' \
  "doctor should start the Hyprland portal stack after rebirth"

report_path="$(sed -n 's/.*Doctor report: //p' <<<"$output" | tail -n1)"
[[ -f $report_path ]] || fail "doctor report should exist"
[[ $report_path == "$report_tmp"/ryoku-doctor-report.*/report.txt ]] \
  || fail "doctor report should be written under TMPDIR with a ryoku-doctor-report prefix"
grep -Fq 'Compositor: Hyprland' "$report_path" \
  || fail "doctor report should record the Hyprland compositor"
grep -Fq "$home" "$report_path" \
  && fail "doctor report should anonymize the home path"
grep -Fq "$current_user" "$report_path" \
  && fail "doctor report should anonymize the username"
[[ -n $current_host ]] && grep -Fq "$current_host" "$report_path" \
  && fail "doctor report should anonymize the hostname"

mkdir -p "$home/.config/systemd/user/niri.service.wants"
ln -s "$home/.config/systemd/user/ryoku-shell.service" \
  "$home/.config/systemd/user/niri.service.wants/ryoku-shell.service"
mkdir -p "$home/.config/systemd/user/ryoku-shell.service.d"
printf '%s\n' '[Service]' 'Environment=QT_WAYLAND_DISABLE_FRACTIONAL_SCALE=1' \
  >"$home/.config/systemd/user/ryoku-shell.service.d/qt6-fractional-scale-workaround.conf"
printf '%s\n' 'stale hypridle config' >"$home/.config/hypr/hypridle-rebirth.conf"
printf '%s\n' 'exec-once = hypridle -c ~/.config/hypr/hypridle-rebirth.conf' \
  >>"$home/.config/hypr/hyprland.conf"
export RYOKU_TEST_STALE_HYPRIDLE_RUNNING=1

set +e
stale_output="$(run_shell_doctor)"
stale_status=$?
set -e
unset RYOKU_TEST_STALE_HYPRIDLE_RUNNING

(( stale_status == 0 )) || fail "doctor should repair stale Niri service wiring on Hyprland: $stale_output"
assert_contains "$stale_output" 'Removed stale Niri service wiring' \
  "doctor should call out stale Niri service wiring repair after the Hyprland switch"
assert_contains "$stale_output" 'Removed stale Qt fractional-scale drop-in' \
  "doctor should call out retired Qt fractional-scale drop-in cleanup"
assert_contains "$stale_output" 'Removed stale Hyprland hypridle exec-once' \
  "doctor should remove the stale Hyprland-spawned hypridle startup"
assert_contains "$stale_output" 'Removed stale hypridle rebirth config' \
  "doctor should remove the retired rebirth hypridle config"
assert_contains "$stale_output" 'Stopped stale Hyprland-spawned hypridle instance' \
  "doctor should stop the duplicate Hyprland-spawned hypridle process when the service is active"
[[ ! -e $home/.config/systemd/user/niri.service.wants/ryoku-shell.service ]] \
  || fail "doctor should remove the stale Niri service symlink"
[[ ! -e $home/.config/systemd/user/ryoku-shell.service.d/qt6-fractional-scale-workaround.conf ]] \
  || fail "doctor should remove the retired Qt fractional-scale drop-in"
[[ ! -e $home/.config/hypr/hypridle-rebirth.conf ]] \
  || fail "doctor should remove the retired rebirth hypridle config"
! grep -Fxq 'exec-once = hypridle -c ~/.config/hypr/hypridle-rebirth.conf' "$home/.config/hypr/hyprland.conf" \
  || fail "doctor should remove stale Hyprland hypridle exec-once lines"

runtime_pick="$tmp/runtime-pick"
old_repo="$tmp/old-repo"
mkdir -p "$runtime_pick" "$old_repo/shell"

cat >"$runtime_pick/setup" <<'SH'
#!/bin/bash
echo "stale runtime setup selected" >&2
exit 66
SH
chmod 755 "$runtime_pick/setup"

cat >"$old_repo/shell/setup" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >"$RYOKU_TEST_RUNTIME_ARGS"
printf '%s\n' "${RYOKU_SHELL_RUNTIME_DIR:-}" >"$RYOKU_TEST_RUNTIME_ENV"
echo "repo doctor selected"
SH
chmod 755 "$old_repo/shell/setup"

runtime_args="$tmp/runtime-args"
runtime_env="$tmp/runtime-env"
runtime_pick_output=$(
  HOME="$home" \
  XDG_CONFIG_HOME="$home/.config" \
  XDG_STATE_HOME="$home/.local/state" \
  RYOKU_PATH="$old_repo" \
  RYOKU_SHELL_RUNTIME_DIR="$runtime_pick" \
  RYOKU_TEST_RUNTIME_ARGS="$runtime_args" \
  RYOKU_TEST_RUNTIME_ENV="$runtime_env" \
  TMPDIR="$report_tmp" \
  PATH="$bin_dir:$home/.local/bin:/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-doctor" 2>&1
) || fail "ryoku-doctor should prefer updated repo setup over stale runtime setup: $runtime_pick_output"

grep -Fq "repo doctor selected" <<<"$runtime_pick_output" \
  || fail "ryoku-doctor should run the repo-managed setup after updates"
[[ $(<"$runtime_args") == "doctor -y" ]] \
  || fail "ryoku-doctor shell should call setup with command before compatibility flags"
[[ $(<"$runtime_env") == "" ]] \
  || fail "ryoku-doctor should not let stale RYOKU_SHELL_RUNTIME_DIR select the old host-shell runtime"

echo "PASS: ryoku doctor shell mode checks the Hyprland Ryoku shell path"
