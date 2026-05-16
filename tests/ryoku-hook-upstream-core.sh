#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq -- "$pattern" "$file" || fail "$message"
}

assert_executable() {
  local path="$1"

  [[ -x $path ]] || fail "$path should be executable"
}

tmp_dir=$(mktemp -d)
export RYOKU_CONFIG_PATH="$tmp_dir/config"
mkdir -p "$RYOKU_CONFIG_PATH/hooks/post-update.d"

cat >"$RYOKU_CONFIG_PATH/hooks/post-update" <<'EOF'
#!/bin/bash
printf 'legacy:%s\n' "$1" >>"$RYOKU_TEST_HOOK_LOG"
exit 7
EOF

cat >"$RYOKU_CONFIG_PATH/hooks/post-update.d/10-first" <<'EOF'
#!/bin/bash
printf 'first:%s\n' "$1" >>"$RYOKU_TEST_HOOK_LOG"
EOF

cat >"$RYOKU_CONFIG_PATH/hooks/post-update.d/20-failing" <<'EOF'
#!/bin/bash
printf 'failing:%s\n' "$1" >>"$RYOKU_TEST_HOOK_LOG"
exit 9
EOF

cat >"$RYOKU_CONFIG_PATH/hooks/post-update.d/30-after" <<'EOF'
#!/bin/bash
printf 'after:%s\n' "$1" >>"$RYOKU_TEST_HOOK_LOG"
EOF

cat >"$RYOKU_CONFIG_PATH/hooks/post-update.d/40-sample.sample" <<'EOF'
#!/bin/bash
printf 'sample:%s\n' "$1" >>"$RYOKU_TEST_HOOK_LOG"
EOF

chmod 755 "$RYOKU_CONFIG_PATH/hooks/post-update" "$RYOKU_CONFIG_PATH/hooks/post-update.d/"*

RYOKU_TEST_HOOK_LOG="$tmp_dir/hooks.log" \
  "$ROOT_DIR/bin/ryoku-hook" post-update value >"$tmp_dir/hook.out"

grep -qx 'legacy:value' "$tmp_dir/hooks.log" || \
  fail "ryoku-hook should keep running legacy single-file hooks"
grep -qx 'first:value' "$tmp_dir/hooks.log" || \
  fail "ryoku-hook should run hooks from hook.d directories"
grep -qx 'failing:value' "$tmp_dir/hooks.log" || \
  fail "ryoku-hook should execute failing hooks"
grep -qx 'after:value' "$tmp_dir/hooks.log" || \
  fail "ryoku-hook should continue after a failing hook"
if grep -qx 'sample:value' "$tmp_dir/hooks.log"; then
  fail "ryoku-hook should skip .sample files"
fi
assert_contains "$tmp_dir/hook.out" 'Hook failed: .*post-update' \
  "ryoku-hook should report failed hooks without aborting"

cat >"$tmp_dir/new-hook" <<'EOF'
#!/bin/bash
printf 'installed\n'
EOF

"$ROOT_DIR/bin/ryoku-hook-install" theme-set "$tmp_dir/new-hook" >"$tmp_dir/install.out"

installed_hook="$RYOKU_CONFIG_PATH/hooks/theme-set.d/new-hook"
assert_executable "$installed_hook"
assert_contains "$tmp_dir/install.out" 'Installed theme-set hook:' \
  "ryoku-hook-install should report the installed hook path"

assert_executable bin/ryoku-hook-install
assert_contains bin/ryoku-hook 'HOOK_DIR="\$HOOK_PATH\.d"' \
  "ryoku-hook should look for hook.d directories"
assert_contains bin/ryoku-hook '\[\[ \$hook == \*\.sample \]\]' \
  "ryoku-hook should skip sample hooks"

bash -n bin/ryoku-hook bin/ryoku-hook-install tests/ryoku-hook-upstream-core.sh

echo "PASS: Ryoku hook upstream core parity"
