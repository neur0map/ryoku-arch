#!/usr/bin/env bash
# Build, sign, and assemble the [ryoku] pacman repository.
#
# Builds every PKGBUILD under release/packages/*/ with makepkg, signs each
# package with the Ryoku release key, then runs `repo-add -s` to produce the
# signed repo database. The output is laid out for the public mirror at
# https://repo.ryoku.dev/<arch>/: an <arch>/ subdir holding the *.pkg.tar.zst
# packages, their *.sig detached signatures, and ryoku.db / ryoku.db.sig (plus
# ryoku.files). The publish workflow rclones that <arch>/ dir straight to R2.
#
# The database is rebuilt from the actual package set on every run: the <arch>/
# dir is wiped and repacked from exactly the packages produced this run, never
# `repo-add --new`. So runs are idempotent and a removed package dir simply
# drops out of the db.
#
# Build deps live on the build host only (the toolchain that compiles our Go
# binaries and the Ryoku.Blobs QML plugin): base-devel, go, cmake, ninja,
# qt6-shadertools, qt6-declarative. makepkg runs with --nodeps on purpose: our
# packages' runtime depends (and AUR depends) are not needed to compile the
# artifacts and are not resolvable here, so only the toolchain above must be
# present.
#
# Usage:
#   ./build-repo.sh
#
# Env overrides:
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

# 0. Sanity. makepkg refuses to run as root; everything else just needs the
#    pacman tools and the release secret key in the active GNUPGHOME.
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

# 1. Fresh output tree. Wiping the arch dir is what keeps the repo idempotent:
#    the db is rebuilt from exactly the packages produced this run, with no
#    stale versions left behind to confuse repo-add.
log "Output dir -> $ARCH_DIR"
rm -rf "$ARCH_DIR"
mkdir -p "$ARCH_DIR"

# 2. Build + sign every package straight into the arch dir. With --sign makepkg
#    writes both the package and its detached .sig to PKGDEST. --nodeps skips
#    the (unresolvable, unneeded) runtime depends; --clean removes the per-build
#    $srcdir/$pkgdir so the checked-out source tree is left untouched.
export PKGDEST=$ARCH_DIR
export PKGEXT='.pkg.tar.zst'

# Per-build version for the monorepo packages: the core semver plus the commit
# count and short sha (bin/ryoku-release-version --pkgver). Every published build
# is then a strictly newer, commit-identifiable pacman version, so `ryoku update`
# (pacman -Syu) actually sees an upgrade after each push and the Hub can show the
# commit. The monorepo PKGBUILDs read RYOKU_PKGVER; ryoku-keyring and gpk keep
# their own versions (key-rotation date and upstream GlazePKG release). Overridable.
: "${RYOKU_PKGVER:=$("$RELEASE_DIR/../bin/ryoku-release-version" --pkgver)}"
export RYOKU_PKGVER
log "Monorepo package version -> $RYOKU_PKGVER"
for pkgbuild in "${pkgbuilds[@]}"; do
  pkgdir=$(dirname "$pkgbuild")
  log "Building $(basename "$pkgdir")"
  ( cd "$pkgdir" \
      && makepkg --force --clean --nodeps --noconfirm --sign --key "$KEY_ID" )
done

# 3. Collect the built packages and confirm each was signed before indexing.
packages=("$ARCH_DIR"/*.pkg.tar.zst)
(( ${#packages[@]} > 0 )) || die "no packages were built into $ARCH_DIR"
for pkg in "${packages[@]}"; do
  [[ -e $pkg.sig ]] || die "missing signature for $(basename "$pkg")"
done

# 4. Build the signed database from the actual package set. No --new: the dir
#    was wiped above, so repo-add always starts from an empty db and indexes
#    exactly the packages present. -s signs the db with the release key.
log "Indexing ${#packages[@]} package(s) into $REPO_NAME.db"
repo-add -s -k "$KEY_ID" "$DB_PATH" "${packages[@]}"

# 5. repo-add leaves ryoku.db / ryoku.db.sig / ryoku.files as symlinks to the
#    versioned tarballs. Object storage (R2/S3) has no symlinks and pacman
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
