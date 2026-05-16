#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

run_case() {
  local tmp_dir="$1"
  local blkid_output="$2"
  local selector_output="$3"

  mkdir -p "$tmp_dir/bin"
  : >"$tmp_dir/events"

  cat >"$tmp_dir/bin/blkid" <<'EOF'
#!/bin/bash
printf '%s' "$RYOKU_TEST_BLKID_OUTPUT"
EOF

  cat >"$tmp_dir/bin/ryoku-drive-select" <<'EOF'
#!/bin/bash
drives="$*"
printf 'select:%s\n' "${drives//$'\n'/|}" >>"$RYOKU_TEST_EVENTS"
printf '%s\n' "$RYOKU_TEST_SELECTOR_OUTPUT"
EOF

  cat >"$tmp_dir/bin/sudo" <<'EOF'
#!/bin/bash
printf 'sudo:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
EOF

  chmod 755 "$tmp_dir/bin"/*

  RYOKU_TEST_EVENTS="$tmp_dir/events" \
  RYOKU_TEST_BLKID_OUTPUT="$blkid_output" \
  RYOKU_TEST_SELECTOR_OUTPUT="$selector_output" \
  PATH="$tmp_dir/bin:$PATH" \
    "$ROOT_DIR/bin/ryoku-drive-set-password" >"$tmp_dir/output" 2>&1
}

single_tmp=$(mktemp -d)
run_case "$single_tmp" $'/dev/nvme0n1p2\n' ""

if grep -q '^select:' "$single_tmp/events"; then
  fail "single encrypted drive should not open the drive selector"
fi
grep -qx 'sudo:cryptsetup luksChangeKey --pbkdf argon2id --iter-time 2000 /dev/nvme0n1p2' \
  "$single_tmp/events" || fail "single encrypted drive should be changed directly"

multi_tmp=$(mktemp -d)
run_case "$multi_tmp" $'/dev/nvme0n1p2\n/dev/sda2\n' "/dev/sda2"

grep -qx 'select:/dev/nvme0n1p2|/dev/sda2' "$multi_tmp/events" || \
  fail "multiple encrypted drives should be passed to the selector"
grep -qx 'sudo:cryptsetup luksChangeKey --pbkdf argon2id --iter-time 2000 /dev/sda2' \
  "$multi_tmp/events" || fail "selected encrypted drive should be changed"

empty_tmp=$(mktemp -d)
if run_case "$empty_tmp" "" ""; then
  fail "missing encrypted drives should exit non-zero"
fi
grep -q 'No encrypted drives available.' "$empty_tmp/output" || \
  fail "missing encrypted drives should explain the failure"

grep -q 'wc -l <<<"\$encrypted_drives"' bin/ryoku-drive-set-password || \
  fail "drive password helper should count the actual encrypted drive list"

bash -n bin/ryoku-drive-set-password tests/drive-password-upstream-core.sh

echo "PASS: encrypted drive password upstream parity"
