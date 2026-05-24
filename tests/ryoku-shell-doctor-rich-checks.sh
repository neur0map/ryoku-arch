#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SHELL_DOCTOR="$ROOT_DIR/shell/scripts/ryoku-shell-doctor"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -f $SHELL_DOCTOR ]] || fail "missing shell doctor"

check_count="$(grep -c 'run_check "' "$SHELL_DOCTOR")"
(( check_count >= 24 )) || \
  fail "shell doctor should expose at least 24 visible health checks; found $check_count"

for label in \
  "dependencies" \
  "command bridges" \
  "runtime-env bridge" \
  "MedEvac command" \
  "update status" \
  "snapshot tooling" \
  "state directories" \
  "script permissions" \
  "shell source pointer" \
  "portal services" \
  "clipboard stack" \
  "screenshot stack" \
  "audio controls"; do
  grep -Fq "run_check \"$label\"" "$SHELL_DOCTOR" || \
    fail "shell doctor should include visible check: $label"
done

grep -Fq '[${doctor_step}/${doctor_total}]' "$SHELL_DOCTOR" || \
  fail "shell doctor should render numbered TUI progress for the check deck"
grep -Fq 'Doctor flight deck' "$SHELL_DOCTOR" || \
  fail "shell doctor should have a richer TUI title"
grep -Fq 'load_hyprland_env_from_quickshell' "$SHELL_DOCTOR" || \
  fail "shell doctor should recover Hyprland env from the running shell before hyprctl checks"
grep -Fq '/proc/$pid/environ' "$SHELL_DOCTOR" || \
  fail "shell doctor should inspect the running shell process environment for SSH-safe compositor checks"

echo "PASS: ryoku shell doctor exposes rich multi-check TUI"
