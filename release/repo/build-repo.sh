#!/usr/bin/env bash
# build, sign, and assemble the [ryoku] pacman repo.
#
# walks release/packages/*/PKGBUILD, makepkg-builds each, signs with the ryoku
# release key, then `repo-add -s` to produce the signed db. layout matches the
# public mirror at https://repo.ryoku.dev/<arch>/: an <arch>/ subdir holding
# the *.pkg.tar.zst, their *.sig detached signatures, and ryoku.db /
# ryoku.db.sig (+ ryoku.files). publish workflow rclones that <arch>/ straight
# to R2.
#
# db is rebuilt from the package set every run: <arch>/ wiped, repacked from
# exactly the packages produced now. never `repo-add --new`. so: idempotent,
# and a removed package dir simply falls out of the db.
#
# build deps live on the build host only (Go toolchain + Ryoku.Blobs QML
# plugin): base-devel, go, cmake, ninja, qt6-shadertools, qt6-declarative.
# makepkg runs --nodeps on purpose: runtime depends (and AUR depends) aren't
# needed to compile the artifacts and aren't resolvable here anyway.
#
# usage: ./build-repo.sh
#
# env overrides:
#   RYOKU_REPO_OUT      output dir            (default: ./out beside this script)
#   RYOKU_REPO_KEY      gpg key id to sign    (default: release key fingerprint)
#   RYOKU_REPO_NAME     repo db base name     (default: ryoku)
#   RYOKU_REPO_ARCH     target architecture   (default: x86_64)
#   RYOKU_PACKAGES_DIR  PKGBUILD parent dir   (default: <repo>/release/packages)
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)   # release/repo
RELEASE_DIR=$(cd "$SCRIPT_DIR/.." && pwd)                  # release

OUT_DIR=${RYOKU_REPO_OUT:-$SCRIPT_DIR/out}
KEY_ID=${RYOKU_REPO_KEY:-EB6D3C0F55A7B3CABA6B2838847B274F025DD6E3}
REPO_NAME=${RYOKU_REPO_NAME:-ryoku}
REPO_ARCH=${RYOKU_REPO_ARCH:-x86_64}
PACKAGES_DIR=${RYOKU_PACKAGES_DIR:-$RELEASE_DIR/packages}

ARCH_DIR=$OUT_DIR/$REPO_ARCH
DB_PATH=$ARCH_DIR/$REPO_NAME.db.tar.gz

log() { printf '\033[1;35m::\033[0m %s\n' "$*"; }
die() { printf 'build-repo.sh: error: %s\n' "$*" >&2; exit 1; }

# 0. preflight. makepkg refuses root; everything else just wants the pacman
#    tools and the release secret key in GNUPGHOME.
[[ $EUID -ne 0 ]] || die "makepkg refuses to run as root; run as a regular user"
command -v makepkg  >/dev/null 2>&1 || die "makepkg not found (pacman -S base-devel)"
command -v repo-add >/dev/null 2>&1 || die "repo-add not found (ships with pacman)"
command -v gpg      >/dev/null 2>&1 || die "gpg not found (pacman -S gnupg)"
[[ -d $PACKAGES_DIR ]] || die "packages dir not found: $PACKAGES_DIR"
gpg --list-secret-keys "$KEY_ID" >/dev/null 2>&1 \
  || die "release signing key $KEY_ID not in GNUPGHOME=${GNUPGHOME:-$HOME/.gnupg}"

shopt -s nullglob
pkgbuilds=("$PACKAGES_DIR"/*/PKGBUILD)
(( ${#pkgbuilds[@]} > 0 )) || die "no PKGBUILDs found under $PACKAGES_DIR"

# 1. fresh output tree. wiping the arch dir is what keeps the repo idempotent:
#    db gets rebuilt from exactly the packages produced this run, no stale
#    versions left to confuse repo-add.
log "Output dir -> $ARCH_DIR"
rm -rf "$ARCH_DIR"
mkdir -p "$ARCH_DIR"

# 2. build + sign every package straight into the arch dir. with --sign
#    makepkg writes the package and its detached .sig to PKGDEST. --nodeps
#    skips the (unresolvable, unneeded) runtime depends; --clean clears the
#    per-build $srcdir/$pkgdir so the checked-out source is left alone.
export PKGDEST=$ARCH_DIR
export PKGEXT='.pkg.tar.zst'

# per-build version for the monorepo packages: core semver + commit count +
# short sha (bin/ryoku-release-version --pkgver). every published build is
# then strictly newer + commit-identifiable in pacman terms, so `ryoku update`
# (pacman -Syu) actually sees an upgrade after each push and the Hub can show
# the commit. monorepo PKGBUILDs read RYOKU_PKGVER; ryoku-keyring and gpk keep
# their own versions (key-rotation date, upstream GlazePKG release). overridable.
: "${RYOKU_PKGVER:=$("$RELEASE_DIR/../bin/ryoku-release-version" --pkgver)}"
export RYOKU_PKGVER
log "Monorepo package version -> $RYOKU_PKGVER"
for pkgbuild in "${pkgbuilds[@]}"; do
  pkgdir=$(dirname "$pkgbuild")
  log "Building $(basename "$pkgdir")"
  ( cd "$pkgdir" \
      && makepkg --force --clean --nodeps --noconfirm --sign --key "$KEY_ID" )
done

# 3. collect built packages, confirm each is signed before indexing.
packages=("$ARCH_DIR"/*.pkg.tar.zst)
(( ${#packages[@]} > 0 )) || die "no packages were built into $ARCH_DIR"
for pkg in "${packages[@]}"; do
  [[ -e $pkg.sig ]] || die "missing signature for $(basename "$pkg")"
done

# 4. signed db from the actual package set. no --new: the dir was wiped above,
#    so repo-add always starts from empty and indexes exactly what's there. -s
#    signs the db with the release key.
log "Indexing ${#packages[@]} package(s) into $REPO_NAME.db"
repo-add -s -k "$KEY_ID" "$DB_PATH" "${packages[@]}"

# 5. repo-add leaves ryoku.db / ryoku.db.sig / ryoku.files as symlinks to the
#    versioned tarballs. object storage (R2/S3) has no symlinks and pacman
#    fetches the bare names, so materialize them as real files in place.
for link in "$REPO_NAME.db" "$REPO_NAME.db.sig" "$REPO_NAME.files" "$REPO_NAME.files.sig"; do
  target=$ARCH_DIR/$link
  [[ -L $target ]] || continue
  resolved=$(readlink -f "$target")
  rm -f "$target"
  cp "$resolved" "$target"
done

[[ -e $ARCH_DIR/$REPO_NAME.db ]]     || die "$REPO_NAME.db missing after repo-add"
[[ -e $ARCH_DIR/$REPO_NAME.db.sig ]] || die "$REPO_NAME.db.sig missing; signing failed"

log "Repo ready at $ARCH_DIR"
log "Serves: https://repo.ryoku.dev/stable/$REPO_ARCH/ (Server = https://repo.ryoku.dev/stable/\$arch)"
