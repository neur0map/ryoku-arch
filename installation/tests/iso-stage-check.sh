#!/usr/bin/env bash
# iso-stage-check.sh -- prove the ISO staging tree is byte-reproducible.
#
# Runs `build.sh --stage-only` twice into two throwaway STAGE dirs, then diffs
# the two staged profiles. A clean diff means the prebuilt binaries (three Go
# programs + the Ryoku.Blobs plugin) and the baked repo payload are
# deterministic for a fixed commit -- the whole point of the -trimpath /
# -buildid= / SOURCE_DATE_EPOCH plumbing in build.sh (see iso/README.md,
# "Reproducibility"). This doubles as an end-to-end smoke test that
# `build.sh --stage-only` still works.
#
# The .payload provenance stamp is regenerated identically per commit but is
# stripped before the diff anyway, so the check stays green on a dirty tree
# (rev-parse HEAD is stable, but this keeps the intent explicit).
#
# Skips cleanly (exit 0) when a build toolchain is missing, so CI runners
# without go/cmake/ninja stay green instead of failing on an absent dependency.
# The test wave owns any hook/CI wiring; nothing here wires itself in.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BUILD=$HERE/../iso/build.sh

for tool in go cmake ninja; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'iso-stage-check: SKIP (%s not found; build toolchain incomplete)\n' "$tool"
    exit 0
  fi
done

# The Ryoku.Blobs plugin build (cmake) hard-needs a Qt6 toolchain; go/cmake/ninja
# alone will not satisfy its find_package(Qt6). Skip when no Qt6 cmake config is
# discoverable (no qmake6 on PATH and no Qt6Config under a standard cmake prefix)
# so a plain runner with only go/cmake/ninja stays green instead of hard-failing
# deep inside cmake.
qt6_found=0
command -v qmake6 >/dev/null 2>&1 && qt6_found=1
for _qtdir in /usr/lib/cmake/Qt6 /usr/lib64/cmake/Qt6 /usr/lib/*/cmake/Qt6 /usr/local/lib/cmake/Qt6; do
  [[ -d $_qtdir ]] && qt6_found=1
done
if (( qt6_found == 0 )); then
  printf 'iso-stage-check: SKIP (no Qt6 toolchain; qmake6 and Qt6 cmake config both absent)\n'
  exit 0
fi

[[ -x $BUILD ]] || { printf 'iso-stage-check: FAIL (build.sh not executable at %s)\n' "$BUILD" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# each run gets its own STAGE/OUT/WORK so nothing bleeds between them; --stage-only
# never reaches OUT/WORK, but isolating them keeps the runs independent.
run_stage() {
  local n=$1
  if ! RYOKU_ISO_STAGE="$tmp/stage$n" \
       RYOKU_ISO_OUT="$tmp/out$n" \
       RYOKU_ISO_WORK="$tmp/work$n" \
         "$BUILD" --stage-only >"$tmp/log$n" 2>&1; then
    printf 'iso-stage-check: FAIL (staging run %s errored)\n' "$n" >&2
    cat "$tmp/log$n" >&2
    exit 1
  fi
}

printf 'iso-stage-check: staging run 1 ...\n'
run_stage 1
printf 'iso-stage-check: staging run 2 ...\n'
run_stage 2

# strip the intentionally-variable provenance stamp from both trees.
for n in 1 2; do
  rm -f "$tmp/stage$n/profile/airootfs/usr/share/ryoku/.payload"
done

if diff -qr "$tmp/stage1/profile" "$tmp/stage2/profile" >"$tmp/diff" 2>&1; then
  printf 'iso-stage-check: PASS (staging tree is reproducible)\n'
else
  printf 'iso-stage-check: FAIL (staging tree differs between runs)\n' >&2
  cat "$tmp/diff" >&2
  exit 1
fi
