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
runtime="$tmp/runtime"
bin_dir="$tmp/bin"
report_tmp="$tmp/reports"
systemctl_log="$tmp/systemctl.log"
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
  "$bin_dir" \
  "$report_tmp"

touch \
  "$runtime/shell.qml" \
  "$runtime/modules/Shortcuts.qml" \
  "$runtime/services/Hypr.qml" \
  "$runtime/assets/systemd/ryoku-shell.service" \
  "$runtime/scripts/ryoku-shell" \
  "$home/.local/lib/qt6/qml/Ryoku/Services/libryoku-services.so"
chmod 755 "$runtime/scripts/ryoku-shell"
ln -s "$runtime/scripts/ryoku-shell" "$home/.local/bin/ryoku-shell"

printf '%s\n' '{"shellUpdates":{"channel":"unstable-dev"}}' >"$home/.config/ryoku-shell/config.json"
cat >"$home/.config/hypr/hyprland.conf" <<'HYPR'
exec-once = sh -lc '$HOME/.local/bin/ryoku-shell run --session'
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
  printf '%s\n' "ryoku-audio-restore-mixers.service enabled enabled"
  exit 0
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

if [[ ${1:-} == "list" ]]; then
  cat <<EOF
Instance test:
  Process ID: 123
  Config path: $RYOKU_TEST_RUNTIME/shell.qml
  Display connection: wayland/wayland-test
EOF
  exit 0
fi

exit 0
SH

for cmd in jq rsync git wl-copy wl-paste cliphist fuzzel grim slurp gradia wpctl nmcli notify-send journalctl pgrep; do
  cat >"$bin_dir/$cmd" <<'SH'
#!/bin/bash
exit 0
SH
done
chmod 755 "$bin_dir/"*

run_shell_doctor() {
  HOME="$home" \
  XDG_CONFIG_HOME="$home/.config" \
  XDG_STATE_HOME="$home/.local/state" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_SHELL_RUNTIME_DIR="$runtime" \
  RYOKU_TEST_RUNTIME="$runtime" \
  RYOKU_SYSTEMCTL_LOG="$systemctl_log" \
  QS_CONFIG_NAME="ryoku-rebirth-shell" \
  TMPDIR="$report_tmp" \
  PATH="$bin_dir:$home/.local/bin:/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-doctor" shell 2>&1
}

output="$(run_shell_doctor)" || fail "ryoku-doctor shell should pass on a healthy Hyprland runtime: $output"

assert_contains "$output" 'Ryoku Doctor: shell' \
  "doctor should expose the shell diagnostics mode"
assert_contains "$output" 'Checking Hyprland compositor' \
  "doctor should check the current Hyprland compositor path"
assert_contains "$output" 'Checking Ryoku shell runtime' \
  "doctor should check the Ryoku shell runtime payload"
assert_not_contains "$output" 'Checking Niri|iNiR|inir' \
  "doctor should not advertise stale Niri/iNiR shell checks"
assert_contains "$output" 'Doctor report:' \
  "doctor should print a shareable report path"

systemctl_output="$(<"$systemctl_log")"
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

set +e
stale_output="$(run_shell_doctor)"
stale_status=$?
set -e

(( stale_status == 0 )) || fail "doctor should repair stale Niri service wiring on Hyprland: $stale_output"
assert_contains "$stale_output" 'Removed stale Niri service wiring' \
  "doctor should call out stale Niri service wiring repair after the Hyprland switch"
[[ ! -e $home/.config/systemd/user/niri.service.wants/ryoku-shell.service ]] \
  || fail "doctor should remove the stale Niri service symlink"

runtime_pick="$tmp/runtime-pick"
old_repo="$tmp/old-repo"
mkdir -p "$runtime_pick" "$old_repo/shell"

cat >"$runtime_pick/setup" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >"$RYOKU_TEST_RUNTIME_ARGS"
echo "runtime doctor selected"
SH
chmod 755 "$runtime_pick/setup"

cat >"$old_repo/shell/setup" <<'SH'
#!/bin/bash
echo "stale installed setup selected" >&2
exit 66
SH
chmod 755 "$old_repo/shell/setup"

runtime_args="$tmp/runtime-args"
runtime_pick_output=$(
  HOME="$home" \
  XDG_CONFIG_HOME="$home/.config" \
  XDG_STATE_HOME="$home/.local/state" \
  RYOKU_PATH="$old_repo" \
  RYOKU_SHELL_RUNTIME_DIR="$runtime_pick" \
  RYOKU_TEST_RUNTIME_ARGS="$runtime_args" \
  TMPDIR="$report_tmp" \
  PATH="$bin_dir:$home/.local/bin:/usr/bin:/bin" \
    "$ROOT_DIR/bin/ryoku-doctor" shell 2>&1
) || fail "ryoku-doctor shell should prefer active runtime setup over stale installed setup: $runtime_pick_output"

grep -Fq "runtime doctor selected" <<<"$runtime_pick_output" \
  || fail "ryoku-doctor shell should run the active runtime setup"
[[ $(<"$runtime_args") == "doctor -y" ]] \
  || fail "ryoku-doctor shell should call setup with command before compatibility flags"

echo "PASS: ryoku doctor shell mode checks the Hyprland Ryoku shell path"
