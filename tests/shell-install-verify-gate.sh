#!/bin/bash

# Proves rsi_verify gates success on the critical artifacts. It must FAIL
# (non-zero) when /usr/bin/qs is owned by a non-quickshell fork (the noctalia-qs
# case that used to ship a black screen as "success"), PASS once the real
# quickshell and a Hyprland config are present, accept either hyprland.lua or a
# legacy hyprland.conf, and FAIL when no config entrypoint exists.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
# Fake pacman: `-Qoq /usr/bin/qs` reports $QS_OWNER (the package owning qs).
cat >"$tmp/bin/pacman" <<EOF
#!/bin/bash
[[ \${1:-} == -Qoq ]] && { printf '%s\n' "\${QS_OWNER:-}"; exit 0; }
exit 0
EOF
chmod +x "$tmp/bin/pacman"
export PATH="$tmp/bin:$PATH"

# Force every RSI path under the sandbox so the test never touches real config.
export HOME="$tmp/home"
mkdir -p "$HOME"
unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_BIN_HOME XDG_DATA_HOME
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/env.sh"
export RSI_SESSION_FILE="$tmp/ryoku.desktop"
export RYOKU_SHELL_QML_DIR="$tmp/qml"
export RSI_DRY_RUN=0
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/ui.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/deploy.sh"

# Lay down every artifact rsi_verify requires.
mkdir -p "$RSI_RYOKU_PATH/bin" "$RSI_BIN_HOME" "$RSI_QUICKSHELL_DIR" \
  "$RYOKU_SHELL_QML_DIR/Ryoku" "$RSI_CONFIG_HOME/hypr" "$RSI_CONFIG_HOME/systemd/user"
: >"$RSI_BIN_HOME/ryoku-shell"
: >"$RSI_QUICKSHELL_DIR/shell.qml"
: >"$RYOKU_SHELL_QML_DIR/Ryoku/libryokuplugin.so"
: >"$RSI_CONFIG_HOME/hypr/hyprland.lua"
: >"$RSI_CONFIG_HOME/systemd/user/ryoku-shell.service"
: >"$RSI_SESSION_FILE"

# --- A non-quickshell fork owns qs -> verify must FAIL despite every file present.
if QS_OWNER=noctalia-qs rsi_verify >/dev/null 2>&1; then
  fail "rsi_verify must fail when /usr/bin/qs is owned by a non-quickshell fork"
fi

# --- The real quickshell owns qs -> verify must PASS.
if ! QS_OWNER=quickshell rsi_verify >/dev/null 2>&1; then
  fail "rsi_verify must pass with the real quickshell and all artifacts present"
fi

# --- A legacy hyprland.conf (no .lua) is still a valid entrypoint.
rm -f "$RSI_CONFIG_HOME/hypr/hyprland.lua"
: >"$RSI_CONFIG_HOME/hypr/hyprland.conf"
if ! QS_OWNER=quickshell rsi_verify >/dev/null 2>&1; then
  fail "rsi_verify must accept a legacy hyprland.conf when hyprland.lua is absent"
fi

# --- No config entrypoint at all -> verify must FAIL.
rm -f "$RSI_CONFIG_HOME/hypr/hyprland.conf"
if QS_OWNER=quickshell rsi_verify >/dev/null 2>&1; then
  fail "rsi_verify must fail when no Hyprland config entrypoint exists"
fi

printf 'PASS: tests/shell-install-verify-gate.sh\n'
