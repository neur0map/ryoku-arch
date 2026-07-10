#!/usr/bin/env bash
# container install smoke test: prove a PACKAGED Ryoku install delivers the whole
# ~/.config a user needs. builds the [ryoku] packages from THIS checkout into a
# local repo, installs ryoku-desktop (which pulls every depend), materializes the
# config as a throwaway user, then asserts the materialized tree. this catches
# the "config file lands in the repo but no package ships it" class the delivery
# contract exists to prevent (docs/updates.md).
#
# runs as root inside an Arch or CachyOS container (archlinux:latest in CI).
# heavy (full build + desktop install), so it is driven by the install-test
# workflow (dispatch/schedule), never on every push.
#
#   installation/tests/container-install.sh [arch|cachyos]   (also RYOKU_TEST_BASE, default arch)
set -euo pipefail

BASE=${1:-${RYOKU_TEST_BASE:-arch}}
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
ARCH=x86_64
OUT="$REPO/release/repo/out/$ARCH"
TESTUSER=ryokutest

log() { printf '\033[1;35m::\033[0m %s\n' "$*"; }
die() { printf 'container-install: error: %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "must run as root (installs packages); got uid $EUID"

# CachyOS differs only in its extra signing keyring; everything downstream (build,
# materialize, assertions) is identical.
case "$BASE" in
  arch)    keyring=(archlinux-keyring) ;;
  cachyos) keyring=(cachyos-keyring archlinux-keyring) ;;
  *)       die "unknown base '$BASE' (want arch|cachyos)" ;;
esac
log "base: $BASE"

# 1. host toolchain. refresh the keyring first so signature checks on the freshly
#    synced core/extra pass on a stale base image, then the same build set
#    publish-repo.yml uses. makepkg's deps live on the host because build-repo.sh
#    builds --nodeps.
pacman -Sy --noconfirm --needed "${keyring[@]}"
pacman -Syu --noconfirm --needed \
  base-devel git go cmake ninja qt6-shadertools qt6-declarative gnupg

# 2. build the packages as an unprivileged user (makepkg refuses root), like
#    publish-repo.yml but with a throwaway ed25519 key: build-repo.sh always
#    signs, and the local repo is consumed with SigLevel=Never below, so the key
#    never needs to be trusted. MIRROR points at an empty dir so build-repo.sh's
#    "adopt already-published bytes" step is a no-op (no network, all fresh).
id builder &>/dev/null || useradd --create-home builder
chown -R builder:builder "$REPO"
mirror_stub=$(mktemp -d)
chmod 755 "$mirror_stub"

log "building [ryoku] packages from the checkout -> $OUT"
runuser -u builder -- env \
  HOME=/home/builder \
  RYOKU_REPO_ROOT="$REPO" \
  RYOKU_REPO_OUT="$REPO/release/repo/out" \
  RYOKU_REPO_NAME=ryoku-local \
  RYOKU_REPO_MIRROR="$mirror_stub" \
  bash -euo pipefail <<'BUILDER'
export GNUPGHOME=$(mktemp -d)
chmod 700 "$GNUPGHOME"
gpg --batch --gen-key <<'KEY'
%no-protection
Key-Type: eddsa
Key-Curve: ed25519
Key-Usage: sign
Expire-Date: 0
Name-Real: Ryoku CI
Name-Email: ci@ryoku.local
%commit
KEY
RYOKU_REPO_KEY=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')
export RYOKU_REPO_KEY
"$RYOKU_REPO_ROOT/release/repo/build-repo.sh"
BUILDER

[[ -f "$OUT/ryoku-local.db" ]] || die "build produced no local repo db at $OUT/ryoku-local.db"

# 3. register the local repo and install the desktop. SigLevel=Never relaxes
#    verification for THIS repo only (it is signed with the throwaway key above,
#    which pacman does not trust); official repos keep their SigLevel. an
#    unresolved depend must fail loudly here -- that is the whole point.
cat >>/etc/pacman.conf <<EOF

[ryoku-local]
SigLevel = Never
Server = file://$OUT
EOF

pacman -Sy --noconfirm
log "installing ryoku-desktop from [ryoku-local]"
pacman -S --noconfirm ryoku-desktop

[[ -d /usr/share/ryoku/config ]] || die "ryoku-desktop did not lay /usr/share/ryoku/config"
[[ -x /usr/bin/ryoku ]] || die "the ryoku CLI was not installed"

# 4. materialize as a throwaway user, forcing HOME/USER like deploy.sh's
#    ryoku_deploy_materialize (runuser keeps root's env otherwise).
id "$TESTUSER" &>/dev/null || useradd --create-home "$TESTUSER"
log "materializing config as $TESTUSER"
runuser -u "$TESTUSER" -- env \
  "HOME=/home/$TESTUSER" "USER=$TESTUSER" "LOGNAME=$TESTUSER" \
  ryoku materialize

# 5. assert the materialized ~/.config is complete: a representative, high-signal
#    slice spanning shell, compositor, palette, and every per-app config.
cfg="/home/$TESTUSER/.config"
files=(
  quickshell/pill/shell.qml
  hypr/hyprland.lua
  fish/config.fish
  starship.toml
  kitty/kitty.conf
  yazi/yazi.toml
  nvim/init.lua
  pip/pip.conf
  mimeapps.list
)
dirs=(quickshell/hub wallust)

missing=()
for f in "${files[@]}"; do
  [[ -s "$cfg/$f" ]] || missing+=("$cfg/$f")
done
for d in "${dirs[@]}"; do
  [[ -n $(find "$cfg/$d" -mindepth 1 -type f -print -quit 2>/dev/null) ]] \
    || missing+=("$cfg/$d/ (empty or absent)")
done
# the nvim handler ships system-wide (not materialized), so check the system tree.
[[ -s /usr/share/applications/ryoku-nvim.desktop ]] \
  || missing+=("/usr/share/applications/ryoku-nvim.desktop")

if (( ${#missing[@]} )); then
  echo "container-install: FAIL -- packaged install is missing config a user needs:" >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

log "container-install: OK -- ryoku-desktop delivered the full config to $cfg"
