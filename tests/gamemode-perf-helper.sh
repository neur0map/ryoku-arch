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

echo "PASS: gamemode perf helper"
