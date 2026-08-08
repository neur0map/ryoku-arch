#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
extras="${RYOKU_EXTRAS_ROOT:-$repo/../ryoku-extras-catalogue}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

for style in nacre obi; do
    log="$work/$style.log"
    scene="file://$extras/barstyles/$style/Scene.qml?v=1.0.0"
    BARSTYLE_ID="$style" BARSTYLE_SCENE="$scene" \
    QML_IMPORT_PATH="$repo/ryoku/shell/quickshell:${QML_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
    QT_QPA_PLATFORM=wayland timeout 15 qs -p "$here/barstyles-package-probe.qml" >"$log" 2>&1 || true
    if ! grep -q "BARSTYLE-PACKAGE-PROBE-PASS:$style" "$log"; then
        cat "$log"
        exit 1
    fi
    if grep -Eq '(^|[[:space:]])(ERROR|TypeError|ReferenceError)|Failed to load' "$log"; then
        cat "$log"
        exit 1
    fi
done

echo "barstyles-package-probe: Nacre and Obi load from external product roots"
