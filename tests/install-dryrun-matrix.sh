#!/usr/bin/env bash
# end-to-end smoke test of the install backend (installation/backend/ryoku-install)
# under RYOKU_DRYRUN across the strategy x encrypt x swap matrix: every
# combination must run clean, emit the six staged @@RYOKU_STEP sentinels in the
# canonical order the TUI tracks, and print exactly one @@RYOKU_DONE as the LAST
# sentinel (the TUI treats @@RYOKU_DONE as the success signal; a stray or early
# one would falsely mark a failed install complete). also pins the per-mode
# narration a reviewer relies on: the shared-Windows-ESP dual-boot promise (a
# dedicated XBOOTLDR /boot, Windows' own /EFI/Microsoft left alone), the pinned
# LUKS KDF, and the hibernation resume line. dry-run, so no disk is touched.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
fail() { echo "FAIL: $1" >&2; exit 1; }

canonical="partition filesystems mount pacstrap configure bootloader"

# run_backend <strategy> <encrypt> <swap>: run ryoku-install in dry-run with the
# repo payload pointed at the checkout. leaves the full output in $out and the
# exit code in $rc.
run_backend() {
  rc=0
  out="$(RYOKU_DRYRUN=1 RYOKU_REPO="$root" \
    RYOKU_DISK=/dev/vda RYOKU_PASSWORD_HASH='$6$fake$hash' \
    RYOKU_DISK_STRATEGY="$1" RYOKU_ENCRYPT="$2" RYOKU_SWAP_GIB="$3" \
    RYOKU_LUKS_PASSPHRASE=passphrase \
    bash "$root/installation/backend/ryoku-install" 2>&1)" || rc=$?
}

for strategy in whole alongside; do
  for encrypt in 0 1; do
    for swap in 0 8; do
      tag="strategy=$strategy encrypt=$encrypt swap=$swap"
      run_backend "$strategy" "$encrypt" "$swap"
      [[ $rc -eq 0 ]] || fail "$tag: dry run exited $rc: $out"

      # exactly six @@RYOKU_STEP sentinels, in the canonical order.
      steps="$(grep -oE '@@RYOKU_STEP [a-z]+' <<<"$out" | awk '{print $2}' | tr '\n' ' ')"
      [[ ${steps% } == "$canonical" ]] || fail "$tag: step order is '${steps% }', expected '$canonical'"

      # exactly one @@RYOKU_DONE, and it is the LAST sentinel of any kind.
      done_n="$(grep -cF '@@RYOKU_DONE' <<<"$out")"
      [[ $done_n -eq 1 ]] || fail "$tag: expected exactly 1 @@RYOKU_DONE, got $done_n"
      last="$(grep -E '@@RYOKU_STEP|@@RYOKU_DONE' <<<"$out" | tail -n1)"
      [[ $last == '@@RYOKU_DONE' ]] || fail "$tag: @@RYOKU_DONE is not the last sentinel (last='$last')"

      # secure-boot gate is narrated in every run (the preflight dry-run note).
      grep -qiF 'secure boot' <<<"$out" || fail "$tag: preflight did not narrate the Secure Boot gate"

      # per-strategy narration.
      if [[ $strategy == alongside ]]; then
        grep -qF 'XBOOTLDR' <<<"$out"        || fail "$tag: alongside missing the dedicated XBOOTLDR /boot narration"
        grep -qF '/EFI/Microsoft' <<<"$out"  || fail "$tag: alongside missing the shared-Windows-ESP (/EFI/Microsoft) promise"
        grep -qF 'ryokuboot' <<<"$out"    || fail "$tag: alongside missing the ryokuboot partlabel"
      else
        grep -qF '/EFI/Microsoft' <<<"$out" && fail "$tag: whole-disk wrongly narrated Windows' ESP (/EFI/Microsoft)"
      fi

      # per-encrypt narration: the pinned argon2id KDF only when encrypting.
      if [[ $encrypt == 1 ]]; then
        grep -qF 'luksFormat --type luks2 --pbkdf argon2id' <<<"$out" \
          || fail "$tag: encrypt missing the pinned argon2id luksFormat"
      else
        grep -qF 'luksFormat' <<<"$out" && fail "$tag: non-encrypt run emitted a luksFormat"
      fi

      # per-swap narration: the hibernation resume line only when swap > 0.
      if [[ $swap -gt 0 ]]; then
        grep -qF 'hibernation resume=' <<<"$out" || fail "$tag: swap>0 missing the hibernation resume narration"
      else
        grep -qF 'hibernation resume=' <<<"$out" && fail "$tag: swap=0 wrongly narrated a hibernation resume"
      fi
    done
  done
done

# RYOKU_GPU_MODE wiring: the value is now CONSUMED. under dry-run the mapped
# `ryoku-gpu mode` call is narrated against the user's gpu.lua; sync->performance.
out="$(RYOKU_DRYRUN=1 RYOKU_REPO="$root" RYOKU_DISK=/dev/vda \
  RYOKU_PASSWORD_HASH='$6$fake$hash' RYOKU_DISK_STRATEGY=whole RYOKU_GPU_MODE=sync \
  bash "$root/installation/backend/ryoku-install" 2>&1)" || fail "gpu-mode dry run exited nonzero: $out"
grep -qF 'ryoku-gpu mode performance' <<<"$out" || fail "RYOKU_GPU_MODE=sync did not narrate 'ryoku-gpu mode performance'"
grep -qF '/home/ryoku/.config/hypr/gpu.lua' <<<"$out" || fail "gpu-mode narration did not target the user's gpu.lua"

# absent by default: no ryoku-gpu mode call when RYOKU_GPU_MODE is unset.
out="$(RYOKU_DRYRUN=1 RYOKU_REPO="$root" RYOKU_DISK=/dev/vda \
  RYOKU_PASSWORD_HASH='$6$fake$hash' RYOKU_DISK_STRATEGY=whole \
  bash "$root/installation/backend/ryoku-install" 2>&1)" || fail "no-gpu-mode dry run exited nonzero: $out"
grep -qF 'ryoku-gpu mode' <<<"$out" && fail "ryoku-gpu mode narrated when RYOKU_GPU_MODE was unset"

echo "install-dryrun-matrix: all 8 combinations passed"
