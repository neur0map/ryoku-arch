#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

cd "$ROOT_DIR"

deploy="shell-install/lib/deploy.sh"

# ryoku-update is git-based (`git -C "$RYOKU_PATH" pull`). The standalone deploy
# must therefore lay down a real git checkout, not an rsync copy that strips
# .git, or standalone installs can never update.
grep -Eq 'git clone|git -C' "$deploy" \
  || fail "rsi_deploy_payload must deploy a git checkout (ryoku-update is git-based)"
! grep -q "exclude='\.git'" "$deploy" \
  || fail "must not exclude .git from the deployed tree (breaks ryoku-update)"
! grep -q "exclude='distro'" "$deploy" \
  || fail "must not exclude distro/ (cava-ryoku rebuilds on update need it)"

printf 'PASS: tests/shell-install-deploy-is-git.sh\n'
