#!/bin/bash
# Guards ryoku-gpu's multi-GPU detection: on a desktop with a strong discrete GPU
# beside a weak integrated one, the discrete GPU must be picked as Hyprland's
# primary render device (AQ_DRM_DEVICES), the display-bearing GPU must stay in the
# list (so a monitor on the iGPU still works via reverse PRIME), and single-GPU or
# laptop machines must be left alone. Detection runs against a synthesized DRM
# tree so it needs no real hardware.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GPU="$ROOT_DIR/bin/ryoku-gpu"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ -x $GPU ]] || fail "bin/ryoku-gpu is missing or not executable"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# make_card <card> <pci-slot> <driver> [vram-bytes] [vis-vram-bytes] [removable]
make_card() {
  local d="$DRM/$1"
  mkdir -p "$d/device"
  {
    printf 'DRIVER=%s\n' "$3"
    printf 'PCI_SLOT_NAME=%s\n' "$2"
  } >"$d/device/uevent"
  [[ -n ${4:-} ]] && printf '%s\n' "$4" >"$d/device/mem_info_vram_total"
  [[ -n ${5:-} ]] && printf '%s\n' "$5" >"$d/device/mem_info_vis_vram_total"
  [[ -n ${6:-} ]] && printf '%s\n' "$6" >"$d/device/removable"
  return 0
}

# make_conn <card> <connector> <status>
make_conn() {
  local d="$DRM/$1-$2"
  mkdir -p "$d"
  printf '%s\n' "$3" >"$d/status"
}

fresh_drm() {
  DRM="$WORK/drm-$RANDOM"
  mkdir -p "$DRM"
}

run_gpu() {
  RYOKU_GPU_DRM_ROOT="$DRM" \
    RYOKU_GPU_DRI_DIR="${DRI:-/dev/dri}" \
    RYOKU_GPU_HYPR_DIR="${HYPRD:-$WORK/hypr}" \
    RYOKU_GPU_UWSM_ENV="$WORK/uwsm/env-hyprland" \
    RYOKU_GPU_UDEV_RULE="${RULE:-$WORK/udev.rules}" \
    RYOKU_GPU_SKIP_UDEVADM=1 \
    RYOKU_GPU_ASSUME_DESKTOP="${ASSUME_DESKTOP:-1}" \
    "$GPU" "$@"
}

GiB=$((1024 * 1024 * 1024))

# ── 1. desktop dGPU(24G) + iGPU(512M, monitor) -> dGPU primary, iGPU kept ─────
fresh_drm
make_card card1 "0000:03:00.0" amdgpu $((24 * GiB))         # discrete RX 7900 XTX
make_card card2 "0000:13:00.0" amdgpu $((512 * 1024 * 1024)) # integrated Raphael
make_conn card1 DP-1 disconnected
make_conn card2 DP-5 connected                               # monitor on the iGPU

order="$(run_gpu order)" || fail "order should succeed on dGPU+iGPU desktop"
want="/dev/dri/ryoku-gpu-0000-03-00-0:/dev/dri/ryoku-gpu-0000-13-00-0"
[[ $order == "$want" ]] \
  || fail "expected dGPU-first AQ value '$want', got '$order'"
[[ $order == *"ryoku-gpu-0000-13-00-0"* ]] \
  || fail "display-bearing iGPU must stay in the list (reverse PRIME), got '$order'"

det="$(run_gpu detect)" || fail "detect should succeed on dGPU+iGPU desktop"
grep -q "Recommended primary render GPU: 0000:03:00.0" <<<"$det" \
  || fail "detect should recommend the discrete GPU (0000:03:00.0) as primary"

# check must report needs-persist (exit 1), not not-applicable (2), when a
# beneficial reorder exists but no gpu.conf has been written yet.
set +e
run_gpu check
rc=$?
set -e
(( rc == 1 )) \
  || fail "check must exit 1 (applicable, unconfigured) when gpu.conf is absent, got $rc"

# ── 2. single discrete GPU -> nothing to do ───────────────────────────────────
fresh_drm
make_card card1 "0000:03:00.0" amdgpu $((24 * GiB))
make_conn card1 DP-1 connected
if run_gpu order >/dev/null 2>&1; then
  fail "single-GPU machine must not request a reorder"
fi

# ── 3. NVIDIA dGPU (no VRAM file) + Intel iGPU -> NVIDIA primary ───────────────
fresh_drm
make_card card0 "0000:01:00.0" nvidia                       # dGPU, no DRM VRAM file
make_card card1 "0000:00:02.0" i915 0                        # Intel iGPU
make_conn card1 HDMI-A-1 connected
order="$(run_gpu order)" || fail "order should succeed on NVIDIA+Intel desktop"
[[ $order == "/dev/dri/ryoku-gpu-0000-01-00-0:"* ]] \
  || fail "NVIDIA dGPU must be primary even with no VRAM file, got '$order'"

# ── 4. laptop (battery present) -> leave Hyprland's iGPU-first default alone ───
fresh_drm
make_card card0 "0000:01:00.0" nvidia $((8 * GiB))
make_card card1 "0000:00:02.0" i915 0
make_conn card1 eDP-1 connected
if ASSUME_DESKTOP=0 run_gpu order >/dev/null 2>&1; then
  fail "laptop (no desktop) must not force the discrete GPU as primary"
fi

# ── 5. persist writes gpu.conf + source line; falls back to cardN nodes ────────
fresh_drm
make_card card1 "0000:03:00.0" amdgpu $((24 * GiB))
make_card card2 "0000:13:00.0" amdgpu $((512 * 1024 * 1024))
make_conn card2 DP-5 connected

HYPRD="$WORK/hypr"
mkdir -p "$HYPRD"
cat >"$HYPRD/hyprland.conf" <<'EOF'
source = ~/.config/hypr/colors.conf
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/keyboard.conf
source = ~/.config/hypr/custom.conf
EOF
# No /dev/dri symlinks exist (DRI points at a temp dir with cardN nodes), so
# persist must fall back to the resolved card nodes rather than write a broken
# config that references non-existent stable symlinks.
DRI="$WORK/dri"
mkdir -p "$DRI"
: >"$DRI/card1"
: >"$DRI/card2"

run_gpu persist >/dev/null || fail "persist should succeed"
[[ -f $HYPRD/gpu.conf ]] || fail "persist must create gpu.conf"
grep -q "^# ryoku-gpu-primary: 0000:03:00.0" "$HYPRD/gpu.conf" \
  || fail "gpu.conf must record the discrete GPU as the pinned primary"
grep -Eq "^env = AQ_DRM_DEVICES,$DRI/card1:$DRI/card2$" "$HYPRD/gpu.conf" \
  || fail "persist must fall back to dGPU-first card nodes; got: $(grep AQ_DRM "$HYPRD/gpu.conf")"
grep -qxF "cursor:no_hardware_cursors = true" "$HYPRD/gpu.conf" \
  || fail "persist must disable HW cursors on multi-GPU (reverse PRIME breaks the cursor plane)"
grep -qxF "source = ~/.config/hypr/gpu.conf" "$HYPRD/hyprland.conf" \
  || fail "persist must add the gpu.conf source line to hyprland.conf"

# gpu.conf must be sourced before custom.conf so user overrides win.
gpu_ln="$(grep -n 'gpu.conf' "$HYPRD/hyprland.conf" | head -n1 | cut -d: -f1)"
custom_ln="$(grep -n 'custom.conf' "$HYPRD/hyprland.conf" | head -n1 | cut -d: -f1)"
(( gpu_ln < custom_ln )) \
  || fail "gpu.conf must be sourced before custom.conf (got gpu=$gpu_ln custom=$custom_ln)"

# persist must be idempotent: a second run must not duplicate the source line.
run_gpu persist >/dev/null || fail "second persist should succeed"
(( $(grep -cF "source = ~/.config/hypr/gpu.conf" "$HYPRD/hyprland.conf") == 1 )) \
  || fail "persist must not duplicate the source line"

# check must now report 'already pinned' (exit 0).
run_gpu check || fail "check should report already-pinned (exit 0) after persist"

# disable must clear the pin and flip check to 'needs persist' (exit 1).
run_gpu disable >/dev/null || fail "disable should succeed"
# the cross-GPU cursor override is conditional: disable must drop it so single-GPU
# machines keep hardware cursors.
if grep -q "cursor:no_hardware_cursors" "$HYPRD/gpu.conf"; then
  fail "disable must not leave the HW-cursor override behind (single-GPU keeps HW cursors)"
fi
if run_gpu check; then
  fail "check should report needs-persist (exit 1) after disable"
fi

# ── 6. install-udev writes the rule + session symlinks; persist prefers them ──
fresh_drm
make_card card1 "0000:03:00.0" amdgpu $((24 * GiB))
make_card card2 "0000:13:00.0" amdgpu $((512 * 1024 * 1024))
make_conn card2 DP-5 connected

DRI="$WORK/dri6"
HYPRD="$WORK/hypr6"
RULE="$WORK/udev6.rules"
mkdir -p "$DRI" "$HYPRD"
: >"$DRI/card1"   # dGPU device node (symlink target)
: >"$DRI/card2"   # iGPU device node
: >"$HYPRD/hyprland.conf"

run_gpu install-udev >/dev/null || fail "install-udev should succeed"
grep -q 'KERNELS=="0000:03:00.0"' "$RULE" \
  || fail "udev rule must match the dGPU PCI slot"
grep -q 'SYMLINK+="dri/ryoku-gpu-0000-03-00-0"' "$RULE" \
  || fail "udev rule must create the stable dGPU symlink"
[[ -L $DRI/ryoku-gpu-0000-03-00-0 ]] \
  || fail "install-udev must materialise the current-session dGPU symlink (no udevadm trigger)"
[[ "$(readlink "$DRI/ryoku-gpu-0000-03-00-0")" == "card1" ]] \
  || fail "dGPU symlink must point at the dGPU card node (card1)"

run_gpu persist >/dev/null || fail "persist after install-udev should succeed"
grep -Eq "^env = AQ_DRM_DEVICES,$DRI/ryoku-gpu-0000-03-00-0:$DRI/ryoku-gpu-0000-13-00-0$" "$HYPRD/gpu.conf" \
  || fail "persist must use stable symlink paths once they exist; got: $(grep AQ_DRM "$HYPRD/gpu.conf")"
unset RULE

# ── 7. Lua mode: persist writes gpu.lua + require("gpu") into hyprland.lua ─────
# When the box has migrated to native Lua (hyprland.lua present), persist must
# emit the Lua-format pin (gpu.lua with hl.env/hl.config) and ensure the entry
# point require()s it, instead of the hyprlang gpu.conf + source line.
fresh_drm
make_card card1 "0000:03:00.0" amdgpu $((24 * GiB))
make_card card2 "0000:13:00.0" amdgpu $((512 * 1024 * 1024))
make_conn card2 DP-5 connected

DRI="$WORK/dri7"
HYPRD="$WORK/hypr7"
mkdir -p "$DRI" "$HYPRD"
: >"$DRI/card1"
: >"$DRI/card2"
printf 'require("custom")\n' >"$HYPRD/hyprland.lua"

run_gpu persist >/dev/null || fail "persist should succeed in Lua mode"
[[ -f $HYPRD/gpu.lua ]] || fail "persist must create gpu.lua when hyprland.lua is present"
grep -qF 'hl.env("AQ_DRM_DEVICES",' "$HYPRD/gpu.lua" \
  || fail "gpu.lua must pin AQ_DRM_DEVICES via hl.env"
grep -qF 'no_hardware_cursors = true' "$HYPRD/gpu.lua" \
  || fail "gpu.lua must disable HW cursors on multi-GPU (reverse PRIME breaks the cursor plane)"
grep -qF 'require("gpu")' "$HYPRD/hyprland.lua" \
  || fail "persist must add require(\"gpu\") to hyprland.lua instead of a source line"
unset DRI HYPRD

# ── 8. AMD APU (4 GiB fully-visible UMA) beside an NVIDIA dGPU -> NVIDIA primary ─
# The APU's whole VRAM is CPU-visible (vis == total), so it must rank as integrated
# and never outrank the NVIDIA dGPU (which reports no sysfs VRAM in the fake tree).
fresh_drm
make_card card0 "0000:01:00.0" nvidia                          # dGPU, no DRM VRAM file
make_card card1 "0000:65:00.0" amdgpu $((4 * GiB)) $((4 * GiB)) # APU: vram == vis == 4 GiB
make_conn card1 eDP-1 connected
order="$(run_gpu order)" || fail "order should succeed on NVIDIA + AMD-APU desktop"
[[ $order == "/dev/dri/ryoku-gpu-0000-01-00-0:"* ]] \
  || fail "NVIDIA dGPU must outrank a 4 GiB-UMA APU, got '$order'"
det="$(run_gpu detect)" || fail "detect should succeed"
grep -q "0000:65:00.0  integrated" <<<"$det" \
  || fail "a fully-visible 4 GiB UMA carveout must classify as integrated, got: $det"

# ── 9. eGPU (removable) on a laptop -> auto-pin it despite the iGPU-first default ─
fresh_drm
make_card card0 "0000:00:02.0" i915 0                                  # Intel iGPU
make_card card1 "0000:0c:00.0" amdgpu $((16 * GiB)) "" removable       # external GPU
make_conn card0 eDP-1 connected
order="$(ASSUME_DESKTOP=0 run_gpu order)" \
  || fail "an eGPU must be auto-pinned even on a laptop (battery default does not apply)"
[[ $order == "/dev/dri/ryoku-gpu-0000-0c-00-0:"* ]] \
  || fail "the eGPU must be the primary in the AQ list, got '$order'"

# ── 10. manual slot pin forces a GPU on a laptop (auto would bail there) ───────
fresh_drm
make_card card0 "0000:01:00.0" nvidia $((8 * GiB))   # dGPU
make_card card1 "0000:00:02.0" i915 0                # Intel iGPU
make_conn card1 eDP-1 connected
DRI="$WORK/dri10"
HYPRD="$WORK/hypr10"
mkdir -p "$DRI" "$HYPRD"
: >"$DRI/card0"
: >"$DRI/card1"
printf 'require("custom")\n' >"$HYPRD/hyprland.lua"
# auto (no slot) must leave a laptop untouched ...
ASSUME_DESKTOP=0 run_gpu persist >/dev/null || fail "auto persist should succeed (no-op) on a laptop"
[[ ! -f $HYPRD/gpu.lua ]] || fail "auto persist must not pin a GPU on a hybrid laptop"
# ... but an explicit slot forces it even on a laptop.
ASSUME_DESKTOP=0 run_gpu persist "0000:01:00.0" >/dev/null \
  || fail "explicit-slot persist should succeed on a laptop"
[[ -f $HYPRD/gpu.lua ]] || fail "explicit-slot persist must write gpu.lua"
grep -qF -- "-- ryoku-gpu-primary: 0000:01:00.0" "$HYPRD/gpu.lua" \
  || fail "gpu.lua must record the user-chosen dGPU as primary"
grep -Eq "hl\.env\(\"AQ_DRM_DEVICES\", \"$DRI/card0:$DRI/card1\"\)" "$HYPRD/gpu.lua" \
  || fail "chosen GPU must lead the AQ list; got: $(grep AQ_DRM "$HYPRD/gpu.lua")"
# an unknown slot must be rejected.
if ASSUME_DESKTOP=0 run_gpu persist "9999:99:99.9" >/dev/null 2>&1; then
  fail "persist must reject an unknown GPU slot"
fi
unset DRI HYPRD

echo "PASS: gpu-render-primary (detection, ordering, persist, idempotency, gates)"
