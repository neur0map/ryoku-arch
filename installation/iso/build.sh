#!/usr/bin/env bash
# build the Ryoku live ISO.
#
# stages a throwaway copy of this archiso profile, bakes the prebuilt
# installer (TUI + backend) + the repo payload into its airootfs, then hands
# the staged copy to mkarchiso. the committed profile under installation/iso
# is never mutated: every generated artifact lands in the staging tree.
#
# usage:
#   ./build.sh                build the ISO (mkarchiso; root + archiso)
#   ./build.sh --stage-only   stage the profile, stop before mkarchiso
#
# env:
#   RYOKU_ISO_OUT     ISO output dir   (./out)
#   RYOKU_ISO_WORK    mkarchiso work   (./work)
#   RYOKU_ISO_STAGE   staging tree     (./staging)
#   RYOKU_ISO_REPRO   1 = pin packages to the commit-dated Arch archive (off)
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

# reproducibility anchor. pin every timestamp-bearing step (mkarchiso, tar,
# gzip, squashfs, and profiledef.sh's iso_label / iso_version) to the commit's
# committer date instead of wall-clock build time, so the same commit builds to
# the same bytes. an already-exported value (e.g. CI) survives only when there
# is no git history to read; otherwise the commit wins.
if _commit_epoch=$(git -C "$REPO_ROOT" log -1 --pretty=%ct 2>/dev/null) && [[ -n $_commit_epoch ]]; then
  SOURCE_DATE_EPOCH=$_commit_epoch
fi
SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH:-$(date +%s)}
export SOURCE_DATE_EPOCH

# payload provenance, stamped into /usr/share/ryoku/.payload below and sed'd
# into the live motd. lets the target's deploy step warn when a long-lived
# ISO's baked payload has drifted from the live [ryoku] repo's package version.
PAYLOAD_COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)
PAYLOAD_DATE=$(git -C "$REPO_ROOT" log -1 --pretty=%cI 2>/dev/null || date -Iseconds)
PAYLOAD_VERSION=$(tr -d '[:space:]' <"$REPO_ROOT/VERSION" 2>/dev/null || echo unknown)

STAGE_ONLY=0
[[ ${1:-} == --stage-only ]] && STAGE_ONLY=1

log() { printf '\033[1;35m::\033[0m %s\n' "$*"; }
die() { printf 'build.sh: error: %s\n' "$*" >&2; exit 1; }

# bake the repo from tracked files only (git archive at HEAD), so gitignored
# dev cruft (editor / AI-tooling configs, build dirs, ISOs) never ships.
stage_repo() {
  local src=$1 dst=$2
  mkdir -p "$dst"
  git -C "$src" archive --format=tar HEAD | tar -C "$dst" -xf -
}

# 0. preflight.
[[ -f $TUI_DIR/go.mod ]]         || die "installer TUI not found at $TUI_DIR"
[[ -f $BACKEND_DIR/ryoku-install ]] || die "backend not found at $BACKEND_DIR/ryoku-install"
[[ -d $BACKEND_DIR/lib ]]        || die "backend lib not found at $BACKEND_DIR/lib"

# 1. fresh profile copy. profile components only, never build dirs.
log "Staging profile -> $PROFILE_STAGE"
rm -rf "$PROFILE_STAGE"
mkdir -p "$PROFILE_STAGE"
for item in profiledef.sh packages.x86_64 pacman.conf airootfs efiboot syslinux; do
  cp -a "$PROFILE_DIR/$item" "$PROFILE_STAGE/"
done
AIROOTFS=$PROFILE_STAGE/airootfs

# reproducible package set (opt-in). the default build pulls whatever the live
# mirrors currently serve, so two builds weeks apart differ by upstream package
# churn. RYOKU_ISO_REPRO=1 repoints the STAGED pacman.conf's [core]/[extra] at
# the Arch Linux Archive snapshot dated from the commit, freezing the exact
# package versions baked into the image. reproducible here means frozen, not
# latest: turn it on only to reproduce a specific historical ISO.
if [[ ${RYOKU_ISO_REPRO:-0} == 1 ]]; then
  ala_date=$(date -u --date="@$SOURCE_DATE_EPOCH" +%Y/%m/%d)
  log "RYOKU_ISO_REPRO=1: pinning [core]/[extra] to archive.archlinux.org/$ala_date"
  sed -i "s|^Include = /etc/pacman.d/mirrorlist|Server = https://archive.archlinux.org/repos/$ala_date/\$repo/os/\$arch|" \
    "$PROFILE_STAGE/pacman.conf"
fi

# 2. build the installer TUI from source. live env has no Go toolchain;
#    the ISO carries the prebuilt binary.
command -v go >/dev/null 2>&1 || die "go is required to build the TUI (pacman -S go)"
log "Building ryoku-tui from $TUI_DIR"
install -d "$AIROOTFS/usr/local/bin"
( cd "$TUI_DIR" && CGO_ENABLED=0 go build -trimpath -ldflags '-s -w -buildid=' -o "$AIROOTFS/usr/local/bin/ryoku-tui" . )

# 3. bake the backend + its lib under /usr/local/lib/ryoku/backend.
#    /usr/local/bin/ryoku-install (overlay) execs the real script; the script
#    finds its lib next to itself via realpath, so they stay together.
log "Installing backend -> /usr/local/lib/ryoku/backend"
install -d "$AIROOTFS/usr/local/lib/ryoku/backend"
install -m0755 "$BACKEND_DIR/ryoku-install" "$AIROOTFS/usr/local/lib/ryoku/backend/ryoku-install"
cp -a "$BACKEND_DIR/lib" "$AIROOTFS/usr/local/lib/ryoku/backend/lib"

# 4. bake the repo payload at /usr/share/ryoku (RYOKU_REPO).
log "Baking repo payload -> /usr/share/ryoku"
stage_repo "$REPO_ROOT" "$AIROOTFS/usr/share/ryoku"

# provenance stamp. records the exact commit + version baked into this payload
# so the target's deploy step can flag drift from the live [ryoku] repo. keep
# the format greppable (key=value); iso-stage-check.sh strips it before diffing.
cat >"$AIROOTFS/usr/share/ryoku/.payload" <<EOF
commit=$PAYLOAD_COMMIT
date=$PAYLOAD_DATE
version=$PAYLOAD_VERSION
EOF

# fill the motd placeholders on the STAGED copy only (the committed motd keeps
# the @...@ tokens), so the live shell greets with the baked version + commit.
sed -i \
  -e "s|@RYOKU_VERSION@|$PAYLOAD_VERSION|g" \
  -e "s|@RYOKU_COMMIT@|${PAYLOAD_COMMIT:0:12}|g" \
  "$AIROOTFS/etc/motd"

# 4b. ryoku-shell daemon (Go). same as the TUI: neither the ISO nor the
#     target has a Go toolchain, so it ships prebuilt inside the payload for
#     the deploy step.
log "Building ryoku-shell from $REPO_ROOT/ryoku/shell/ipc"
install -d "$AIROOTFS/usr/share/ryoku/ryoku/shell/ipc"
( cd "$REPO_ROOT/ryoku/shell/ipc" && CGO_ENABLED=0 go build -trimpath -ldflags '-s -w -buildid=' -o "$AIROOTFS/usr/share/ryoku/ryoku/shell/ipc/ryoku-shell" . )

# 4d. ryoku-hub backend (Go), same prebuilt model as ryoku-shell.
log "Building ryoku-hub from $REPO_ROOT/ryoku/hub/backend"
install -d "$AIROOTFS/usr/share/ryoku/ryoku/hub/backend"
( cd "$REPO_ROOT/ryoku/hub/backend" && CGO_ENABLED=0 go build -trimpath -ldflags '-s -w -buildid=' -o "$AIROOTFS/usr/share/ryoku/ryoku/hub/backend/ryoku-hub" . )

# 4c. prebuild the Ryoku.Blobs QML plugin (the frame's blob renderer) into
#     the payload, same model as ryoku-shell. target has no build toolchain;
#     build deps live on the build host only.
command -v cmake >/dev/null 2>&1 || die "cmake is required to build the Ryoku.Blobs plugin (pacman -S cmake ninja qt6-shadertools)"
command -v ninja >/dev/null 2>&1 || die "ninja is required to build the Ryoku.Blobs plugin (pacman -S cmake ninja)"
log "Building Ryoku.Blobs plugin from $REPO_ROOT/ryoku/shell/plugin"
RYOKU_BLOBS_BUILD="$STAGE_DIR/blobs-build" \
  "$REPO_ROOT/ryoku/shell/plugin/build.sh" \
  "$AIROOTFS/usr/share/ryoku/ryoku/shell/plugin/dist"

# 5. keep the staged launchers executable. profiledef file_permissions also
#    sets these at build time, but this keeps the staged tree consistent now.
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

# 6. assemble. mkarchiso needs root + the archiso package.
if ! command -v mkarchiso >/dev/null 2>&1; then
  cat >&2 <<EOF

build.sh: mkarchiso not found. Install the 'archiso' package, then build the
staged profile as root:

  sudo --preserve-env=SOURCE_DATE_EPOCH mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_STAGE"

or, equivalently, from inside the staged profile:

  cd "$PROFILE_STAGE" && sudo --preserve-env=SOURCE_DATE_EPOCH mkarchiso -v -w work -o out .

EOF
  exit 1
fi

log "Running mkarchiso (requires root)"
install -d "$OUT_DIR"
# default sudoers env_reset drops SOURCE_DATE_EPOCH, so a non-root local build
# would silently lose the reproducibility anchor; --preserve-env carries it in.
if [[ $EUID -eq 0 ]]; then
  mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_STAGE"
else
  sudo --preserve-env=SOURCE_DATE_EPOCH mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_STAGE"
fi

# Broadcom sanity. broadcom-wl ships a precompiled wl.ko matched to one exact
# linux ABI. A [core]/[extra] mirror-sync window can pair a `linux` from one
# snapshot with a `broadcom-wl` built against another, so the module lands under
# a kernel dir the live image never boots: modprobe finds nothing at `uname -r`
# and Broadcom BCM43xx laptops lose live Wi-Fi with no error. The live set ships
# exactly one kernel, so require exactly one kernel module dir and prove wl.ko
# sits in it. Guarded on the mkarchiso work airootfs existing.
for wl_modroot in "$WORK_DIR"/*/airootfs/usr/lib/modules; do
  [[ -d $wl_modroot ]] || continue
  mapfile -t _kdirs < <(find "$wl_modroot" -mindepth 1 -maxdepth 1 -type d | sort)
  _wl_kdirs=()
  for _kd in "${_kdirs[@]}"; do
    compgen -G "$_kd/extramodules/wl.ko*" >/dev/null 2>&1 && _wl_kdirs+=("$_kd")
  done
  if (( ${#_kdirs[@]} != 1 || ${#_wl_kdirs[@]} != 1 )); then
    die "Broadcom wl.ko kernel mismatch: ${#_kdirs[@]} kernel module dir(s), ${#_wl_kdirs[@]} carrying extramodules/wl.ko* under $wl_modroot. A [core]/[extra] mirror-sync window baked broadcom-wl against a kernel this ISO does not ship, so Broadcom Wi-Fi would fail silently. Rebuild once 'pacman -Syu' has settled (or pin versions with RYOKU_ISO_REPRO=1)."
  fi
done
log "ISO written to $OUT_DIR"

# checksums next to the ISO for verification. deterministic for a fixed commit,
# since the ISO is (see README.md, "Reproducibility"). a missing *.iso here is a
# real mkarchiso failure, so let the glob stay literal and fail loudly.
log "Writing SHA256SUMS"
( cd "$OUT_DIR" && sha256sum -- *.iso >SHA256SUMS )
