#!/usr/bin/env bash
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repo="$here/../.."
work="$(mktemp -d)"
pid=""
cleanup() {
    if [[ -n $pid ]]; then kill "$pid" 2>/dev/null || true; fi
    rm -rf "$work"
}
trap cleanup EXIT

state="$work/state/ryoku/store"
views="$state/barstyle-views/obi"
mkdir -p "$state" "$views"
cp "$here/barstyles-live-probe.qml" "$work/probe.qml"

write_scene() {
    local version="$1"
    local marker="$2"
    local digest="$3"
    local product="$views/$digest"
    mkdir -p "$product"
    printf 'import QtQuick\nItem { property string marker: "%s" }\n' "$marker" >"$product/Child.qml"
    printf 'import QtQuick\nItem { Child { id: child } property string marker: child.marker }\n' \
        >"$product/Scene.qml"
}
write_index() {
    local version="$1"
    local digest="$2"
    printf '[{"id":"obi","version":"%s","scene":"Scene.qml","view":"barstyle-views/obi/%s"}]\n' \
        "$version" "$digest" >"$state/.barstyles.json.tmp"
    mv "$state/.barstyles.json.tmp" "$state/barstyles.json"
}
write_revision() {
    local revision="$1"
    printf '{"revision":%s,"category":"barstyles","id":"obi","version":"1.0.%s","operation":"update"}\n' \
        "$revision" "$revision" >"$state/.revision.json.tmp"
    mv "$state/.revision.json.tmp" "$state/revision.json"
}
wait_for() {
    local marker="$1"
    for _ in $(seq 1 200); do
        grep -q "$marker" "$work/log" 2>/dev/null && return 0
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.05
    done
    cat "$work/log" 2>/dev/null || true
    return 1
}

v1_digest="$(printf 'a%.0s' {1..64})"
v2_digest="$(printf 'b%.0s' {1..64})"
write_scene 1 v1 "$v1_digest"
write_index 1.0.1 "$v1_digest"
write_revision 1
XDG_STATE_HOME="$work/state" \
QML_IMPORT_PATH="$repo/ryoku/shell/quickshell:${QML_IMPORT_PATH:-$HOME/.local/lib/qt6/qml}" \
QT_QPA_PLATFORM=offscreen qs -p "$work/probe.qml" >"$work/log" 2>&1 &
pid=$!

wait_for 'BARSTYLE-MARKER:v1'
original_pid=$pid
write_scene 2 v2 "$v2_digest"
write_index 1.0.2 "$v2_digest"
write_revision 2
wait_for 'BARSTYLE-MARKER:v2'
[[ $pid == "$original_pid" ]] && kill -0 "$pid"

printf '[]\n' >"$state/.barstyles.json.tmp"
mv "$state/.barstyles.json.tmp" "$state/barstyles.json"
write_revision 3
wait_for 'BARSTYLE-SUMI'
[[ $pid == "$original_pid" ]] && kill -0 "$pid"

if grep -Eq '(^|[[:space:]])(ERROR|TypeError|ReferenceError)|Failed to load' "$work/log"; then
    cat "$work/log"
    exit 1
fi

echo "barstyles-live-probe: v1 -> v2 -> Sumi in pid $pid"
