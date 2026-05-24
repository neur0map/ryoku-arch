#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
PURGE="$ROOT_DIR/bin/ryoku-rebirth-purge-niri-live"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -x $PURGE ]] || fail "missing executable purge command"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home="$tmp_dir/home"
state="$tmp_dir/state"
bin_dir="$tmp_dir/bin"

mkdir -p \
  "$home/.config/niri" \
  "$home/.config/xdg-desktop-portal" \
  "$home/.config/alacritty" \
  "$home/.config/fish/conf.d" \
  "$home/.config/quickshell/ryoku-shell/scripts/__pycache__" \
  "$home/.config/systemd/user/niri.service.wants" \
  "$home/.config/hypr" \
  "$home/.local/share/ryoku-shell/defaults/niri" \
  "$home/.local/share/ryoku-shell/dots/.config/fish/conf.d" \
  "$home/.local/share/ryoku-shell/dots/.config/xdg-desktop-portal" \
  "$home/.local/share/ryoku-shell/services" \
  "$home/.local/state" \
  "$bin_dir" \
  "$state"

printf 'niri config\n' > "$home/.config/niri/config.kdl"
printf 'old niri backup\n' > "$home/.config/niri.before-main-reset"
printf 'old alacritty backup\n' > "$home/.config/alacritty/alacritty.toml.inir-only-20260502"
printf '[preferred]\n' > "$home/.config/xdg-desktop-portal/niri-portals.conf"
printf 'exec niri-session\n' > "$home/.config/fish/auto-Niri.fish"
printf 'set -gx INIR_VENV old\n' > "$home/.config/fish/conf.d/inir-env.fish"
printf 'old pyc\n' > "$home/.config/quickshell/ryoku-shell/scripts/__pycache__/niri-config.cpython-314.pyc"
printf 'old pyc\n' > "$home/.config/quickshell/ryoku-shell/scripts/__pycache__/parse_niri_keybinds.cpython-314.pyc"
printf 'service link\n' > "$home/.config/systemd/user/niri.service.wants/ryoku-shell.service"
printf "exec-once = sh -lc 'systemctl --user reset-failed ryoku-shell.service >/dev/null 2>&1 || true; exec systemctl --user start ryoku-shell.service'\n" > "$home/.config/hypr/hyprland.conf"
printf 'old niri defaults\n' > "$home/.local/share/ryoku-shell/defaults/niri/config.kdl"
printf 'exec niri-session\n' > "$home/.local/share/ryoku-shell/dots/.config/fish/auto-Niri.fish"
printf 'set -gx INIR_VENV old\n' > "$home/.local/share/ryoku-shell/dots/.config/fish/conf.d/inir-env.fish"
printf '[preferred]\n' > "$home/.local/share/ryoku-shell/dots/.config/xdg-desktop-portal/niri-portals.conf"
printf 'old niri service\n' > "$home/.local/share/ryoku-shell/services/NiriService.qml"

cat > "$bin_dir/ryoku-pkg-present" <<'SH'
#!/bin/bash
case "$1" in
  niri|xdg-desktop-portal-gnome)
    exit 0
    ;;
  *)
    exit 1
    ;;
esac
SH

cat > "$bin_dir/ryoku-pkg-remove" <<'SH'
#!/bin/bash
printf '%s\n' "$*" > "$RYOKU_TEST_STATE/pkg-remove.args"
SH

cat > "$bin_dir/systemctl" <<'SH'
#!/bin/bash
exit 0
SH

cat > "$bin_dir/hyprctl" <<'SH'
#!/bin/bash
exit "${RYOKU_TEST_HYPRCTL_STATUS:-1}"
SH

cat > "$bin_dir/sudo" <<'SH'
#!/bin/bash
if [[ $1 == "-n" && $2 == "true" ]]; then
  exit "${RYOKU_TEST_SUDO_STATUS:-1}"
fi
exit 1
SH

chmod +x "$bin_dir/"*

export HOME="$home"
export XDG_CONFIG_HOME="$home/.config"
export XDG_STATE_HOME="$home/.local/state"
export RYOKU_TEST_STATE="$state"
export PATH="$bin_dir:/usr/bin"
export XDG_CURRENT_DESKTOP=""
export HYPRLAND_INSTANCE_SIGNATURE=""

set +e
"$PURGE" >"$tmp_dir/no-confirm.out" 2>"$tmp_dir/no-confirm.err"
status=$?
set -e
(( status == 2 )) || fail "purge should require explicit confirmation"

set +e
"$PURGE" --confirm-niri-free >"$tmp_dir/no-hypr.out" 2>"$tmp_dir/no-hypr.err"
status=$?
set -e
(( status == 77 )) || fail "purge should refuse outside Hyprland"
[[ -d $home/.config/niri ]] || fail "purge should not move Niri config outside Hyprland"

export HYPRLAND_INSTANCE_SIGNATURE="test"
"$PURGE" --confirm-niri-free >"$tmp_dir/no-auth.out" 2>"$tmp_dir/no-auth.err"
snapshot_dir=$(sed -n 's/^Snapshot: //p' "$tmp_dir/no-auth.out" | tail -1)
[[ -n $snapshot_dir && -d $snapshot_dir ]] || fail "purge should print a valid no-auth snapshot path"
[[ -d $snapshot_dir/removed/config/niri ]] || fail "no-auth purge should archive Niri config"
[[ -f $snapshot_dir/removed/config/niri.before-main-reset ]] || \
  fail "no-auth purge should archive old Niri backup config"
[[ -f $snapshot_dir/removed/config/alacritty/alacritty.toml.inir-only-20260502 ]] || \
  fail "no-auth purge should archive old iNiR-only config backups"
[[ -f $snapshot_dir/removed/config/xdg-desktop-portal/niri-portals.conf ]] || \
  fail "no-auth purge should archive Niri portal config"
[[ -f $snapshot_dir/removed/config/fish/auto-Niri.fish ]] || \
  fail "no-auth purge should archive Niri fish autostart"
[[ -f $snapshot_dir/removed/config/fish/conf.d/inir-env.fish ]] || \
  fail "no-auth purge should archive iNiR fish env"
[[ -f $snapshot_dir/removed/config/quickshell/ryoku-shell/scripts/__pycache__/niri-config.cpython-314.pyc ]] || \
  fail "no-auth purge should archive stale runtime pycache"
[[ -f $snapshot_dir/removed/config/quickshell/ryoku-shell/scripts/__pycache__/parse_niri_keybinds.cpython-314.pyc ]] || \
  fail "no-auth purge should archive stale runtime parser pycache"
[[ -f $snapshot_dir/removed/local-share/ryoku-shell/defaults/niri/config.kdl ]] || \
  fail "no-auth purge should archive stale shell Niri defaults"
[[ -f $snapshot_dir/removed/local-share/ryoku-shell/dots/.config/fish/auto-Niri.fish ]] || \
  fail "no-auth purge should archive stale shell Niri fish defaults"
[[ -f $snapshot_dir/removed/local-share/ryoku-shell/dots/.config/fish/conf.d/inir-env.fish ]] || \
  fail "no-auth purge should archive stale shell iNiR fish env defaults"
[[ -f $snapshot_dir/removed/local-share/ryoku-shell/dots/.config/xdg-desktop-portal/niri-portals.conf ]] || \
  fail "no-auth purge should archive stale shell Niri portal defaults"
[[ -f $snapshot_dir/removed/local-share/ryoku-shell/services/NiriService.qml ]] || \
  fail "no-auth purge should archive stale shell Niri service"
[[ ! -e $home/.config/niri ]] || fail "no-auth purge should remove live Niri config"
[[ ! -e $home/.config/systemd/user/niri.service.wants/ryoku-shell.service ]] || \
  fail "no-auth purge should remove Niri service wiring"
[[ ! -e $state/pkg-remove.args ]] || fail "no-auth purge should not remove packages"
grep -Fq 'Skipped package removal' "$tmp_dir/no-auth.out" || \
  fail "no-auth purge should explain skipped package removal"

export RYOKU_TEST_SUDO_STATUS=0
mkdir -p \
  "$home/.config/niri" \
  "$home/.config/systemd/user/niri.service.wants"
printf 'niri config\n' > "$home/.config/niri/config.kdl"
printf 'service link\n' > "$home/.config/systemd/user/niri.service.wants/ryoku-shell.service"
"$PURGE" --confirm-niri-free >"$tmp_dir/purge.out"

snapshot_dir=$(sed -n 's/^Snapshot: //p' "$tmp_dir/purge.out" | tail -1)
[[ -n $snapshot_dir && -d $snapshot_dir ]] || fail "purge should print a valid snapshot path"
[[ -d $snapshot_dir/removed/config/niri ]] || fail "purge should archive Niri config into the snapshot"
[[ ! -e $home/.config/niri ]] || fail "purge should remove live Niri config"
[[ ! -e $home/.config/systemd/user/niri.service.wants/ryoku-shell.service ]] || \
  fail "purge should remove Niri service wiring"
grep -Fq 'niri xdg-desktop-portal-gnome' "$state/pkg-remove.args" || \
  fail "purge should remove only Niri-specific packages"

printf 'exec-once = ryoku-rebirth-shell\n' > "$home/.config/hypr/hyprland.conf"
set +e
"$PURGE" --confirm-niri-free --force >"$tmp_dir/shell-wired.out" 2>"$tmp_dir/shell-wired.err"
status=$?
set -e
(( status == 77 )) || fail "purge should refuse when an experimental shell is still wired"

echo "PASS: rebirth Niri purge is guarded by live Hyprland proof"
