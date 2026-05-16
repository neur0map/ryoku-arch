#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$ROOT_DIR/$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq -- "$pattern" "$ROOT_DIR/$file"; then
    fail "$message"
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# USB-C-only power supplies should count as AC power.
mkdir -p \
  "$tmp_dir/bin" \
  "$tmp_dir/power/AC0" \
  "$tmp_dir/power/usb_c_port"

cat >"$tmp_dir/bin/powerprofilesctl" <<'EOF'
#!/bin/bash
case "${1:-}" in
  list)
    printf '  performance:\n* balanced:\n'
    ;;
  set)
    printf '%s\n' "${2:-}" >"$RYOKU_TEST_PROFILE_SET"
    ;;
  *)
    exit 2
    ;;
esac
EOF

chmod +x "$tmp_dir/bin/powerprofilesctl"
printf 'Mains\n' >"$tmp_dir/power/AC0/type"
printf '0\n' >"$tmp_dir/power/AC0/online"
printf 'USB\n' >"$tmp_dir/power/usb_c_port/type"
printf '1\n' >"$tmp_dir/power/usb_c_port/online"

RYOKU_POWER_SUPPLY_DIR="$tmp_dir/power" \
RYOKU_TEST_PROFILE_SET="$tmp_dir/profile-set" \
PATH="$tmp_dir/bin:$ROOT_DIR/bin:$PATH" \
  "$ROOT_DIR/bin/ryoku-powerprofiles-set"

[[ $(<"$tmp_dir/profile-set") == "performance" ]] \
  || fail "USB-C online power should autodetect AC and prefer performance"

# refresh-config should create missing destination directories.
mkdir -p "$tmp_dir/ryoku/config/demo"
printf 'new default\n' >"$tmp_dir/ryoku/config/demo/settings.conf"
test_home="$tmp_dir/user"
HOME="$test_home" RYOKU_PATH="$tmp_dir/ryoku" \
  "$ROOT_DIR/bin/ryoku-refresh-config" demo/settings.conf >/dev/null

[[ $(<"$test_home/.config/demo/settings.conf") == "new default" ]] \
  || fail "ryoku-refresh-config should create missing ~/.config subdirectories"

assert_contains "install/config/powerprofilesctl-rules.sh" 'ATTR\{type\}=="USB"' \
  "power profile udev rules should listen for USB-C power supplies"
assert_contains "install/config/powerprofilesctl-rules.sh" 'ryoku-powerprofiles-set"' \
  "udev rules should let ryoku-powerprofiles-set autodetect AC vs battery"
assert_file "install/config/increase-fd-limit.sh"
assert_contains "install/config/all.sh" 'config/increase-fd-limit\.sh' \
  "install config should apply the file descriptor limit"
assert_contains "install/config/increase-fd-limit.sh" 'DefaultLimitNOFILE=' \
  "fd-limit setup should write a systemd DefaultLimitNOFILE value"
assert_contains "bin/ryoku-reinstall-git" 'branch[= ]main| -b main| --branch main' \
  "reinstall-git should pin the Ryoku default branch to main"

assert_not_contains "install/config/all.sh" 'gtk-primary-paste' \
  "this batch should not add the middle-click paste upstream item"

echo "PASS: tests/upstream-core-small-batch.sh"
