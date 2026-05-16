#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOCK_HELPER="${RYOKU_LOCK_HELPER:-$ROOT_DIR/bin/ryoku-lock-qylock}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

make_fake_bin() {
  local bin_dir="$1"

  mkdir -p "$bin_dir"

  cat >"$bin_dir/pgrep" <<'EOF'
#!/bin/bash
exit 1
EOF

  cat >"$bin_dir/systemctl" <<'EOF'
#!/bin/bash
exit 0
EOF

  cat >"$bin_dir/quickshell" <<'EOF'
#!/bin/bash
exit 0
EOF

  cat >"$bin_dir/hyprlock" <<'EOF'
#!/bin/bash
printf 'hyprlock\n' >> "$RYOKU_TEST_LOG"
EOF

  chmod +x "$bin_dir"/pgrep "$bin_dir"/systemctl "$bin_dir"/quickshell "$bin_dir"/hyprlock
}

make_home() {
  local home="$1"
  local theme="$2"
  local with_main="$3"

  mkdir -p \
    "$home/.local/share/qylock/themes/$theme" \
    "$home/.local/share/quickshell-lockscreen"

  if [[ $with_main == "yes" ]]; then
    printf 'import QtQuick\nItem {}\n' >"$home/.local/share/qylock/themes/$theme/Main.qml"
  fi

  cat >"$home/.local/share/quickshell-lockscreen/lock.sh" <<'EOF'
#!/bin/bash
printf 'qylock:%s\n' "$1" >> "$RYOKU_TEST_LOG"
EOF
  chmod +x "$home/.local/share/quickshell-lockscreen/lock.sh"
  printf 'import QtQuick\nItem {}\n' >"$home/.local/share/quickshell-lockscreen/lock_shell.qml"
}

run_case() {
  local name="$1"
  local theme="$2"
  local with_main="$3"
  local expected="$4"
  local case_dir="$TMPDIR/$name"
  local home="$case_dir/home"
  local conf_dir="$case_dir/etc/sddm.conf.d"
  local log="$case_dir/lock.log"

  mkdir -p "$conf_dir"
  make_fake_bin "$case_dir/bin"
  make_home "$home" "$theme" "$with_main"
  printf '[Theme]\nCurrent=%s\n' "$theme" >"$conf_dir/theme.conf"
  : >"$log"

  env -i \
    HOME="$home" \
    PATH="$case_dir/bin:/usr/bin:/bin" \
    RYOKU_SDDM_CONF_FILE="$case_dir/etc/sddm.conf" \
    RYOKU_SDDM_CONF_DIR="$conf_dir" \
    RYOKU_TEST_LOG="$log" \
    "$LOCK_HELPER"

  grep -qxF "$expected" "$log" || {
    echo "case '$name' log:" >&2
    sed -n '1,40p' "$log" >&2
    fail "expected lock helper to record '$expected'"
  }
}

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

run_case valid-theme dog-samurai yes "qylock:dog-samurai"
run_case invalid-parent-theme clockwork no "hyprlock"
run_case unsafe-nested-theme-name clockwork/orbital yes "hyprlock"

echo "PASS: tests/qylock-lock-helper-behavior.sh"
