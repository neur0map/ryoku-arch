#!/bin/bash

# Exercises rsi_deploy_payload for REAL (not dry-run) against throwaway git
# repos, proving the standalone deploy produces a working git checkout that
# ryoku-update (git pull based) can update. This covers the mechanism that
# replaced the old rsync deploy.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

export HOME="$work/home"
mkdir -p "$HOME"

git_t() { git -c user.email=t@example.com -c user.name=tester "$@"; }

# A fake "official" remote (bare) carrying a `main` branch with a tiny tree.
seed="$work/seed"
git_t init -q "$seed"
mkdir -p "$seed/bin" "$seed/lib" "$seed/distro/arch"
printf 'echo hi\n' >"$seed/bin/ryoku-x"
printf '# runtime\n' >"$seed/lib/runtime-env.sh"
printf '# pkgbuild\n' >"$seed/distro/arch/PKGBUILD"
git_t -C "$seed" add -A
git_t -C "$seed" commit -qm seed
git_t -C "$seed" branch -M main
remote="$work/remote.git"
git_t clone -q --bare "$seed" "$remote"

# The bootstrap checkout boot.sh produces: a clone of the remote, on `main`.
boot="$work/boot"
git_t clone -q "$remote" "$boot"

# Load the installer libs, then point RSI_REPO at the bootstrap checkout and the
# deploy target under the throwaway HOME.
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/env.sh"
export RSI_REPO="$boot"
export RSI_RYOKU_PATH="$HOME/.local/share/ryoku"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/ui.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/manifest.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/backup.sh"
# shellcheck disable=SC1091
source "$ROOT_DIR/shell-install/lib/deploy.sh"

rsi_manifest_init
rsi_deploy_payload >/dev/null 2>&1 || fail "rsi_deploy_payload exited non-zero"

# 1. The deployed tree is a real git repo (ryoku-update needs git -C to work).
[[ -d $RSI_RYOKU_PATH/.git ]] || fail "deployed tree has no .git (ryoku-update would fail)"

# 2. It is on the channel branch the bootstrap was on.
branch="$(git_t -C "$RSI_RYOKU_PATH" rev-parse --abbrev-ref HEAD)"
[[ $branch == main ]] || fail "deployed tree not on channel main (got: $branch)"

# 3. origin points at the real upstream, not the temporary bootstrap clone, so
#    ryoku-update pulls from the official remote.
url="$(git_t -C "$RSI_RYOKU_PATH" remote get-url origin)"
[[ $url == "$remote" ]] || fail "origin should be the upstream remote ($remote), got: $url"

# 4. ryoku-update's `git -C <path> pull` is viable (upstream tracked).
git_t -C "$RSI_RYOKU_PATH" pull --ff-only >/dev/null 2>&1 \
  || fail "deployed tree is not pull-able (ryoku-update would fail)"

# 5. The payload content (incl. distro/ for cava rebuilds) is present.
[[ -f $RSI_RYOKU_PATH/bin/ryoku-x ]] || fail "deployed tree missing payload content"
[[ -d $RSI_RYOKU_PATH/distro/arch ]] || fail "deployed tree missing distro/ (cava rebuilds need it)"

# 6. A subsequent upstream commit is pulled cleanly (proves real update parity).
printf 'echo bye\n' >"$seed/bin/ryoku-y"
git_t -C "$seed" add -A
git_t -C "$seed" commit -qm second
git_t -C "$seed" push -q "$remote" main
git_t -C "$RSI_RYOKU_PATH" pull --ff-only >/dev/null 2>&1 || fail "could not pull a new upstream commit"
[[ -f $RSI_RYOKU_PATH/bin/ryoku-y ]] || fail "update did not bring the new upstream file"

printf 'PASS: tests/shell-install-deploy-git-checkout.sh\n'
