#!/bin/bash

# Verifies the laptop-aware suspend-then-hibernate wiring:
#   - ryoku-hw-laptop reports laptop vs desktop from chassis type / overrides
#   - ryoku-hibernation-setup --write-sth-config writes the logind + sleep
#     drop-ins (laptop), only the sleep delay (desktop), and nothing when the
#     machine has no usable hibernate image
#   - the migration that backfills existing installs is gated on a real resume hook

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# Exercise the code under test, not whatever is installed at ~/.local/share/ryoku.
export RYOKU_PATH="$ROOT_DIR"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

hib="$ROOT_DIR/bin/ryoku-hibernation-setup"
hwlap="$ROOT_DIR/bin/ryoku-hw-laptop"

bash -n "$hwlap" || fail "ryoku-hw-laptop has a syntax error"
bash -n "$hib" || fail "ryoku-hibernation-setup has a syntax error"

# --- ryoku-hw-laptop -------------------------------------------------------
RYOKU_ASSUME_LAPTOP=1 bash "$hwlap" || fail "RYOKU_ASSUME_LAPTOP=1 should report laptop (exit 0)"
RYOKU_ASSUME_LAPTOP=0 bash "$hwlap" && fail "RYOKU_ASSUME_LAPTOP=0 should report desktop (exit 1)" || true

chassis="$(mktemp)"
printf '10\n' >"$chassis"  # Notebook
RYOKU_CHASSIS_TYPE_FILE="$chassis" bash "$hwlap" || fail "chassis type 10 (Notebook) should be a laptop"
printf '3\n' >"$chassis"   # Desktop
RYOKU_CHASSIS_TYPE_FILE="$chassis" bash "$hwlap" && fail "chassis type 3 (Desktop) should not be a laptop" || true
rm -f "$chassis"

# --- ryoku-hibernation-setup --write-sth-config (laptop) -------------------
pref="$(mktemp -d)"
RYOKU_ETC_PREFIX="$pref" RYOKU_ASSUME_HIBERNATION_READY=1 RYOKU_ASSUME_LAPTOP=1 \
  RYOKU_HIBERNATE_DELAY_SEC=50min bash "$hib" --write-sth-config >/dev/null

sleep_conf="$pref/etc/systemd/sleep.conf.d/10-ryoku-hibernate-delay.conf"
logind_conf="$pref/etc/systemd/logind.conf.d/10-ryoku-lid.conf"
[[ -f $sleep_conf ]] || fail "laptop: missing sleep.conf.d HibernateDelaySec drop-in"
[[ -f $logind_conf ]] || fail "laptop: missing logind.conf.d lid drop-in"
grep -q '^HibernateDelaySec=50min$' "$sleep_conf" || fail "laptop: HibernateDelaySec not written"
grep -q '^HandleLidSwitch=suspend-then-hibernate$' "$logind_conf" || fail "laptop: HandleLidSwitch not set to suspend-then-hibernate"
grep -q '^HandleSuspendKey=suspend-then-hibernate$' "$logind_conf" || fail "laptop: HandleSuspendKey not set"
rm -rf "$pref"

# --- desktop: sleep delay only, never a lid override -----------------------
pref="$(mktemp -d)"
RYOKU_ETC_PREFIX="$pref" RYOKU_ASSUME_HIBERNATION_READY=1 RYOKU_ASSUME_LAPTOP=0 \
  bash "$hib" --write-sth-config >/dev/null
[[ -f "$pref/etc/systemd/sleep.conf.d/10-ryoku-hibernate-delay.conf" ]] \
  || fail "desktop: missing sleep delay drop-in"
[[ -f "$pref/etc/systemd/logind.conf.d/10-ryoku-lid.conf" ]] \
  && fail "desktop: must NOT write a lid suspend override" || true
rm -rf "$pref"

# --- no usable hibernate image: write nothing ------------------------------
pref="$(mktemp -d)"
RYOKU_ETC_PREFIX="$pref" RYOKU_ASSUME_HIBERNATION_READY=0 RYOKU_ASSUME_LAPTOP=1 \
  bash "$hib" --write-sth-config >/dev/null
(( $(find "$pref" -type f | wc -l) == 0 )) \
  || fail "not hibernation-ready: must not write any drop-ins"
rm -rf "$pref"

# --- migration backfill is gated on a real resume hook ---------------------
migration="$ROOT_DIR/migrations/1781066122.sh"
[[ -f $migration ]] || fail "missing suspend-then-hibernate backfill migration"
bash -n "$migration" || fail "migration has a syntax error"
grep -q 'ryoku_resume.conf' "$migration" || fail "migration must gate on the ryoku_resume.conf hook"
grep -q 'write-sth-config' "$migration" || fail "migration must call ryoku-hibernation-setup --write-sth-config"

printf 'PASS: tests/suspend-then-hibernate-wiring.sh\n'
