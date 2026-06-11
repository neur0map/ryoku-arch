#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

make_env() { # tmp_dir
  local tmp="$1"
  mkdir -p "$tmp/drm/card0/device" "$tmp/drm/card1/device" "$tmp/cpufreq/policy0" "$tmp/state" "$tmp/bin"
  printf 'auto\n' >"$tmp/drm/card0/device/power_dpm_force_performance_level"
  # card1 has no dpm knob (e.g. NVIDIA card driven by the proprietary driver)
  printf '0\n' >"$tmp/cpufreq/boost"
  printf '0\n' >"$tmp/cpufreq/policy0/boost"

  cat >"$tmp/bin/nvidia-smi" <<'EOF'
#!/bin/bash
printf 'nvidia-smi:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
if [[ $* == *clocks.max.graphics* ]]; then printf '2370\n'; fi
EOF
  chmod 755 "$tmp/bin/nvidia-smi"
  : >"$tmp/events"
}

run_helper() { # tmp_dir args...
  local tmp="$1"
  shift
  RYOKU_TEST_EVENTS="$tmp/events" \
  RYOKU_GAMEMODE_DRM_ROOT="$tmp/drm" \
  RYOKU_GAMEMODE_CPUFREQ_ROOT="$tmp/cpufreq" \
  RYOKU_GAMEMODE_STATE_DIR="$tmp/state" \
  RYOKU_GAMEMODE_NVIDIA_SMI="$tmp/bin/nvidia-smi" \
  RYOKU_GAMEMODE_INTEL_PSTATE_ROOT="$tmp/intel_pstate" \
    bash "$ROOT_DIR/bin/ryoku-gamemode-perf" "$@"
}

# ── full instance: dpm high, boost on, nvidia clocks locked ──────────────────
tmp="$(mktemp -d)"
make_env "$tmp"
run_helper "$tmp" enable full

[[ "$(cat "$tmp/drm/card0/device/power_dpm_force_performance_level")" == "high" ]] \
  || fail "enable should force the amdgpu dpm level to high"
[[ "$(cat "$tmp/cpufreq/boost")" == "1" ]] \
  || fail "enable should force the global cpufreq boost on"
[[ "$(cat "$tmp/state/dpm-card0")" == "auto" ]] \
  || fail "enable should save the dpm pre-state for restore"
grep -q -- '-lgc 0,2370' "$tmp/events" \
  || fail "enable full should lock NVIDIA graphics clocks to the queried max"
[[ ! -e "$tmp/state/dpm-card1" ]] \
  || fail "card1 has no dpm knob and must be skipped (no pre-state saved)"

run_helper "$tmp" disable full
[[ "$(cat "$tmp/drm/card0/device/power_dpm_force_performance_level")" == "auto" ]] \
  || fail "disable should restore the saved dpm level"
[[ "$(cat "$tmp/cpufreq/boost")" == "0" ]] \
  || fail "disable should restore the saved boost value"
grep -q -- '-rgc' "$tmp/events" \
  || fail "disable should reset NVIDIA clock locks"
[[ ! -d "$tmp/state" || -z "$(ls -A "$tmp/state")" ]] \
  || fail "disable should clear the saved pre-state"
rm -rf "$tmp"

# ── base instance: no NVIDIA calls ───────────────────────────────────────────
tmp="$(mktemp -d)"
make_env "$tmp"
run_helper "$tmp" enable base
if grep -q 'nvidia-smi' "$tmp/events"; then
  fail "enable base must not touch NVIDIA clocks"
fi
run_helper "$tmp" disable base
rm -rf "$tmp"

# ── absent knobs are skipped silently ────────────────────────────────────────
tmp="$(mktemp -d)"
mkdir -p "$tmp/drm" "$tmp/cpufreq" "$tmp/state" "$tmp/bin"
: >"$tmp/events"
RYOKU_TEST_EVENTS="$tmp/events" \
RYOKU_GAMEMODE_DRM_ROOT="$tmp/drm" \
RYOKU_GAMEMODE_CPUFREQ_ROOT="$tmp/cpufreq" \
RYOKU_GAMEMODE_STATE_DIR="$tmp/state" \
RYOKU_GAMEMODE_NVIDIA_SMI="$tmp/bin/does-not-exist" \
  bash "$ROOT_DIR/bin/ryoku-gamemode-perf" enable full \
  || fail "enable must not fail when no knob exists on this hardware"
rm -rf "$tmp"

# ── double-enable must not clobber the saved pre-state (save-guard teeth) ─────
tmp="$(mktemp -d)"
make_env "$tmp"
run_helper "$tmp" enable full
# Live files are now already-applied; enabling a SECOND time must NOT re-save
# the now-mutated values over the genuine pre-state.
printf 'high\n' >"$tmp/drm/card0/device/power_dpm_force_performance_level"
printf '1\n' >"$tmp/cpufreq/boost"
run_helper "$tmp" enable full
run_helper "$tmp" disable full
[[ "$(cat "$tmp/drm/card0/device/power_dpm_force_performance_level")" == "auto" ]] \
  || fail "double-enable must keep the ORIGINAL dpm pre-state for restore"
[[ "$(cat "$tmp/cpufreq/boost")" == "0" ]] \
  || fail "double-enable must keep the ORIGINAL boost pre-state for restore"
[[ ! -d "$tmp/state" || -z "$(ls -A "$tmp/state")" ]] \
  || fail "disable should clear the saved pre-state"
rm -rf "$tmp"

# ── amd_pstate: per-policy boost when no global cpufreq/boost exists ──────────
tmp="$(mktemp -d)"
make_env "$tmp"
rm -f "$tmp/cpufreq/boost"   # force the per-policy (amd_pstate) branch
run_helper "$tmp" enable full
[[ "$(cat "$tmp/cpufreq/policy0/boost")" == "1" ]] \
  || fail "enable should force the per-policy amd_pstate boost on"
[[ "$(cat "$tmp/state/boost-policy0")" == "0" ]] \
  || fail "enable should save the per-policy boost pre-state"
run_helper "$tmp" disable full
[[ "$(cat "$tmp/cpufreq/policy0/boost")" == "0" ]] \
  || fail "disable should restore the per-policy boost value"
rm -rf "$tmp"

# ── nvidia-smi multi-GPU: query prints one line per GPU, head/SIGPIPE safe ────
tmp="$(mktemp -d)"
make_env "$tmp"
cat >"$tmp/bin/nvidia-smi" <<'EOF'
#!/bin/bash
printf 'nvidia-smi:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
if [[ $* == *clocks.max.graphics* ]]; then printf '2370\n1800\n'; fi
EOF
chmod 755 "$tmp/bin/nvidia-smi"
run_helper "$tmp" enable full \
  || fail "enable full must survive a multi-GPU nvidia-smi query"
grep -q -- '-lgc 0,2370' "$tmp/events" \
  || fail "enable full should lock to the first GPU's max clock"
rm -rf "$tmp"

# ── nvidia-smi query failure: best-effort, no lock attempted ──────────────────
tmp="$(mktemp -d)"
make_env "$tmp"
cat >"$tmp/bin/nvidia-smi" <<'EOF'
#!/bin/bash
printf 'nvidia-smi:%s\n' "$*" >>"$RYOKU_TEST_EVENTS"
if [[ $* == *clocks.max.graphics* ]]; then exit 1; fi
EOF
chmod 755 "$tmp/bin/nvidia-smi"
run_helper "$tmp" enable full \
  || fail "enable full must survive a failing nvidia-smi query"
if grep -q -- '-lgc' "$tmp/events"; then
  fail "enable full must not attempt a clock lock when the query fails"
fi
rm -rf "$tmp"
# ── Intel intel_pstate: turbo via no_turbo (inverted), no cpufreq boost ───────
tmp="$(mktemp -d)"
make_env "$tmp"
rm -f "$tmp/cpufreq/boost" "$tmp/cpufreq/policy0/boost"   # intel_pstate has neither
mkdir -p "$tmp/intel_pstate"
printf '1\n' >"$tmp/intel_pstate/no_turbo"                # turbo currently disabled
run_helper "$tmp" enable full
[[ "$(cat "$tmp/intel_pstate/no_turbo")" == "0" ]] \
  || fail "enable should clear intel_pstate no_turbo (turbo on)"
[[ "$(cat "$tmp/state/no-turbo")" == "1" ]] \
  || fail "enable should save the intel no_turbo pre-state"
run_helper "$tmp" disable full
[[ "$(cat "$tmp/intel_pstate/no_turbo")" == "1" ]] \
  || fail "disable should restore the intel no_turbo pre-state"
rm -rf "$tmp"

echo "PASS: gamemode perf helper"
