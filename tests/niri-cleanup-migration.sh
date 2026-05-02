#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
MIGRATION="$ROOT_DIR/migrations/1777751965.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_cleanup_defers_without_success_outside_niri() {
  local temp_dir home_dir bin_dir status

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  bin_dir="$temp_dir/bin"
  status=0

  mkdir -p "$home_dir/.config/hypr" "$bin_dir" "$temp_dir/ryoku/default/alacritty" "$temp_dir/ryoku/default/ghostty"
  touch "$temp_dir/ryoku/default/alacritty/screensaver.toml"
  touch "$temp_dir/ryoku/default/ghostty/screensaver"

  cat > "$bin_dir/inir" <<'EOF'
#!/bin/bash
exit 0
EOF
  cat > "$bin_dir/niri" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$bin_dir/inir" "$bin_dir/niri"

  HOME="$home_dir" \
    PATH="$bin_dir:$PATH" \
    RYOKU_PATH="$temp_dir/ryoku" \
    XDG_CURRENT_DESKTOP=Hyprland \
    /bin/bash "$MIGRATION" >/dev/null 2>&1 || status=$?

  if (( status != 75 )); then
    rm -rf "$temp_dir"
    fail "cleanup migration should return defer exit 75 outside Niri"
  fi

  [[ -d $home_dir/.config/hypr ]] || {
    rm -rf "$temp_dir"
    fail "cleanup migration should not remove old config before Niri is active"
  }

  rm -rf "$temp_dir"
}

assert_ryoku_migrate_does_not_mark_deferred_cleanup() {
  local temp_dir home_dir bin_dir status state_dir

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  bin_dir="$temp_dir/bin"
  state_dir="$home_dir/.local/state/ryoku/migrations"
  status=0

  mkdir -p "$home_dir/.config/hypr" "$bin_dir" "$temp_dir/ryoku/default/alacritty" "$temp_dir/ryoku/default/ghostty"
  mkdir -p "$temp_dir/ryoku/migrations" "$temp_dir/ryoku/bin" "$temp_dir/ryoku/lib"
  touch "$temp_dir/ryoku/default/alacritty/screensaver.toml"
  touch "$temp_dir/ryoku/default/ghostty/screensaver"
  cp "$MIGRATION" "$temp_dir/ryoku/migrations/1777751965.sh"
  cp "$ROOT_DIR/bin/ryoku-migrate" "$temp_dir/ryoku/bin/ryoku-migrate"
  cp "$ROOT_DIR/lib/runtime-env.sh" "$temp_dir/ryoku/lib/runtime-env.sh"

  cat > "$bin_dir/inir" <<'EOF'
#!/bin/bash
exit 0
EOF
  cat > "$bin_dir/niri" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$bin_dir/inir" "$bin_dir/niri" "$temp_dir/ryoku/bin/ryoku-migrate"

  HOME="$home_dir" \
    PATH="$bin_dir:$PATH" \
    RYOKU_PATH="$temp_dir/ryoku" \
    XDG_CURRENT_DESKTOP=Hyprland \
    /bin/bash "$temp_dir/ryoku/bin/ryoku-migrate" >/dev/null 2>&1 || status=$?

  if (( status != 0 )); then
    rm -rf "$temp_dir"
    fail "ryoku-migrate should continue after a deferred cleanup migration"
  fi

  [[ ! -e $state_dir/1777751965.sh ]] || {
    rm -rf "$temp_dir"
    fail "ryoku-migrate should not mark deferred cleanup as applied"
  }
  [[ ! -e $state_dir/skipped/1777751965.sh ]] || {
    rm -rf "$temp_dir"
    fail "ryoku-migrate should not mark deferred cleanup as skipped"
  }

  rm -rf "$temp_dir"
}

assert_cleanup_runs_in_niri() {
  local temp_dir home_dir bin_dir

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  bin_dir="$temp_dir/bin"

  mkdir -p "$home_dir/.config/hypr" "$bin_dir" "$temp_dir/ryoku/default/alacritty" "$temp_dir/ryoku/default/ghostty"
  printf 'screen\n' > "$temp_dir/ryoku/default/alacritty/screensaver.toml"
  printf 'ghost\n' > "$temp_dir/ryoku/default/ghostty/screensaver"

  cat > "$bin_dir/inir" <<'EOF'
#!/bin/bash
exit 0
EOF
  cat > "$bin_dir/niri" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$bin_dir/inir" "$bin_dir/niri"

  HOME="$home_dir" \
    PATH="$bin_dir:$PATH" \
    RYOKU_PATH="$temp_dir/ryoku" \
    XDG_CURRENT_DESKTOP=niri \
    /bin/bash "$MIGRATION" >/dev/null

  [[ ! -e $home_dir/.config/hypr ]] || {
    rm -rf "$temp_dir"
    fail "cleanup migration should remove old Hypr config in Niri"
  }

  grep -qxF 'screen' "$home_dir/.local/share/ryoku/default/alacritty/screensaver.toml" \
    || fail "cleanup migration should preserve Alacritty screensaver"
  grep -qxF 'ghost' "$home_dir/.local/share/ryoku/default/ghostty/screensaver" \
    || fail "cleanup migration should preserve Ghostty screensaver"

  rm -rf "$temp_dir"
}

assert_cleanup_defers_without_success_outside_niri
assert_cleanup_runs_in_niri
assert_ryoku_migrate_does_not_mark_deferred_cleanup

echo "PASS: Niri cleanup migration tests"
