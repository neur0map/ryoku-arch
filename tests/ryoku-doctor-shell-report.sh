#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_BIN_HOME="$HOME/.local/bin"

mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_BIN_HOME"

tui_success() { echo "OK: $*"; }
tui_error() { echo "ERR: $*"; }
tui_warn() { echo "WARN: $*"; }
tui_info() { echo "INFO: $*"; }
tui_step() { echo "STEP: $*"; }
tui_step_start() { echo "START: $*"; }
tui_step_done() { echo "DONE: $*"; }
tui_step_fail() { echo "STEPFAIL: $*"; }
tui_step_warn() { echo "STEPWARN: $*"; }
tui_divider() { echo "---"; }
tui_title() { echo "$*"; }
tui_badge_row() { echo "BADGES: $*"; }
tui_elapsed() { echo "0s"; }
tui_confirm() { return 1; }

source "$ROOT_DIR/shell/sdata/lib/doctor.sh"

ask=false
current_user="$(id -un)"
current_host="$(hostname 2>/dev/null || true)"

check_dependencies() { doctor_pass "dependency pass for $HOME $current_user $current_host"; }
check_fonts() { doctor_pass "fonts are fine"; }
check_repo_checkout_state() { doctor_fail "repo issue at $HOME/source for $current_user on $current_host"; }
check_updater_bootstrap_health() { doctor_fix "refreshed $HOME/.local/bin/ryoku-shell"; }
check_critical_files() { doctor_pass "critical files present"; }
check_script_permissions() { doctor_pass "script permissions OK"; }
check_launcher_health() { doctor_pass "launcher current"; }
check_user_config() { doctor_pass "user config valid"; }
check_state_directories() { doctor_pass "state directories exist"; }
check_version_tracking() { doctor_pass "version tracking OK"; }
check_manifest() { doctor_pass "file manifest OK"; }
check_service_unit_health() { doctor_pass "user service file present"; }
check_niri_running() { doctor_pass "niri running"; }
check_python_packages() { doctor_pass "python packages OK"; }
check_quickshell_abi() { doctor_pass "quickshell ABI OK"; }
check_quickshell_loads() { doctor_pass "quickshell running"; }
check_matugen_colors() { doctor_pass "theme colors generated"; }
check_qt_theming() { doctor_pass "qt theming OK"; }
check_conflicting_services() { doctor_pass "no conflicting services"; }
check_conflicting_shells() { doctor_pass "no conflicting shells"; }
check_wallpaper_health() { doctor_pass "wallpapers healthy"; }
check_environment_vars() { doctor_pass "environment variables OK"; }
check_niri_config() { doctor_pass "niri config valid"; }

set +e
output=$(TMPDIR="$tmp" run_doctor_with_fixes 2>&1)
status=$?
set -e

(( status != 0 )) || fail "doctor should return nonzero when a mocked issue is present"

grep -Fq 'START: 1 23 Checking dependencies' <<<"$output" \
  || fail "doctor should use the buffered step runner"
grep -Fq 'Checking updater bootstrap' <<<"$output" \
  || fail "doctor should keep the Ryoku updater-bootstrap check"
grep -Fq 'Doctor report:' <<<"$output" \
  || fail "doctor should print the generated report path"

report_path="$(sed -n 's/.*Doctor report: //p' <<<"$output" | tail -1)"
[[ -f $report_path ]] || fail "doctor report should exist at the printed path"
[[ $report_path == "$tmp"/ryoku-doctor-report.*/report.txt ]] \
  || fail "doctor report should be written under TMPDIR with a ryoku-doctor-report prefix"

grep -Fq 'FAIL repo issue' "$report_path" \
  || fail "doctor report should include failures"
grep -Fq 'FIX refreshed' "$report_path" \
  || fail "doctor report should include automatic fixes"
grep -Fq 'fonts are fine' "$report_path" \
  && fail "doctor report should not include passing checks"
grep -Fq "$HOME" "$report_path" \
  && fail "doctor report should anonymize the home path"
[[ -n $current_user ]] && grep -Fq "$current_user" "$report_path" \
  && fail "doctor report should anonymize the username"
[[ -n $current_host ]] && grep -Fq "$current_host" "$report_path" \
  && fail "doctor report should anonymize the hostname"

echo "PASS: ryoku shell doctor writes an anonymous issue report"
