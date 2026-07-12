#!/usr/bin/env bash
# hermetic test for ryoku-gpu-lib32: the loaded DRM driver of every GPU maps to
# the right 32-bit package on a lib32-mesa + lib32-vulkan-icd-loader baseline,
# a hybrid box gets both vendor ICDs (Mesa once), and a GPU-less box gets the
# baseline only. Uses a fake /sys DRM tree (RYOKU_GPU_DRM_ROOT) and dry-run, so
# nothing installs; no pacman, no network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
cmd="$here/../system/hardware/gpu/ryoku-gpu-lib32"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# pacman.conf with multilib enabled, so the repo check passes without a mutation.
conf="$tmp/pacman.conf"
printf '[multilib]\nInclude = /dev/null\n' >"$conf"

# fabricate a DRM card whose device uevent reports a given kernel driver.
mk_card() { # <drm-root> <cardN> <driver>
  local d="$1/$2/device"
  mkdir -p "$d"
  printf 'DRIVER=%s\nPCI_SLOT_NAME=0000:0%s:00.0\n' "$3" "${2#card}" >"$d/uevent"
}

plan() { # <drm-root> -> the dry-run pacman line
  RYOKU_DRYRUN=1 RYOKU_PACMAN_CONF="$conf" RYOKU_GPU_DRM_ROOT="$1" bash "$cmd" 2>&1
}

# --- AMD: radeon ICD, no other vendor ----------------------------------------
root="$tmp/amd"; mk_card "$root" card0 amdgpu
out="$(plan "$root")"
grep -q 'lib32-mesa' <<<"$out" || fail "amd: missing lib32-mesa baseline"
grep -q 'lib32-vulkan-icd-loader' <<<"$out" || fail "amd: missing loader baseline"
grep -q 'lib32-vulkan-radeon' <<<"$out" || fail "amd: missing lib32-vulkan-radeon"
grep -qE 'lib32-vulkan-intel|lib32-nvidia-utils' <<<"$out" && fail "amd: wrong-vendor package planned"

# --- Intel: anv ICD ----------------------------------------------------------
root="$tmp/intel"; mk_card "$root" card0 i915
grep -q 'lib32-vulkan-intel' <<<"$(plan "$root")" || fail "intel: missing lib32-vulkan-intel"

# --- NVIDIA proprietary: lib32-nvidia-utils ----------------------------------
root="$tmp/nvidia"; mk_card "$root" card0 nvidia
grep -q 'lib32-nvidia-utils' <<<"$(plan "$root")" || fail "nvidia: missing lib32-nvidia-utils"

# --- hybrid Intel iGPU + NVIDIA dGPU: both ICDs, Mesa deduped -----------------
root="$tmp/hybrid"; mk_card "$root" card0 i915; mk_card "$root" card1 nvidia
out="$(plan "$root")"
grep -q 'lib32-vulkan-intel' <<<"$out" || fail "hybrid: missing intel ICD"
grep -q 'lib32-nvidia-utils' <<<"$out" || fail "hybrid: missing nvidia ICD"
line="$(grep -E 'DRYRUN: .*pacman -Syu' <<<"$out")"
[ "$(grep -o 'lib32-mesa' <<<"$line" | wc -l)" -eq 1 ] || fail "hybrid: lib32-mesa not deduped"

# --- no GPU (VM): baseline only ----------------------------------------------
root="$tmp/none"; mkdir -p "$root"
out="$(plan "$root")"
grep -q 'lib32-mesa' <<<"$out" || fail "none: missing baseline mesa"
grep -qi 'baseline only' <<<"$out" || fail "none: missing baseline-only notice"
grep -qE 'lib32-vulkan-(radeon|intel|nvidia)' <<<"$out" && fail "none: a vendor ICD leaked in"

# --- multilib off: refuses with guidance -------------------------------------
# stub the enabler as a no-op so the repo stays "off" and nothing real is
# touched (ryoku-pkg-multilib edits the host /etc/pacman.conf), keeping this
# hermetic whatever the dev box's real multilib state is.
offconf="$tmp/pacman-noml.conf"; printf '[core]\nInclude = /dev/null\n' >"$offconf"
fakebin="$tmp/bin"; mkdir -p "$fakebin"
printf '#!/usr/bin/env bash\nexit 0\n' >"$fakebin/ryoku-pkg-multilib"; chmod +x "$fakebin/ryoku-pkg-multilib"
root="$tmp/amd"
if RYOKU_PACMAN_CONF="$offconf" RYOKU_GPU_DRM_ROOT="$root" PATH="$fakebin:/usr/bin:/bin" bash "$cmd" >/dev/null 2>&1; then
  fail "multilib off: should have exited non-zero"
fi

echo "gpu-lib32: all checks passed"
