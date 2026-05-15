#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

bin_dir="$temp_dir/bin"
log_file="$temp_dir/snapper.log"

mkdir -p "$bin_dir"

cat >"$bin_dir/sudo" <<'SUDO'
#!/bin/bash
exec "$@"
SUDO

cat >"$bin_dir/snapper" <<'SNAPPER'
#!/bin/bash
printf 'snapper:%s\n' "$*" >>"$RYOKU_TEST_SNAPPER_LOG"

if [[ $1 == "--csvout" && $2 == "list-configs" ]]; then
  printf '%s\n' "Config,Subvolume"
  printf '%s\n' "root,/"
  printf '%s\n' "home,/home"
fi
SNAPPER

chmod +x "$bin_dir/sudo" "$bin_dir/snapper"

output=$(
  HOME="$temp_dir/home" \
  RYOKU_PATH="$ROOT_DIR" \
  RYOKU_TEST_SNAPPER_LOG="$log_file" \
  PATH="$bin_dir:$PATH" \
  "$ROOT_DIR/bin/ryoku-snapshot" create 2>&1
) || fail "ryoku-snapshot create should finish with mocked snapper: $output"

grep -qx 'snapper:--csvout list-configs' "$log_file" || \
  fail "ryoku-snapshot should list configured snapper configs"

for config in root home; do
  grep -qx "snapper:-c $config create -c number -d $(bash "$ROOT_DIR/bin/ryoku-version")" "$log_file" || \
    fail "ryoku-snapshot should create a numbered $config snapshot"
  grep -qx "snapper:-c $config cleanup number" "$log_file" || \
    fail "ryoku-snapshot should enforce numbered cleanup for $config"
done

grep -Eq 'chrootable_systemctl_enable snapper-cleanup\.timer' "$ROOT_DIR/install/login/limine-snapper.sh" || \
  fail "limine-snapper should enable Snapper cleanup so numbered retention is enforced"
grep -Eq 'snapper-timeline\.timer' "$ROOT_DIR/install/login/limine-snapper.sh" || \
  fail "limine-snapper should disable timeline snapshots when Ryoku uses numbered recovery snapshots"

echo "PASS: tests/snapshot-retention.sh"
