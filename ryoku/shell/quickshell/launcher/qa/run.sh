#!/usr/bin/env bash
# Launcher QA runner: drives the live launcher over its command socket and
# synthesized keyboard input (wtype), snapshots `state` JSON, screenshots each
# scenario, and evaluates jq assertions. One scenario at a time: they share
# the single resident launcher.
#
# Usage: run.sh [scenarios.json] [only-ids-comma-separated]
# Evidence: $QA_OUT (default /tmp/launcher-qa)/run-<stamp>/<id>/
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SOCK="${XDG_RUNTIME_DIR}/ryoku-launcher.sock"
SUITE="${1:-$HERE/scenarios.json}"
ONLY="${2:-}"
RUN="run-$(date +%Y%m%d-%H%M%S)"
OUT="${QA_OUT:-/tmp/launcher-qa}/$RUN"
mkdir -p "$OUT"

sock() { (printf '%s\n' "$1"; sleep 0.35) | socat - UNIX-CONNECT:"$SOCK"; }

settle() { # wait for async providers to go quiet, max $1 seconds (default 8)
    local max="${1:-8}"
    for _ in $(seq $((max * 2))); do
        [ "$(sock state | jq -r '(.busy or .searching) // false')" = "false" ] && return 0
        sleep 0.5
    done
    return 0
}

run_step() {
    local step="$1"
    case "$step" in
    show) sock show >/dev/null; sleep 0.6 ;;
    hide) sock hide >/dev/null; sleep 0.4 ;;
    "type "*) wtype -- "${step#type }"; sleep 0.45 ;;
    "key "*) local k; for k in ${step#key }; do wtype -k "$k"; sleep 0.2; done ;;
    "ctrl "*) wtype -M ctrl -k "${step#ctrl }" -m ctrl; sleep 0.3 ;;
    "sleep "*) sleep "${step#sleep }" ;;
    settle) settle ;;
    "settle "*) settle "${step#settle }" ;;
    "sh "*) bash -c "${step#sh }" ;;
    *) echo "unknown step: $step" >&2; return 1 ;;
    esac
}

pass=0; fail=0; block=0
: >"$OUT/results.tsv"

while IFS= read -r sc; do
    id=$(jq -r .id <<<"$sc")
    name=$(jq -r .name <<<"$sc")
    if [ -n "$ONLY" ] && ! [[ ",$ONLY," == *",$id,"* ]]; then continue; fi
    dir="$OUT/$id"
    mkdir -p "$dir"
    printf '%s' "$sc" >"$dir/scenario.json"

    # uniform initial conditions: closed, settled
    sock hide >/dev/null
    sleep 0.5

    verdict=PASS reason=""
    while IFS= read -r step; do
        echo "STEP: $step" >>"$dir/steps.log"
        run_step "$step" >>"$dir/steps.log" 2>&1 ||
            { verdict=FAIL reason="step failed: $step"; break; }
    done < <(jq -r '.steps[]' <<<"$sc")

    sock state >"$dir/state.json"
    grim "$dir/screen.png" 2>>"$dir/steps.log" || true

    if [ "$verdict" = PASS ]; then
        while IFS= read -r a; do
            r=$(jq -r "$a" "$dir/state.json" 2>&1)
            [ "$r" = "true" ] ||
                { verdict=FAIL reason="assert: $a => $r"; break; }
        done < <(jq -r '.asserts[]?' <<<"$sc")
    fi
    if [ "$verdict" = PASS ]; then
        while IFS= read -r a; do
            out=$(bash -c "$a" 2>&1) ||
                { verdict=FAIL reason="shell assert: $a => $out"; break; }
        done < <(jq -r '.shell_asserts[]?' <<<"$sc")
    fi

    # per-scenario teardown always runs (close spawned windows, clear clipboard)
    while IFS= read -r t; do
        bash -c "$t" >>"$dir/steps.log" 2>&1 || true
    done < <(jq -r '.teardown[]?' <<<"$sc")

    sock hide >/dev/null
    sleep 0.3
    # scenarios blocked on a defect outside the launcher (documented in the
    # scenario's "blocked" field) report as BLOCKED, visible but not failing.
    blocked=$(jq -r '.blocked // empty' <<<"$sc")
    if [ "$verdict" = FAIL ] && [ -n "$blocked" ]; then
        verdict=BLOCKED reason="$blocked"
    fi
    case "$verdict" in
    PASS) pass=$((pass + 1)) ;;
    BLOCKED) block=$((block + 1)) ;;
    *) fail=$((fail + 1)) ;;
    esac
    printf '%s\t%s\t%s\t%s\n' "$id" "$verdict" "$name" "$reason" |
        tee -a "$OUT/results.tsv"
done < <(jq -c '.scenarios[]' "$SUITE")

echo "----"
echo "PASS $pass FAIL $fail BLOCKED $block  evidence: $OUT"
[ "$fail" -eq 0 ]
