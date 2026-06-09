#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

cd "$ROOT_DIR"

# The generated ryoku-shell branch is dropped: standalone installs pull a real
# channel (main / unstable-dev) directly.
[[ ! -e .github/workflows/publish-ryoku-shell.yml ]] \
  || fail "publish-ryoku-shell.yml must be deleted (no generated branch)"
! grep -q 'RYOKU_REF:-ryoku-shell' shell-install/boot.sh \
  || fail "shell-install/boot.sh must not default RYOKU_REF to ryoku-shell"
grep -q 'RYOKU_REF:-main' shell-install/boot.sh \
  || fail "shell-install/boot.sh must default RYOKU_REF to main"

# No tracked doc may tell users to install FROM the ryoku-shell branch.
if git grep -lEI 'branch=ryoku-shell|--branch ryoku-shell|RYOKU_REF=ryoku-shell|RYOKU_REF="ryoku-shell"' -- '*.md' '*.mdx' >/dev/null 2>&1; then
  echo "offending docs:" >&2
  git grep -lEI 'branch=ryoku-shell|--branch ryoku-shell|RYOKU_REF=ryoku-shell|RYOKU_REF="ryoku-shell"' -- '*.md' '*.mdx' >&2
  fail "a tracked doc still references installing from the ryoku-shell branch"
fi

printf 'PASS: tests/no-ryoku-shell-branch.sh\n'
