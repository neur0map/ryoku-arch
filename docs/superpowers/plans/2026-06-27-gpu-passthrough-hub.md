# Ryoku Hub GPU page - Implementation Plan

> **For agentic workers:** Use superpowers:subagent-driven-development or
> superpowers:executing-plans. Steps use checkbox (`- [ ]`) tracking.

**Goal:** Add a System → GPU page to Ryoku Hub for graphics-mode switching and a
Looking-Glass Windows 11 passthrough VM, gated by a rigorous capability engine.

**Architecture:** Go logic in `ryoku-hub` (`gpu`/`vm` subcommands) over a read-only
capability engine and a libvirt domain-XML generator; privileged enable/bind via
pkexec + a libvirt hook; QML page in the Profile idiom; a "Ryoku VM" launcher entry.

**Tech Stack:** Go 1.26 (stdlib + BurntSushi/toml), QML/Quickshell, libvirt+QEMU,
OVMF, swtpm, Looking Glass (kvmfr), pkexec/polkit, bash for `ryoku-gpu-detect`.

## Global Constraints

- Go module `ryoku-hub` (`ryoku/hub/backend`); build `go build -o ryoku-hub .`.
- All backend data to QML is JSON on stdout; atomic file writes (temp+rename).
- Reads unprivileged; privilege only via `pkexec ryoku-hub gpu apply ...`.
- No destructive action unless the capability verdict permits it.
- No boot-time vfio binding; dynamic bind/unbind via libvirt hook only.
- Reuse `ryoku-gpu-detect` as the single GPU-enumeration source.
- Commit subjects start with `[ryoku]` / `[system]` / `[docs]`; no em-dash; pass hooks.
- Capability engine reads sysfs under `RYOKU_SYSFS_ROOT` (default `/`) for tests.

---

## Phase 1 - Enumeration JSON + capability engine (safety gate)

### Task 1.1: `ryoku-gpu-detect` JSON + iommu_group
**Files:** Modify `system/hardware/gpu/ryoku-gpu-detect`; Modify
`system/hardware/gpu/ryoku-gpu` (add `detect --json`); Test:
`system/hardware/gpu/ryoku-gpu-detect.test` (bats-free shell asserts).
**Produces:** `ryoku-gpu detect --json` → `[{slot,class,driver,vram,connected,
model,iommu_group,boot_vga}]`.
**Acceptance:** JSON parses; each record has `iommu_group` (int) read from
`<sysfs>/bus/pci/devices/<slot>/iommu_group` basename; TSV output unchanged;
honors `DRM_ROOT`.

### Task 1.2: Capability engine
**Files:** Create `ryoku/hub/backend/hwcaps.go`; Test
`ryoku/hub/backend/hwcaps_test.go`; fixtures under
`ryoku/hub/backend/testdata/caps/<scenario>/`.
**Interfaces (Produces):**
```
func DetectCapability() (Capability, error)
type Capability struct { Chassis, Mux string; Host, Passthrough GPU;
  Strategy, Verdict string; Checks []Check; RamTotalMB, RamFreeMB int }
type GPU struct { Slot,Vendor,Model,Driver,Class string; IommuGroup int;
  DrivesDisplay,GroupIsolated bool; Functions []string }
type Check struct { ID,Level,Label,Value,Hint string }
```
**Checks:** cpu-virt (`/proc/cpuinfo` svm|vmx), kvm (`/dev/kvm`), iommu
(`/sys/kernel/iommu_groups`), two-gpus, iommu-isolation, display-owner
(`/sys/class/drm/card*-*/status`), ram, disk, tooling-*.
**Strategy/Verdict:** per the spec handoff table.
**Acceptance:** fixture scenarios desktop-dual→ready/live-bind,
laptop-hybrid→ready/live-bind, laptop-mux-dgpu→needs-reboot/mux-reboot,
single-gpu→incapable/none, intel-iommu-off→needs-setup, no-virt→incapable.
`go test ./...` passes.

### Task 1.3: `gpu caps` subcommand
**Files:** Create `ryoku/hub/backend/gpu.go` (dispatch + `caps`); Modify
`ryoku/hub/backend/main.go` (add `gpu` case + usage).
**Produces:** `ryoku-hub gpu caps` → Capability JSON on stdout.
**Acceptance:** runs on dev box, emits valid JSON; `go vet` clean.

---

## Phase 2 - GPU mode control

### Task 2.1: `ryoku-gpu` explicit primary
**Files:** Modify `system/hardware/gpu/ryoku-gpu` (add `persist --primary <slot>`
and `mode <hybrid|performance|passthrough>` thin wrappers over existing
persist/disable). 
**Acceptance:** `ryoku-gpu persist --primary <igpu-slot>` writes a `gpu.lua`
pinning that slot first; `disable` still resets; dry-run via stdout (`-`).

### Task 2.2: `gpu mode` subcommand
**Files:** Modify `ryoku/hub/backend/gpu.go`; Test `gpu_test.go`.
**Produces:** `ryoku-hub gpu mode get` → `{mode,cost}`; `... mode set <m>` →
applies via `ryoku-gpu`, returns `{cost: live|relogin|reboot}`.
**Acceptance:** set hybrid/performance/passthrough call the right `ryoku-gpu`
path; cost computed from capability strategy; unit test with a stubbed `ryoku-gpu`
via `RYOKU_GPU_BIN` seam.

---

## Phase 3 - VM model + libvirt XML

### Task 3.1: VM config store
**Files:** Create `ryoku/hub/backend/vm.go` (`get`/`save`); Modify `main.go`
(`vm` case). Test `vm_test.go`.
**Produces:** `VM` struct (spec §5); `ryoku-hub vm get|save` ↔
`~/.config/ryoku/vm.json` (atomic). Defaults: name `ryoku-win11`, 4 cores,
8192 MB, 64 GB disk, display `looking-glass`.
**Acceptance:** round-trip save/get; missing file → defaults; honors
`RYOKU_CONFIG_BASE` seam.

### Task 3.2: Domain XML generator
**Files:** Create `ryoku/hub/backend/vmxml.go`; Test `vmxml_test.go`; golden
`testdata/xml/windows11.xml`, `testdata/xml/linux.xml`.
**Produces:** `func RenderDomain(vm VM, cap Capability) (string, error)`.
**Details:** q35, host-passthrough CPU, hyperv + `kvm` hidden state + `vendor_id`;
OVMF secure-boot + swtpm (windows); virtio disk/net + virtio-win CDROM (windows);
`<hostdev managed='no'>` for `cap.Passthrough` + each `Functions` entry; kvmfr
ivshmem size = next-pow2(W*H*4*2/1MiB+10) min 128; memballoon off.
**Acceptance:** golden XML match; size math unit-tested (2560x1600→128); hostdev
includes the dGPU audio function.

### Task 3.3: kvmfr size + helper math
**Files:** Modify `vmxml.go` (exported `KvmfrSizeMB(w,h int) int`); test.
**Acceptance:** 1920x1080→64? (32+10→64); 2560x1600→128; 3840x2160→256.

---

## Phase 4 - Passthrough enable/disable + hook + orchestration

### Task 4.1: privileged `gpu apply`
**Files:** Modify `ryoku/hub/backend/gpu.go` (`apply enable|disable
[--dry-run]`); Create `ryoku/hub/backend/gpuapply.go`. 
**Behaviour:** spec §6. Re-exec under pkexec when not root (lock.go pattern);
resolve user via `PKEXEC_UID`. Idempotent `/etc` writes; `disable` reverts.
**Acceptance:** `--dry-run` prints each planned change and writes nothing
(unit-testable with a `RYOKU_ETC_ROOT` seam + fake pacman).

### Task 4.2: libvirt hook + bind/unbind
**Files:** Modify `gpuapply.go` (installs `/etc/libvirt/hooks/qemu`); Create
`ryoku/hub/backend/gpuhook.go` (`gpu hook <prepare|release> <vmname>`).
**Behaviour:** prepare → disable NVIDIA persistence, unbind dGPU group from host
driver, bind vfio-pci (direct sysfs); release → rebind host driver. Only acts for
the Ryoku VM name and only on the capability `Passthrough` group.
**Acceptance:** dry-run/seam test of the sysfs path sequence; refuses if the group
drives the display.

### Task 4.3: launch/stop orchestration
**Files:** Modify `vm.go` (`define`, `launch`, `stop`, `status`).
**Behaviour:** spec §7. `launch` re-reads caps, refuses unless `ready`, virsh
start, modprobe kvmfr, spawn looking-glass-client; non-ready → actionable message,
non-zero exit.
**Acceptance:** `status` returns `{defined,running,verdict}` JSON; launch on a
non-ready box prints the required action and exits non-zero (testable).

---

## Phase 5 - Hub GPU page (QML, Profile idiom)

### Task 5.1: GpuPage + GpuCard
**Files:** Create `ryoku/hub/quickshell/GpuPage.qml`,
`ryoku/hub/quickshell/GpuCard.qml`; Modify `ryoku/hub/quickshell/Hub.qml`
(sectionDefs, pageMeta, pageFor, Component).
**Details:** ShowcaseBackdrop + GpuCard hero (iGPU/dGPU + verdict badge) + dossier
(`SpecRow` per Check) + `Segmented` Graphics/VM. Process+StdioCollector JSON.
**Acceptance:** page registers under System; `qmllint` clean (or hub launches);
reads `ryoku-hub gpu caps`.

### Task 5.2: Graphics segment (mode + enable)
**Files:** Modify `GpuPage.qml`.
**Details:** mode `ChoiceRow`, Apply with cost text, "Enable passthrough" showing
dry-run plan then `pkexec ryoku-hub gpu apply enable`.
**Acceptance:** mode set calls backend; enable shows plan; disabled-state reasons
shown when not capable.

### Task 5.3: Virtual Machine segment
**Files:** Modify `GpuPage.qml`.
**Details:** ISO picker, guest type, cores/RAM/disk fields, Create/Save, Launch.
Segment disabled with inline reason until verdict allows + passthrough enabled.
**Acceptance:** save persists vm.json; Launch calls `ryoku-hub vm launch`.

---

## Phase 6 - Launcher + packaging + deploy

### Task 6.1: launcher entry + window rule
**Files:** Create `ryoku/apps/ryoku-vm/ryoku-vm.desktop`; Modify
`ryoku/hyprland/modules/window_rules.lua` (looking-glass-client float).
**Acceptance:** desktop entry valid; window rule matches `looking-glass-client`.

### Task 6.2: packaging + deploy + changelogs
**Files:** Modify `release/packages/ryoku-desktop/PKGBUILD` (optdepends + install
.desktop), `ryoku/shell/deploy.sh` (install .desktop), `ryoku/CHANGELOG.md`,
`system/hardware/CHANGELOG.md`.
**Acceptance:** deploy installs the entry; optdepends list qemu/libvirt/ovmf/
swtpm/looking-glass; changelogs entered.

---

## Self-review

- Spec coverage: every spec §1–10 maps to a task above.
- No placeholders: each task has files, interfaces, acceptance.
- Type consistency: `Capability`/`GPU`/`Check`/`VM` names identical across tasks.
- Verification reality: live vfio/VM boot is implemented + dry-run-tested, not
  executed on the dev box (would black-screen it); stated in spec §Testing.
