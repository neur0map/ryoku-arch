#!/usr/bin/env bash
# Hermetic test for bin/ryoku-recovery, the curl|bash panic button. It must
# always restore a machine to the stable main branch, even when RYOKU_CHANNEL is
# leaked to unstable-dev (the failure that bricked a user: an old ISO updater
# switched the checkout to unstable-dev, where the new tree has none of the old
# helper commands). It must repair the pre-rewrite checkout (kept at the data
# root) in place rather than leave the broken checkout beside a fresh one, and
# drop the dangling pre-rewrite runtime-env bridge.
#
# No network, no pacman, no real build: the origin is a local bare repo whose
# deploy.sh is a stub, and a fake `go` satisfies the recovery preflight.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
RECOVERY="$ROOT/bin/ryoku-recovery"
[[ -x $RECOVERY ]] || { echo "::error::missing or non-executable $RECOVERY" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# A fake `go` so the recovery preflight `need go` passes on a CI runner with no
# Go toolchain; the stub deploy.sh below never actually invokes it.
mkdir -p "$work/fakebin"
printf '#!/bin/sh\nexit 0\n' >"$work/fakebin/go"
chmod +x "$work/fakebin/go"
export PATH="$work/fakebin:$PATH"

git_q() { git -c init.defaultBranch=main -c user.name=t -c user.email=t@t -c advice.detachedHead=false "$@"; }

# Build a local origin with main + unstable-dev. main carries a stub deploy.sh
# that records which checkout it ran from, standing in for the real build.
origin="$work/origin.git"
seed="$work/seed"
git_q init -q "$seed"
mkdir -p "$seed/ryoku/shell" "$seed/system/packages"
cat >"$seed/ryoku/shell/deploy.sh" <<'EOF'
#!/usr/bin/env bash
printf 'deployed-from %s\n' "$(cd "$(dirname "$0")/../.." && pwd -P)" >"${RYOKU_TEST_MARKER:?}"
EOF
chmod +x "$seed/ryoku/shell/deploy.sh"
echo "# packages" >"$seed/system/packages/base.packages"
git_q -C "$seed" add -A
git_q -C "$seed" commit -qm "main seed"
git_q -C "$seed" checkout -q -b unstable-dev
echo "unstable only" >"$seed/UNSTABLE_MARKER"
git_q -C "$seed" add -A
git_q -C "$seed" commit -qm "unstable work"
git_q -C "$seed" checkout -q main
git_q init -q --bare "$origin"
git_q -C "$seed" remote add origin "$origin"
git_q -C "$seed" push -q origin main unstable-dev

fail=0
check() {
  if [[ $1 == "$2" ]]; then echo "  ok: $3"; else
    echo "::error::FAIL: $3 (got '$1' want '$2')" >&2
    fail=1
  fi
}
absent() { if [[ ! -e $1 && ! -L $1 ]]; then echo "  ok: $2"; else echo "::error::FAIL: $2" >&2; fail=1; fi; }

# Case 1: an old-layout checkout stranded on unstable-dev, with RYOKU_CHANNEL
# leaked to unstable-dev. Recovery must drag it back to main in place.
home1="$work/home1"
data1="$home1/.local/share/ryoku"
mkdir -p "$(dirname "$data1")" "$home1/.local/lib"
git_q clone -q "$origin" "$data1"
git_q -C "$data1" checkout -q unstable-dev
# The old updater stash-pops before switching, which can leave the tree dirty or
# conflicted; dirty it on purpose so the test proves the rescue forces past that.
echo "stray local edit" >>"$data1/system/packages/base.packages"
echo "stray" >"$data1/stray-untracked"
ln -s "$data1/lib/runtime-env.sh" "$home1/.local/lib/runtime-env.sh" # dangling bridge

HOME="$home1" XDG_DATA_HOME="$home1/.local/share" \
  RYOKU_RECOVERY_URL="$origin" RYOKU_CHANNEL="unstable-dev" \
  RYOKU_RECOVERY_FORCE=1 RYOKU_TEST_MARKER="$work/marker1" \
  "$RECOVERY" --yes --no-packages >/dev/null

check "$(git_q -C "$data1" rev-parse --abbrev-ref HEAD)" "main" \
  "old checkout repaired in place onto main despite RYOKU_CHANNEL=unstable-dev"
check "$(sed -n 's/^deployed-from //p' "$work/marker1" 2>/dev/null)" "$(cd "$data1" && pwd -P)" \
  "deploy ran from the repaired in-place checkout"
absent "$data1/UNSTABLE_MARKER" "unstable-dev content cleaned from the checkout"
absent "$home1/.local/lib/runtime-env.sh" "dangling pre-rewrite runtime-env bridge removed"
check "$(git_q -C "$data1" status --porcelain)" "" \
  "rescue forces a dirty stranded checkout clean"

# Case 2: a clean machine with no prior checkout clones to repo/ on main.
home2="$work/home2"
data2="$home2/.local/share/ryoku"
HOME="$home2" XDG_DATA_HOME="$home2/.local/share" \
  RYOKU_RECOVERY_URL="$origin" RYOKU_CHANNEL="unstable-dev" \
  RYOKU_RECOVERY_FORCE=1 RYOKU_TEST_MARKER="$work/marker2" \
  "$RECOVERY" --yes --no-packages >/dev/null

check "$(git_q -C "$data2/repo" rev-parse --abbrev-ref HEAD)" "main" \
  "clean machine clones to repo/ on main"

if ((fail)); then echo "ryoku-recovery: FAILED" >&2; exit 1; fi
echo "ryoku-recovery: all checks passed"
