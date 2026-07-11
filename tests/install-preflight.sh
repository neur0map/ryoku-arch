#!/usr/bin/env bash
# fixture test for the Secure Boot preflight gate (installation/backend/lib/
# preflight.sh): Limine ships unsigned, so a box enforcing Secure Boot installs
# a system that then dies at a firmware security violation on first boot. the
# gate reads the SecureBoot efivar (last byte 1 = on) and aborts unless
# RYOKU_ALLOW_SECUREBOOT=1. the efivar path is overridden with RYOKU_SB_VAR, so
# we assert the byte parse and the override wiring against temp files without
# touching firmware.
# the mocks are single-quoted on purpose: they are shell snippets eval'd in a
# subshell and must not expand here.
# shellcheck disable=SC2016
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# a SecureBoot efivar payload: 4-byte attribute prefix + a 1-byte state.
sb_var() { printf '\x06\x00\x00\x00%b' "$1" >"$tmp/sb"; printf '%s' "$tmp/sb"; }

# sb_enabled <RYOKU_SB_VAR>: run ryoku_secureboot_enabled against that path,
# leaving the exit code in $rc (0 = Secure Boot on).
sb_enabled() {
  rc=0
  RYOKU_SB_VAR="$1" ROOT="$root" bash -c '
    source "$ROOT/installation/backend/lib/preflight.sh"
    ryoku_secureboot_enabled
  ' || rc=$?
}

# --- last byte 1 -> enabled ----------------------------------------------------
sb_enabled "$(sb_var '\x01')"
[[ $rc -eq 0 ]] || fail "SecureBoot var ending in 0x01 must read as enabled (rc=$rc)"

# --- last byte 0 -> not enabled ------------------------------------------------
sb_enabled "$(sb_var '\x00')"
[[ $rc -ne 0 ]] || fail "SecureBoot var ending in 0x00 must read as not enabled"

# --- var absent -> not enabled (the common no-UEFI-var case) -------------------
sb_enabled "$tmp/does-not-exist"
[[ $rc -ne 0 ]] || fail "an absent SecureBoot var must read as not enabled"

# --- gate wiring: the exact preflight branch, driven with a real enabled var ---
# ryoku_preflight's own root/UEFI checks precede this branch and cannot be
# faked in a unit test (EUID is readonly), so we exercise the gate condition as
# written in preflight.sh against the REAL ryoku_secureboot_enabled: the
# RYOKU_ALLOW_SECUREBOOT override decides whether an enabled box is blocked.
gate() {
  local allow=$1 var=$2
  RYOKU_ALLOW_SECUREBOOT="$allow" RYOKU_SB_VAR="$var" ROOT="$root" bash -c '
    source "$ROOT/installation/backend/lib/common.sh"
    source "$ROOT/installation/backend/lib/preflight.sh"
    if [[ ${RYOKU_ALLOW_SECUREBOOT:-} != 1 ]] && ryoku_secureboot_enabled; then
      die "Secure Boot is enabled and Limine is unsigned"
    fi
    echo "preflight would proceed"
  ' 2>&1
}

on="$(sb_var '\x01')"
rc=0; out="$(gate '' "$on")" || rc=$?
[[ $rc -ne 0 ]] || fail "an enabled Secure Boot box must abort preflight when RYOKU_ALLOW_SECUREBOOT is unset"
grep -qF 'Secure Boot is enabled' <<<"$out" || fail "the abort did not explain the Secure Boot failure"

rc=0; out="$(gate 1 "$on")" || rc=$?
[[ $rc -eq 0 ]] || fail "RYOKU_ALLOW_SECUREBOOT=1 must let an enabled box through (rc=$rc): $out"
grep -qF 'preflight would proceed' <<<"$out" || fail "the override did not let preflight proceed"

# a box with Secure Boot OFF proceeds regardless of the override.
off="$(sb_var '\x00')"
rc=0; out="$(gate '' "$off")" || rc=$?
[[ $rc -eq 0 ]] || fail "a Secure Boot-off box must pass the gate without the override (rc=$rc): $out"

echo "install-preflight: all checks passed"
