# Ryoku Hub GPU page - graphics modes + Windows VM passthrough

Design spec. Status: approved 2026-06-27.

## Goal

Add a **System → GPU** page to Ryoku Hub that lets a user (1) choose how the
machine's GPUs are used (Hybrid / Performance / Passthrough) and (2) configure and
launch a single, Looking-Glass-windowed Windows 11 VM that owns the discrete GPU,
all gated behind a rigorous hardware-capability engine so a misconfiguration can
never strand or black-screen the host. This implements the `vfio` GPU mode the
installer already advertises but left deferred (`installation/tui/main.go:597`).

## Non-goals (v1)

- Single-GPU passthrough (host has only one GPU). Detected and refused: too risky.
- More than one VM, or multiple ISOs at once. The on-disk model is a list so this
  is a clean future add, but the UI exposes exactly one VM.
- macOS guests, nested virtualization, SR-IOV / vGPU partitioning.
- GPU hot-migration between host and guest without any session change. We do the
  cheapest correct handoff per topology and state the cost honestly.

## Vocabulary (reuse the installer's)

The installer offers `offload` / `sync` / `vfio` (`installation/tui/main.go:593`).
The Hub surfaces the same three as user-facing **modes**:

| Hub mode | installer key | Meaning |
| --- | --- | --- |
| Hybrid | `offload` | iGPU drives the display, dGPU on demand (battery). |
| Performance | `sync` | dGPU is Ryoku's primary renderer (`AQ_DRM_DEVICES`). |
| Passthrough | `vfio` | dGPU reserved for the VM; Ryoku runs on the iGPU. |

"Optimize Linux" in the user's words = Hybrid or Performance. "GPU passthrough" =
Passthrough.

## Architecture overview

```
Hub GPU page (QML, Profile idiom)
  -> ryoku-hub gpu  caps|mode|apply|hook        (Go)
  -> ryoku-hub vm   get|save|xml|define|launch|stop|status   (Go)
       -> hwcaps.go   capability engine (read-only, unit-tested)
       -> vmxml.go    libvirt domain XML generator (unit-tested)
       -> orchestrator -> pkexec ryoku-hub gpu apply   (privileged, polkit)
                       -> libvirt (qemu:///system) + QEMU + swtpm + OVMF
                       -> /etc/libvirt/hooks/qemu -> ryoku-hub gpu hook (vfio bind/unbind)
                       -> looking-glass-client (user)
App launcher: "Ryoku VM" .desktop -> ryoku-hub vm launch
```

Single source of GPU enumeration stays `system/hardware/gpu/ryoku-gpu-detect`
(extended with JSON + IOMMU group). The Go engine consumes it and adds the
virtualization-specific checks. No duplicate GPU-detection logic.

## Component design

### 1. GPU enumeration (bash, extend existing)

`system/hardware/gpu/ryoku-gpu-detect` gains a `gpu_records_json` emitter and each
record gains `iommu_group` (read from
`/sys/bus/pci/devices/<slot>/iommu_group` basename) and `boot_vga`
(`/sys/bus/pci/devices/<slot>/boot_vga`). Existing TSV output and test seams
(`DRM_ROOT`, `DRI_DIR`) are preserved. `ryoku-gpu detect --json` exposes it.

### 2. Capability engine (Go: `ryoku/hub/backend/hwcaps.go` + test)

Pure, read-only. Reads sysfs/procfs under a `RYOKU_SYSFS_ROOT` seam (default `/`)
so tests run on fixtures. Consumes `ryoku-gpu detect --json` for the GPU list.
Emits a `Capability` struct as JSON:

```
type Check struct {
    ID    string // "cpu-virt", "kvm", "iommu", "iommu-isolation",
                 // "two-gpus", "display-owner", "ram", "disk", "tooling-*"
    Level string // "ok" | "warn" | "fail"
    Label string // human label for the dossier row
    Value string // detected value ("AMD-Vi on", "group 14: isolated", ...)
    Hint  string // remediation when not ok
}
type GPU struct {
    Slot, Vendor, Model, Driver, Class string // class: integrated|discrete|egpu
    IommuGroup int
    DrivesDisplay bool   // owns a connected, active connector
    GroupIsolated bool   // group holds only this GPU + its own functions
    Functions  []string  // sibling PCI funcs to pass together (e.g. HDMI audio)
}
type Capability struct {
    Chassis     string  // "laptop" | "desktop"
    Mux         string  // "none" | "present-igpu" | "present-dgpu" | "unknown"
    Host        GPU     // the GPU Ryoku should keep
    Passthrough GPU     // the candidate dGPU to hand to the VM
    Strategy    string  // see handoff table below
    Verdict     string  // "ready" | "needs-relogin" | "needs-reboot" |
                        //  "needs-setup" | "incapable"
    Checks      []Check
    RamTotalMB, RamFreeMB int
}
```

Checks performed:

- `cpu-virt`: `svm` (AMD) or `vmx` (Intel) in `/proc/cpuinfo`.
- `kvm`: `/dev/kvm` exists and is accessible.
- `iommu`: `/sys/kernel/iommu_groups` non-empty. If empty and Intel, hint
  `intel_iommu=on`; AMD is usually on by firmware.
- `two-gpus`: at least one integrated/egpu host candidate AND one discrete
  candidate. Otherwise `fail` (single-GPU not supported).
- `iommu-isolation`: the dGPU's IOMMU group contains only the dGPU and its own
  functions (0x...0/0x...1). Otherwise `warn` (ACS/other devices in group).
- `display-owner`: which GPU drives the active display, derived from
  `/sys/class/drm/card*-*/status == connected` joined to the card's PCI driver.
  Drives `Strategy`.
- `ram`/`disk`: enough headroom for host + requested guest.
- `tooling-*`: presence of `qemu-system-x86_64`, `virsh`/`libvirtd`,
  OVMF firmware, `swtpm`, `looking-glass-client`, kvmfr module availability.

### 3. Handoff strategy (the "no reboot if possible" truth)

Derived in the engine, shown verbatim in the UI:

| Detected state | Strategy | Verdict | Launch cost |
| --- | --- | --- | --- |
| Desktop/laptop, host on iGPU, dGPU free | `live-bind` | ready | none - automatic |
| Host currently on the dGPU | `relogin-then-bind` | needs-relogin | logout/login once |
| Laptop, dGPU drives the panel (MUX=dGPU) | `mux-reboot` | needs-reboot | reboot once to flip MUX→hybrid |
| Missing deps / IOMMU off / cmdline | `setup` | needs-setup | one-time enable (maybe reboot) |
| Single GPU / no virt | `none` | incapable | unsupported |

Default handoff (user-chosen 2026-06-27): **fully automatic at launch.** Clicking
"Ryoku VM" performs `live-bind` and opens Looking Glass with no prompts when the
verdict is `ready`. For `needs-relogin` / `needs-reboot` it refuses and tells the
user exactly what to do (it never silently restarts the session). Binding uses
libvirt `managed='no'` + a Ryoku libvirt hook (dynamic, reversible). **No
boot-time vfio binding** - the dGPU is a normal host device whenever the VM is off.

### 4. GPU mode control (Go, integrates `ryoku-gpu`)

`ryoku-hub gpu mode get|set <hybrid|performance|passthrough>`:

- Hybrid: `ryoku-gpu disable` (no AQ_DRM_DEVICES pin; iGPU-first). 
- Performance: `RYOKU_GPU_FORCE=1 ryoku-gpu persist` (pin dGPU primary).
- Passthrough: ensure host is NOT on the dGPU (pin iGPU primary via a new
  `ryoku-gpu persist --primary <slot>`), mark the dGPU for VM use.
- Each returns the cost (`live` / `relogin` / `reboot`) so the UI can message it.
  Compositor-primary changes take effect on next Hyprland login (relogin), per the
  existing `gpu.lua` contract - never a full reboot except a hardware MUX flip.

### 5. VM model + libvirt XML (Go: `vm.go`, `vmxml.go` + tests)

Config persisted at `~/.config/ryoku/vm.json` (atomic write, hub pattern):

```
type VM struct {
    Name     string // "ryoku-win11"
    Guest    string // "windows11" | "linux" | "other"
    IsoPath  string
    VirtioIso string // auto for windows guests
    Cores    int
    RamMB    int
    DiskPath string // ~/.local/share/ryoku/vm/<name>.qcow2
    DiskGB   int
    Display  string // "looking-glass" (only option v1)
    GpuSlot  string // dGPU PCI slot to pass through
}
```

`vmxml.go` renders a libvirt domain via `text/template`:

- q35, host-passthrough CPU, hyperv enlightenments, `kvm` hidden state +
  spoofed `vendor_id` (NVIDIA code-43 insurance).
- OVMF with Secure Boot vars (Win11) and `swtpm` TPM 2.0.
- virtio disk + virtio-net; a second CDROM with the virtio-win driver ISO for
  Windows installs. Generic guests get virtio without the driver ISO.
- `<hostdev managed='no'>` for the dGPU + each sibling function (HDMI audio).
- Looking Glass IVSHMEM via kvmfr: `ivshmem-plain` + `memory-backend-file`
  `mem-path=/dev/kvmfr0`, size = next-pow2(W*H*4*2/1MiB + 10), minimum 128 MiB.
- memballoon disabled (LG perf). spice fallback display kept for first-boot/install
  before the guest driver + IDD are present.

Unit tests assert the rendered XML against golden files for windows11 and linux.

### 6. Passthrough enablement (Go privileged: `ryoku-hub gpu apply`, pkexec)

One-time, idempotent, reversible, snapshot-protected. Mirrors `cli/doctor.go`
`/etc`-write patterns and `lock.go` pkexec escalation. `enable`:

1. `snapper` pre-snapshot (reuse CLI helper) when available.
2. Install packages via pacman: `qemu-desktop libvirt edk2-ovmf swtpm dnsmasq
   looking-glass` (+ kvmfr dkms / `looking-glass-module-dkms`), gated/idempotent
   like `system/hardware/drivers/*.sh`.
3. Write `/etc/modules-load.d/kvmfr.conf`, `/etc/modprobe.d/kvmfr.conf`
   (`static_size_mb`), `/etc/udev/rules.d/99-kvmfr.rules` (user/kvm 0660).
4. Install `/etc/libvirt/hooks/qemu` dispatcher calling `ryoku-hub gpu hook`.
5. Polkit: `/etc/polkit-1/rules.d/50-ryoku-libvirt.rules` (libvirt-group manage).
6. Add the invoking user (via `PKEXEC_UID`) to `libvirt` and `kvm` groups.
7. Enable `libvirtd.socket`. Define the NAT `default` network.
8. Intel + IOMMU-off only: add `intel_iommu=on iommu=pt` to the Limine cmdline
   (reversible) and flag reboot-required.

`disable` reverts every file it wrote and removes group membership it added. Every
step prints a dry-run preview line first (UI shows the plan before the user
confirms the one-time enable).

### 7. Orchestration + launch

`ryoku-hub vm launch`:

1. Re-read capability. If verdict != `ready`, print the required action and exit
   non-zero (UI/launcher surfaces it). Never touches drivers when not ready.
2. `virsh start <name>` (system domain). The libvirt `prepare` hook
   (`ryoku-hub gpu hook prepare`) unbinds the dGPU group from its host driver and
   binds `vfio-pci` via direct sysfs; the `release/stopped` hook rebinds the host
   driver. NVIDIA persistence mode disabled before unbind.
3. `modprobe kvmfr static_size_mb=<n>` if not loaded (via the hook/helper).
4. Launch `looking-glass-client` as the user; Hyprland float rule frames it.
5. `vm stop`: `virsh shutdown`/`destroy`; hooks rebind the host driver.

### 8. Hub GPU page (QML, Profile idiom)

`ryoku/hub/quickshell/GpuPage.qml` + register in `Hub.qml` (sectionDefs, pageMeta,
pageFor, Component) under group `System`. Layout: `ShowcaseBackdrop` + a hero
`GpuCard` (iGPU/dGPU models, VRAM wave, big verdict badge) + a dossier built from
`SpecRow`/`Stat`/`MicroLabel`. A `Segmented` toggles:

- **Graphics**: capability dossier (one `SpecRow` per `Check`, ok/bad accent), the
  mode `ChoiceRow` (Hybrid/Performance/Passthrough), and an Apply action that
  states the cost (live/relogin/reboot). A one-time "Enable passthrough" button
  shows the dry-run plan, then runs `pkexec ryoku-hub gpu apply enable`.
- **Virtual Machine**: ISO picker, guest type, cores `NumberField`, RAM, disk;
  Create/Save; a prominent Launch. The whole segment is disabled (with the reason
  inline) until verdict is `ready`/`needs-relogin`/`needs-reboot` and passthrough
  is enabled.

Backend calls use the established `Process` + `StdioCollector` JSON pattern. Reads
are unprivileged; `apply` goes through pkexec.

### 9. Launcher + window rule

- `ryoku/apps/ryoku-vm/ryoku-vm.desktop` (Name "Ryoku VM", icon, `Exec=ryoku-hub
  vm launch`), installed to `/usr/share/applications` by the PKGBUILD and to
  `~/.local/share/applications` by deploy.sh. Discovered by the pill launcher
  (`DesktopEntries`).
- `ryoku/hyprland/modules/window_rules.lua`: float rule for the Looking Glass
  client (`class = "looking-glass-client"`), centered, large.

### 10. Packaging / deploy

- `release/packages/ryoku-desktop/PKGBUILD`: add the `.desktop`; list qemu /
  libvirt / ovmf / swtpm / looking-glass as **optdepends** (installed on first
  enable, not forced on every machine).
- `ryoku/shell/deploy.sh`: install the `.desktop`; `ryoku-hub` already built/installed.
- `system/hardware/CHANGELOG.md`, `ryoku/CHANGELOG.md`: entries.

## Safety model (the "don't break PCs" contract)

1. No destructive action unless the capability verdict is green for that action.
2. The GPU currently driving the host display is never bound to vfio.
3. Dynamic bind/unbind only; no boot-time vfio. dGPU is a normal host device when
   the VM is off.
4. The one-time enable: snapper snapshot first, dry-run preview shown, fully
   reversible `disable`.
5. All `/etc` writes idempotent and reverted on disable (doctor pattern).
6. Privilege only via pkexec with a Ryoku polkit policy; reads stay unprivileged.
7. IOMMU isolation validated before passthrough is offered.

## Testing

- `hwcaps_test.go`: fixture sysfs trees for desktop-dual, laptop-hybrid,
  laptop-mux-dgpu, single-gpu, intel-iommu-off, no-virt → assert verdict +
  strategy + each check level.
- `vmxml_test.go`: golden domain XML for windows11 and linux configs; assert
  hostdev funcs, kvmfr size math, hidden-state/vendor_id, swtpm/OVMF presence.
- `ryoku-gpu-detect` bash test additions: JSON shape + iommu_group field.
- Live passthrough (vfio bind, VM boot, Looking Glass) cannot be executed on the
  dev machine without black-screening it; it is implemented to the documented
  patterns, exercised via `apply --dry-run` / `vm xml`, and hard-gated.

## Decomposition (build order)

1. Enumeration JSON + capability engine (Go, tested) - the safety gate.
2. GPU mode control (Go) + `ryoku-gpu` `--primary` support.
3. VM model + libvirt XML generator (Go, golden tests).
4. Passthrough enable/disable + libvirt hook + orchestration + pkexec.
5. Hub GPU page (QML, Profile idiom).
6. Launcher + window rule + polkit + packaging + deploy + changelogs.
