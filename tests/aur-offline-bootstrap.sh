#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temp_dir_bootstrap=
temp_dir_access=

link_cmd() {
  local cmd="$1"
  local dest_dir="$2"

  ln -sf "$(command -v "$cmd")" "$dest_dir/$cmd"
}

make_test_path() {
  local bin_dir="$1"
  local cmd

  mkdir -p "$bin_dir"

  for cmd in find grep head install mktemp rm sed sleep tar; do
    link_cmd "$cmd" "$bin_dir"
  done
}

fail() {
  echo "FAIL: $*" >&2
  return 1
}

cleanup() {
  [[ -n $temp_dir_bootstrap ]] && rm -rf "$temp_dir_bootstrap"
  [[ -n $temp_dir_access ]] && rm -rf "$temp_dir_access"
}

assert_offline_yay_bootstrap_is_best_effort() {
  local temp_dir="$1"
  local bin_dir="$temp_dir/bin"
  local status=0

  make_test_path "$bin_dir"

  cat > "$bin_dir/ryoku-pkg-add" <<'EOF'
#!/bin/bash
exit 0
EOF

  cat > "$bin_dir/git" <<'EOF'
#!/bin/bash
echo "simulated git failure" >&2
exit 1
EOF

  cat > "$bin_dir/curl" <<'EOF'
#!/bin/bash
echo "simulated curl failure" >&2
exit 6
EOF

  cat > "$bin_dir/sudo" <<'EOF'
#!/bin/bash
echo "sudo should not be called during offline yay bootstrap" >&2
exit 99
EOF

  chmod +x "$bin_dir/ryoku-pkg-add" "$bin_dir/git" "$bin_dir/curl" "$bin_dir/sudo"

  env -i HOME="$temp_dir/home" PATH="$bin_dir" \
    /bin/bash "$ROOT_DIR/install/preflight/yay-bootstrap.sh" \
    >"$temp_dir/yay-bootstrap.log" 2>&1 || status=$?

  if (( status != 0 )); then
    echo "FAIL: offline yay bootstrap should not abort install (status=$status)" >&2
    cat "$temp_dir/yay-bootstrap.log" >&2
    return 1
  fi
}

assert_aur_access_requires_yay() {
  local temp_dir="$1"
  local bin_dir="$temp_dir/bin"

  make_test_path "$bin_dir"

  cat > "$bin_dir/curl" <<'EOF'
#!/bin/bash
exit 0
EOF

  chmod +x "$bin_dir/curl"

  if env -i HOME="$temp_dir/home" PATH="$bin_dir" \
    /bin/bash "$ROOT_DIR/bin/ryoku-pkg-aur-accessible" \
    >"$temp_dir/aur-access.log" 2>&1; then
    echo "FAIL: AUR access guard should fail when yay is missing" >&2
    cat "$temp_dir/aur-access.log" >&2
    return 1
  fi
}

assert_iso_aur_overlay_retries_clones() {
  local script="$ROOT_DIR/iso/builder/build-boot-overlay.sh"

  grep -Eq 'aur_clone\(\)' "$script" || \
    fail "ISO AUR overlay builder should wrap AUR git clones"
  grep -Eq 'for attempt in \{1\.\.3\}' "$script" || \
    fail "ISO AUR overlay builder should retry transient AUR clone failures"
  grep -Eq 'git clone of \$pkg from AUR failed' "$script" || \
    fail "ISO AUR overlay builder should explain retrying AUR clone failures"
}

main() {
  temp_dir_bootstrap="$(mktemp -d)"
  temp_dir_access="$(mktemp -d)"
  trap cleanup EXIT

  assert_offline_yay_bootstrap_is_best_effort "$temp_dir_bootstrap"
  assert_aur_access_requires_yay "$temp_dir_access"
  assert_iso_aur_overlay_retries_clones
}

main "$@"
