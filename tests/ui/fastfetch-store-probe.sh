#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/Ryoku" "$work/ryoku/hub"
ln -s "$repo/ryoku/ui" "$work/Ryoku/Ui"
cp -a "$repo/ryoku/hub/quickshell" "$work/ryoku/hub"
cp "$here/fastfetch-store-probe.qml" "$work/ryoku/probe.qml"

QML2_IMPORT_PATH="$work:${QML2_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
    QT_QPA_PLATFORM=offscreen timeout 20 qs -p "$work/ryoku/probe.qml" >"$work/log" 2>&1 || true
grep -q FASTFETCH-STORE-PROBE-PASS "$work/log" || { sed -n '1,120p' "$work/log"; exit 1; }
grep -Eq ' ERROR|TypeError|ReferenceError' "$work/log" && { sed -n '1,120p' "$work/log"; exit 1; }
echo "fastfetch-store-probe: installed style picker loads"
