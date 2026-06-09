#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

cd "$ROOT_DIR"

# The shared package manifests (install/ryoku-*.packages) are the only package
# data. The standalone installer must not keep a parallel list or a hardcoded
# deny list that drifts from them.
[[ ! -e shell-install/packages/shell.deps ]] || fail "shell.deps must be deleted (manifests are the only package data)"
[[ ! -d shell-install/packages ]] || fail "shell-install/packages/ should be removed once shell.deps is gone"
! grep -rq 'RSI_ARCH_PKG' shell-install/ || fail "the RSI_ARCH_PKG package map must be removed"
! grep -rq 'RSI_ARCH_DENY' shell-install/ || fail "the hardcoded RSI_ARCH_DENY must be removed (use @os-only tags)"
! grep -rq 'RSI_DEPS_FILE' shell-install/ || fail "RSI_DEPS_FILE (shell.deps) must be removed"
! grep -rq 'RSI_MINIMAL' shell-install/ || fail "--minimal mode must be removed (install everything is the point)"

printf 'PASS: tests/shell-install-no-duplicate-pkgdata.sh\n'
