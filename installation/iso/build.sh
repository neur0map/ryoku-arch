#!/usr/bin/env bash
# Build the Ryoku live ISO.
#
# Stages a throwaway copy of this archiso profile, bakes the prebuilt installer
# (TUI + backend) and the repo payload into its airootfs, then hands the staged
# copy to mkarchiso. The committed profile under installation/iso is never
# mutated: every generated artifact lands in the staging tree.
#
# Usage:
#   ./build.sh                build the ISO (runs mkarchiso; needs root + archiso)
#   ./build.sh --stage-only   stage the profile but stop before mkarchiso
#
# Env overrides:
#   RYOKU_ISO_OUT     ISO output dir   (default: ./out)
#   RYOKU_ISO_WORK    mkarchiso work   (default: ./work)
#   RYOKU_ISO_STAGE   staging tree     (default: ./staging)
set -euo pipefail

PROFILE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)   # installation/iso
INSTALL_DIR=$(cd "$PROFILE_DIR/.." && pwd)                  # installation
REPO_ROOT=$(cd "$INSTALL_DIR/.." && pwd)                    # repo root
TUI_DIR=$INSTALL_DIR/tui
BACKEND_DIR=$INSTALL_DIR/backend

OUT_DIR=${RYOKU_ISO_OUT:-$PROFILE_DIR/out}
WORK_DIR=${RYOKU_ISO_WORK:-$PROFILE_DIR/work}
STAGE_DIR=${RYOKU_ISO_STAGE:-$PROFILE_DIR/staging}
PROFILE_STAGE=$STAGE_DIR/profile

STAGE_ONLY=0
[[ ${1:-} == --stage-only ]] && STAGE_ONLY=1

log() { printf '\033[1;35m::\033[0m %s\n' "$*"; }
die() { printf 'build.sh: error: %s\n' "$*" >&2; exit 1; }

# Bake the repo payload from tracked files only (git archive at HEAD), so
# gitignored developer cruft (editor and AI-tooling configs, build dirs, ISOs)
# never ships in the image.
stage_repo() {
  local src=$1 dst=$2
  mkdir -p "$dst"
  git -C "$src" archive --format=tar HEAD | tar -C "$dst" -xf -
}

# 0. Sanity.
[[ -f $TUI_DIR/go.mod ]]         || die "installer TUI not found at $TUI_DIR"
[[ -f $BACKEND_DIR/ryoku-install ]] || die "backend not found at $BACKEND_DIR/ryoku-install"
[[ -d $BACKEND_DIR/lib ]]        || die "backend lib not found at $BACKEND_DIR/lib"

# 1. Fresh profile copy (only the profile components; never the build dirs).
log "Staging profile -> $PROFILE_STAGE"
rm -rf "$PROFILE_STAGE"
mkdir -p "$PROFILE_STAGE"
for item in profiledef.sh packages.x86_64 pacman.conf airootfs efiboot syslinux; do
  cp -a "$PROFILE_DIR/$item" "$PROFILE_STAGE/"
done
AIROOTFS=$PROFILE_STAGE/airootfs

# 2. Build the installer TUI from source. The ISO ships the binary; the live
#    environment has no Go toolchain.
command -v go >/dev/null 2>&1 || die "go is required to build the TUI (pacman -S go)"
log "Building ryoku-tui from $TUI_DIR"
install -d "$AIROOTFS/usr/local/bin"
( cd "$TUI_DIR" && CGO_ENABLED=0 go build -trimpath -o "$AIROOTFS/usr/local/bin/ryoku-tui" . )

# 3. Bake the backend and its lib under /usr/local/lib/ryoku/backend. The
#    /usr/local/bin/ryoku-install wrapper (in the overlay) execs the real script;
#    the script finds its lib next to itself via realpath, so they stay together.
log "Installing backend -> /usr/local/lib/ryoku/backend"
install -d "$AIROOTFS/usr/local/lib/ryoku/backend"
install -m0755 "$BACKEND_DIR/ryoku-install" "$AIROOTFS/usr/local/lib/ryoku/backend/ryoku-install"
cp -a "$BACKEND_DIR/lib" "$AIROOTFS/usr/local/lib/ryoku/backend/lib"

# 4. Bake the repo payload at /usr/share/ryoku (RYOKU_REPO).
log "Baking repo payload -> /usr/share/ryoku"
stage_repo "$REPO_ROOT" "$AIROOTFS/usr/share/ryoku"

# 4b. Build the Ryoku shell daemon (Go). Like the TUI, neither the live ISO nor
#     the target has a Go toolchain, so it ships prebuilt inside the repo payload
#     for the backend's deploy step to install onto the target.
log "Building ryoku-shell from $REPO_ROOT/ryoku/shell/ipc"
install -d "$AIROOTFS/usr/share/ryoku/ryoku/shell/ipc"
( cd "$REPO_ROOT/ryoku/shell/ipc" && CGO_ENABLED=0 go build -trimpath -o "$AIROOTFS/usr/share/ryoku/ryoku/shell/ipc/ryoku-shell" . )

# 4c. Prebuild the Ryoku.Blobs QML plugin (the frame's blob renderer) into the
#     payload, same model as ryoku-shell: the target has no build toolchain, so
#     the backend's deploy step installs the prebuilt module. Build deps live on
#     the build host only.
command -v cmake >/dev/null 2>&1 || die "cmake is required to build the Ryoku.Blobs plugin (pacman -S cmake ninja qt6-shadertools)"
command -v ninja >/dev/null 2>&1 || die "ninja is required to build the Ryoku.Blobs plugin (pacman -S cmake ninja)"
log "Building Ryoku.Blobs plugin from $REPO_ROOT/ryoku/shell/plugin"
RYOKU_BLOBS_BUILD="$STAGE_DIR/blobs-build" \
  "$REPO_ROOT/ryoku/shell/plugin/build.sh" \
  "$AIROOTFS/usr/share/ryoku/ryoku/shell/plugin/dist"

# 5. Keep the staged launchers executable (profiledef file_permissions also sets
#    these at build time; this keeps the staged tree self-consistent meanwhile).
chmod 0755 \
  "$AIROOTFS/usr/local/bin/ryoku-installer-session" \
  "$AIROOTFS/usr/local/bin/ryoku-install" \
  "$AIROOTFS/usr/local/bin/ryoku-tui" \
  "$AIROOTFS/usr/local/lib/ryoku/backend/ryoku-install"

log "Profile staged at $PROFILE_STAGE"

if [[ $STAGE_ONLY -eq 1 ]]; then
  log "--stage-only: skipping mkarchiso"
  exit 0
fi

# 6. Assemble the ISO. mkarchiso needs root and the archiso package.
if ! command -v mkarchiso >/dev/null 2>&1; then
  cat >&2 <<EOF

build.sh: mkarchiso not found. Install the 'archiso' package, then build the
staged profile as root:

  sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_STAGE"

or, equivalently, from inside the staged profile:

  cd "$PROFILE_STAGE" && sudo mkarchiso -v -w work -o out .

EOF
  exit 1
fi

log "Running mkarchiso (requires root)"
install -d "$OUT_DIR"
if [[ $EUID -eq 0 ]]; then
  mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_STAGE"
else
  sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_STAGE"
fi
log "ISO written to $OUT_DIR"
