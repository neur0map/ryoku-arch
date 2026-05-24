#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DOCTOR="$ROOT_DIR/bin/ryoku-doctor"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

grep -Fq 'last-medevac' "$DOCTOR" || \
  fail "ryoku-doctor should read MedEvac recovery provenance"
grep -Fq 'If doctor cannot start, update, or repair the install, run ryoku-call911now' "$DOCTOR" || \
  fail "ryoku-doctor help should point failed normal repairs to MedEvac"
grep -Fq 'Settings > About > Stuck?' "$DOCTOR" || \
  fail "ryoku-doctor help should mention the Settings MedEvac entrypoint"
grep -Fq 'Last MedEvac:' "$DOCTOR" || \
  fail "ryoku-doctor should expose the last MedEvac run in its context panel"
grep -Fq 'doctor_report_value "Last MedEvac"' "$DOCTOR" || \
  fail "ryoku-doctor report should include the last MedEvac run"
grep -Fq 'doctor_last_medevac_value()' "$DOCTOR" || \
  fail "ryoku-doctor should read individual MedEvac status fields"
grep -Fq 'doctor_status) doctor_status="$value"' "$DOCTOR" || \
  fail "ryoku-doctor should include MedEvac doctor status"
grep -Fq 'update_status) update_status="$value"' "$DOCTOR" || \
  fail "ryoku-doctor should include MedEvac updater status"
grep -Fq 'archive_mode) archive_mode="$value"' "$DOCTOR" || \
  fail "ryoku-doctor should include MedEvac archive fallback mode"
grep -Fq 'preserved_backups) preserved_backups="$value"' "$DOCTOR" || \
  fail "ryoku-doctor should include MedEvac preserved backup paths"
grep -Fq 'backups=%s' "$DOCTOR" || \
  fail "ryoku-doctor MedEvac summary should print preserved backup paths"
grep -Fq 'Last MedEvac doctor handoff exited with status' "$DOCTOR" || \
  fail "ryoku-doctor report should warn when MedEvac doctor handoff failed"
grep -Fq 'Last MedEvac updater handoff exited with status' "$DOCTOR" || \
  fail "ryoku-doctor report should warn when MedEvac updater handoff failed"

printf '%s\n' "PASS: ryoku-doctor medevac state"
