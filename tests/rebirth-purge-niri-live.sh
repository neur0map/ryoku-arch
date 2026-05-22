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
  "$home/.config/systemd/user/niri.service.wants" \
  "$home/.config/hypr" \
  "$home/.config/quickshell/ryoku-rebirth-shell" \
  "$home/.local/state" \
  "$bin_dir" \
  "$state"

printf 'niri config\n' > "$home/.config/niri/config.kdl"
printf 'service link\n' > "$home/.config/systemd/user/niri.service.wants/ryoku-shell.service"
printf 'exec-once = ryoku-rebirth-shell\n' > "$home/.config/hypr/hyprland.conf"
printf 'shell\n' > "$home/.config/quickshell/ryoku-rebirth-shell/shell.qml"

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
set +e
"$PURGE" --confirm-niri-free >"$tmp_dir/no-auth.out" 2>"$tmp_dir/no-auth.err"
status=$?
set -e
(( status == 77 )) || fail "purge should refuse package removal without auth"
[[ -d $home/.config/niri ]] || fail "purge should not move Niri config before auth is available"

export RYOKU_TEST_SUDO_STATUS=0
"$PURGE" --confirm-niri-free >"$tmp_dir/purge.out"

snapshot_dir=$(sed -n 's/^Snapshot: //p' "$tmp_dir/purge.out" | tail -1)
[[ -n $snapshot_dir && -d $snapshot_dir ]] || fail "purge should print a valid snapshot path"
[[ -d $snapshot_dir/removed/config/niri ]] || fail "purge should archive Niri config into the snapshot"
[[ ! -e $home/.config/niri ]] || fail "purge should remove live Niri config"
[[ ! -e $home/.config/systemd/user/niri.service.wants/ryoku-shell.service ]] || \
  fail "purge should remove Niri service wiring"
grep -Fq 'niri xdg-desktop-portal-gnome' "$state/pkg-remove.args" || \
  fail "purge should remove only Niri-specific packages"

echo "PASS: rebirth Niri purge is guarded by live Hyprland proof"
