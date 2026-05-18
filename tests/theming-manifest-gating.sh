#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
tmp_dir="$(mktemp -d)"
test_home="$tmp_dir/u"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

mkdir -p "$test_home/.config/ryoku-shell" \
  "$tmp_dir/state" \
  "$tmp_dir/scripts/colors/lib" \
  "$tmp_dir/scripts/colors/modules" \
  "$tmp_dir/scripts/colors/targets" \
  "$tmp_dir/scripts/lib"

cp "$ROOT_DIR/shell/scripts/colors/applycolor.sh" "$tmp_dir/scripts/colors/applycolor.sh"
cp "$ROOT_DIR/shell/scripts/colors/lib/module-runtime.sh" "$tmp_dir/scripts/colors/lib/module-runtime.sh"

cat > "$tmp_dir/scripts/lib/config-path.sh" <<'EOF'
#!/bin/bash
ryoku_shell_config_file() {
  printf '%s\n' "$XDG_CONFIG_HOME/ryoku-shell/config.json"
}
EOF

cat > "$tmp_dir/scripts/colors/modules/10-enabled.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'enabled\n' >> "$THEMING_TEST_LOG"
EOF

cat > "$tmp_dir/scripts/colors/modules/20-disabled.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
printf 'disabled\n' >> "$THEMING_TEST_LOG"
EOF

chmod +x "$tmp_dir/scripts/colors/applycolor.sh" \
  "$tmp_dir/scripts/colors/lib/module-runtime.sh" \
  "$tmp_dir/scripts/colors/modules/10-enabled.sh" \
  "$tmp_dir/scripts/colors/modules/20-disabled.sh"

cat > "$tmp_dir/scripts/colors/targets/enabled.json" <<'JSON'
{
  "id": "enabled",
  "label": "Enabled",
  "module": "10-enabled.sh",
  "configKey": "appearance.wallpaperTheming.enableEnabled"
}
JSON

cat > "$tmp_dir/scripts/colors/targets/disabled.json" <<'JSON'
{
  "id": "disabled",
  "label": "Disabled",
  "module": "20-disabled.sh",
  "configKey": "appearance.wallpaperTheming.enableDisabled"
}
JSON

cat > "$test_home/.config/ryoku-shell/config.json" <<'JSON'
{
  "appearance": {
    "wallpaperTheming": {
      "enableEnabled": true,
      "enableDisabled": false
    }
  }
}
JSON

export HOME="$test_home"
export XDG_CONFIG_HOME="$test_home/.config"
export XDG_CACHE_HOME="$tmp_dir/cache"
export XDG_STATE_HOME="$tmp_dir/state"
export THEMING_TEST_LOG="$tmp_dir/theming.log"
export RYOKU_THEME_MAX_JOBS=2

"$tmp_dir/scripts/colors/applycolor.sh"

[[ -f $THEMING_TEST_LOG ]] || fail "enabled module did not run"
grep -Fxq "enabled" "$THEMING_TEST_LOG" || fail "enabled module missing from run log"
! grep -Fxq "disabled" "$THEMING_TEST_LOG" || fail "disabled manifest module should not run"

cat > "$test_home/.config/ryoku-shell/config.json" <<'JSON'
{
  "appearance": {
    "wallpaperTheming": {
      "enableEnabled": false,
      "enableDisabled": false
    }
  }
}
JSON

rm -f "$THEMING_TEST_LOG"
"$tmp_dir/scripts/colors/applycolor.sh" 2> "$tmp_dir/no-enabled.err"

[[ ! -f $THEMING_TEST_LOG ]] || fail "no modules should run when every target is disabled"
grep -Fq "No enabled theming targets found" "$tmp_dir/no-enabled.err" \
  || fail "all-disabled run should report no enabled targets"

echo "PASS: theming manifest gates disabled targets"
