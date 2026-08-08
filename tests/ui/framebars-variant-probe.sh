#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/imports/Ryoku" "$work/config/ryoku"
ln -s "$repo/ryoku/shell/framebars" "$work/imports/Ryoku/FrameBars"

# A minimal store whose left rail diverges from every default, so a config
# that silently falls back to the defaults cannot pass.
cat >"$work/config/ryoku/shell.json" <<'EOF'
{
  "frameBars": {
    "version": 1,
    "rails": {
      "left": { "enabled": true, "size": 48, "reveal": true, "top": [], "center": [], "bottom": ["clock"] }
    }
  }
}
EOF

XDG_CONFIG_HOME="$work/config" QT_QPA_PLATFORM=offscreen \
    QML2_IMPORT_PATH="$work/imports:${QML2_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
    timeout 20 qs -p "$here/framebars-variant-probe.qml" >"$work/log" 2>&1 || true
grep -q VARIANT-PROBE-PASS "$work/log" || { sed -n '1,80p' "$work/log"; exit 1; }
echo "framebars-variant-probe: adapter configs survive the module boundary"
