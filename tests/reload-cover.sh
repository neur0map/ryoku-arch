#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
live_runtime="${XDG_RUNTIME_DIR:-}"
reload_pid=""

cleanup() {
    local status="$1" token
    if [[ -n $reload_pid ]] && kill -0 "$reload_pid" 2>/dev/null; then
        wait "$reload_pid" 2>/dev/null || true
    fi
    if [[ -n $live_runtime && -e "$live_runtime/ryoku-reload-cover.json" ]]; then
        token=$(env XDG_RUNTIME_DIR="$live_runtime" jq -r '.token // empty' "$live_runtime/ryoku-reload-cover.json" 2>/dev/null || true)
        [[ $token =~ ^[0-9a-f]{32}$ ]] && env XDG_RUNTIME_DIR="$live_runtime" ryoku-reload-cover finish "$token" >/dev/null 2>&1 || true
    fi
    rm -rf "$tmp"
    trap - EXIT
    exit "$status"
}
trap 'cleanup $?' EXIT

export XDG_RUNTIME_DIR="$tmp/runtime"
mkdir -p "$XDG_RUNTIME_DIR"
cover="$root/ryoku/shell/scripts/ryoku-reload-cover"

token=$(RYOKU_RELOAD_COVER_TEST=1 "$cover" begin)
test -n "$token"
test "$(stat -c %a "$XDG_RUNTIME_DIR/ryoku-reload-cover.json")" = 600
test "$(jq -r .token "$XDG_RUNTIME_DIR/ryoku-reload-cover.json")" = "$token"
test "$(jq -r .pid "$XDG_RUNTIME_DIR/ryoku-reload-cover.json")" -gt 0
test -n "$(jq -r .pidStart "$XDG_RUNTIME_DIR/ryoku-reload-cover.json")"
RYOKU_RELOAD_COVER_TEST=1 "$cover" finish wrong-token
test "$(jq -r .token "$XDG_RUNTIME_DIR/ryoku-reload-cover.json")" = "$token"
RYOKU_RELOAD_COVER_TEST=1 "$cover" finish "$token"
test ! -e "$XDG_RUNTIME_DIR/ryoku-reload-cover.json"

for out in "$tmp/a" "$tmp/b"; do
    (RYOKU_RELOAD_COVER_TEST=1 "$cover" begin >"$out" 2>/dev/null) &
done
wait || true
test "$(awk 'NF { n++ } END { print n + 0 }' "$tmp/a" "$tmp/b")" = 1
token=$(jq -r .token "$XDG_RUNTIME_DIR/ryoku-reload-cover.json")
RYOKU_RELOAD_COVER_TEST=1 "$cover" finish "$token"

echo "reload cover launcher: PASS"

if [[ ${RYOKU_RELOAD_COVER_LIVE:-0} == 1 ]]; then
    [[ -n $live_runtime ]] || { echo "missing live runtime" >&2; exit 1; }
    env XDG_RUNTIME_DIR="$live_runtime" ryoku-shell reload >"$tmp/reload.log" 2>&1 &
    reload_pid=$!
    seen=0
    for _ in $(seq 1 200); do
        if env XDG_RUNTIME_DIR="$live_runtime" hyprctl layers -j | grep -q '"ryoku-reload-cover"'; then
            seen=1
            break
        fi
        sleep 0.05
    done
    test "$seen" = 1

    delay=0
    for mark in 0 100 300 700 1200; do
        sleep "$delay"
        env XDG_RUNTIME_DIR="$live_runtime" grim "$tmp/reload-cover-$mark.png"
        delay=$(awk "BEGIN { print ($mark == 0 ? 0.1 : $mark == 100 ? 0.2 : $mark == 300 ? 0.4 : 0.5) }")
    done

    magick montage "$tmp"/reload-cover-*.png -thumbnail 560x -tile 3x2 -geometry +4+4 /tmp/ryoku-reload-cover-montage.png

    for _ in $(seq 1 240); do
        kill -0 "$reload_pid" 2>/dev/null || break
        sleep 0.05
    done
    if kill -0 "$reload_pid" 2>/dev/null; then
        echo "reload did not complete" >&2
        exit 1
    fi
    wait "$reload_pid"
    reload_pid=""
    cleared=0
    for _ in $(seq 1 60); do
        if ! env XDG_RUNTIME_DIR="$live_runtime" hyprctl layers -j | grep -q '"ryoku-reload-cover"'; then
            cleared=1
            break
        fi
        sleep 0.05
    done
    if [[ $cleared != 1 ]]; then
        echo "reload cover remained after finish" >&2
        exit 1
    fi
    if [[ ${RYOKU_RELOAD_COVER_WATCHDOG:-0} == 1 ]]; then
        token=$(env XDG_RUNTIME_DIR="$live_runtime" ryoku-reload-cover begin)
        sleep 15.2
        phase=$(env XDG_RUNTIME_DIR="$live_runtime" qs -p "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/reload-cover" ipc call reload-cover status "$token")
        test "$phase" = failed
        env XDG_RUNTIME_DIR="$live_runtime" hyprctl layers -j | grep -q '"ryoku-reload-cover"'
        sleep 2.3
        if env XDG_RUNTIME_DIR="$live_runtime" hyprctl layers -j | grep -q '"ryoku-reload-cover"'; then
            echo "failed cover did not release" >&2
            exit 1
        fi
        test ! -e "$live_runtime/ryoku-reload-cover.json"
    fi
    echo "reload cover live: PASS (/tmp/ryoku-reload-cover-montage.png)"
fi
