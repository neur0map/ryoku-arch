#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Ryoku"
ln -s "$repo/ryoku/ui" "$work/Ryoku/Ui"

QT_QPA_PLATFORM=offscreen QML2_IMPORT_PATH="$work:${QML2_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" timeout 20 qs -p "$here/bar-studio-keyboard-probe.qml" >"$work/log" 2>&1 || true
grep -q KEYBOARD-PROBE-PASS "$work/log" || { sed -n '1,80p' "$work/log"; exit 1; }
echo "bar-studio-keyboard-probe: controls accept keyboard activation"
