#!/usr/bin/env bash
# Prevent the "fresh install halts in the chroot" class: a bare
# `systemctl --user enable|start|...` run inside a chroot install phase fails (no
# user bus) and, under `set -e`, halts the whole install before the desktop is
# deployed. Every such call in a chroot-run phase must be guarded (|| true, or a
# 2>/dev/null fallthrough).
set -euo pipefail

ROOT=${RYOKU_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}
phases="$ROOT/installation/backend/lib"

fail=0
while IFS= read -r -d '' f; do
  lineno=0
  while IFS= read -r line; do
    lineno=$((lineno + 1))
    [[ $line =~ ^[[:space:]]*# ]] && continue
    [[ $line == *"systemctl --user"* ]] || continue
    if [[ $line != *"|| true"* && $line != *"2>/dev/null"* ]]; then
      echo "::error file=installation/backend/lib/$(basename "$f"),line=$lineno::unguarded 'systemctl --user' in a chroot phase" >&2
      printf '  %s:%s: %s\n' "$(basename "$f")" "$lineno" "${line#"${line%%[![:space:]]*}"}" >&2
      fail=1
    fi
  done <"$f"
done < <(find "$phases" -type f -name '*.sh' -print0 2>/dev/null)

if (( fail == 0 )); then
  echo "install-chroot-safety: all chroot-run 'systemctl --user' calls are guarded"
fi
exit "$fail"
