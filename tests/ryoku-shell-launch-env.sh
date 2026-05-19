#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
LAUNCHER="$ROOT_DIR/shell/scripts/ryoku-shell"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

extract_function() {
  local name="$1"

  awk -v name="$name" '
    $0 == name "() {" { capture = 1 }
    capture { print }
    capture && /^}/ { exit }
  ' "$LAUNCHER"
}

[[ -f $LAUNCHER ]] || fail "missing shell launcher"

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

mkdir -p "$tmp_dir/path" "$tmp_dir/ryoku/bin"

cat > "$tmp_dir/path/systemctl" <<'SH'
#!/bin/bash
if [[ $* == "--user show-environment" ]]; then
  printf '%s\n' \
    "PATH=/usr/local/sbin:/usr/local/bin:/usr/bin:/usr/bin/site_perl:/usr/bin/vendor_perl:/usr/bin/core_perl" \
    "XDG_SESSION_TYPE=wayland"
fi
SH
chmod +x "$tmp_dir/path/systemctl"

apply_gpu_policy() { :; }

eval "$(extract_function _get_systemd_user_env)"
eval "$(extract_function apply_qt_runtime_env)"

export HOME="$tmp_dir/home"
export RYOKU_PATH="$tmp_dir/ryoku"
export WAYLAND_DISPLAY="wayland-test"
export NIRI_SOCKET="$tmp_dir/niri.sock"
export PATH="$tmp_dir/path:$RYOKU_PATH/bin:/usr/local/sbin:/usr/local/bin:/usr/bin"

_cached_systemd_env=""
_cached_systemd_env_fetched=false

apply_qt_runtime_env

case ":$PATH:" in
  *":$RYOKU_PATH/bin:"*) ;;
  *) fail "session boot PATH merge should preserve RYOKU_PATH/bin for QML helper commands" ;;
esac

echo "PASS: ryoku-shell launch environment preserves helper PATH"
