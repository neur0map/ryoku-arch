#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_local_source_uses_checkout_even_when_ryoku_path_is_set() {
  local temp_dir project_dir bin_dir home_dir log_file expected_mount status

  temp_dir=$(mktemp -d)
  project_dir="$temp_dir/project"
  bin_dir="$temp_dir/bin"
  home_dir="$temp_dir/home"
  log_file="$temp_dir/docker-args.log"
  status=0

  mkdir -p "$project_dir/iso/bin" "$project_dir/iso/builder" "$project_dir/iso/configs" "$bin_dir" "$home_dir" "$temp_dir/stale"
  cp "$ROOT_DIR/iso/bin/ryoku-iso-make" "$project_dir/iso/bin/ryoku-iso-make"

  cat > "$bin_dir/docker" <<'EOF'
#!/bin/bash
set -euo pipefail

printf '%s\n' "$@" > "$DOCKER_ARGS_FILE"

for arg in "$@"; do
  if [[ $arg == *":/out/" ]]; then
    out_dir=${arg%%:/out/}
    mkdir -p "$out_dir"
    touch "$out_dir/test.iso"
    exit 0
  fi
done

echo "missing /out mount" >&2
exit 1
EOF

  cat > "$bin_dir/sudo" <<'EOF'
#!/bin/bash
exit 0
EOF

  chmod +x "$bin_dir/docker" "$bin_dir/sudo" "$project_dir/iso/bin/ryoku-iso-make"

  expected_mount="$project_dir:/ryoku:ro"

  PATH="$bin_dir:$PATH" \
    HOME="$home_dir" \
    RYOKU_PATH="$temp_dir/stale" \
    DOCKER_ARGS_FILE="$log_file" \
    "$project_dir/iso/bin/ryoku-iso-make" --local-source --no-boot-offer >/dev/null 2>&1 || status=$?

  if (( status != 0 )); then
    rm -rf "$temp_dir"
    fail "ryoku-iso-make should succeed under the test harness (status=$status)"
  fi

  if ! grep -F -- "$expected_mount" "$log_file" >/dev/null; then
    cat "$log_file" >&2
    rm -rf "$temp_dir"
    fail "--local-source should mount the current checkout instead of \$RYOKU_PATH"
  fi

  rm -rf "$temp_dir"
}

assert_local_source_uses_checkout_even_when_ryoku_path_is_set

echo "PASS: iso local-source path tests"
