#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_missing_offline_node_payload_does_not_abort_install() {
  local temp_dir home_dir bin_dir log_file status

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  bin_dir="$temp_dir/bin"
  log_file="$temp_dir/mise.log"
  status=0

  mkdir -p "$home_dir" "$bin_dir"

  cat > "$bin_dir/mise" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$*" >> "$MISE_LOG_FILE"
exit 0
EOF

  chmod +x "$bin_dir/mise"

  HOME="$home_dir" \
    PATH="$bin_dir:$PATH" \
    MISE_LOG_FILE="$log_file" \
    RYOKU_CHROOT_INSTALL=1 \
    /bin/bash "$ROOT_DIR/install/config/mise-work.sh" >/dev/null 2>&1 || status=$?

  if (( status != 0 )); then
    rm -rf "$temp_dir"
    fail "mise-work.sh should not abort when offline node payload is missing (status=$status)"
  fi

  if [[ ! -f $home_dir/Work/.mise.toml ]]; then
    rm -rf "$temp_dir"
    fail "mise-work.sh should still create ~/Work/.mise.toml"
  fi

  if ! grep -F "trust $home_dir/Work/.mise.toml" "$log_file" >/dev/null; then
    cat "$log_file" >&2
    rm -rf "$temp_dir"
    fail "mise-work.sh should trust the generated Work mise config"
  fi

  if grep -F "use -g node@" "$log_file" >/dev/null; then
    cat "$log_file" >&2
    rm -rf "$temp_dir"
    fail "mise-work.sh should not select a node version when no offline payload exists"
  fi

  rm -rf "$temp_dir"
}

assert_missing_offline_node_payload_does_not_abort_install

echo "PASS: mise-work offline tests"
