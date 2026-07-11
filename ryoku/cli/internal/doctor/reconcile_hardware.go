package doctor

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"ryoku-cli/internal/sys"
)

// ---- reconciler: display backlight -------------------------------------------

// reconcileBacklight flags the common brightness failures:
//   - no backlight interface at all.
//   - backlight present but no brightnessctl to drive it.
//   - hybrid-GPU laptop with only a firmware backlight.
//
// for the last we trust the kernel's own verdict (dGPU reports no native
// backlight) over a sysfs value the panel may ignore. detect-and-warn only;
// the fixes (GPU mux switch, kernel parameters) are too machine-specific to
// apply blindly.
func reconcileBacklight(_ bool) recResult {
	devs := backlightDevices()
	if len(devs) == 0 {
		if !isLaptop() {
			return okRes("no internal backlight (desktop or external display)")
		}
		return warnRes("no backlight interface found; display brightness cannot be set").
			withFix("try a kernel parameter such as acpi_backlight=native or acpi_backlight=vendor")
	}
	if !sys.Has("brightnessctl") {
		return warnRes("backlight present but brightnessctl is missing; brightness keys and idle-dim will not work").
			withFix("sudo pacman -S brightnessctl")
	}
	if gpus := gpuDriversLoaded(); len(gpus) >= 2 && onlyFirmwareBacklight(devs) {
		detail := fmt.Sprintf("hybrid GPU (%s) with only a firmware backlight (%s); the panel may not dim",
			strings.Join(gpus, "+"), strings.Join(devs, ","))
		if nvidiaBacklightDead() {
			detail = fmt.Sprintf("hybrid GPU (%s): the kernel reports the dGPU has no working backlight, and the firmware fallback (%s) does not dim the panel",
				strings.Join(gpus, "+"), strings.Join(devs, ","))
		}
		fix := "route the panel to the iGPU: set the BIOS GPU/MUX mode to Hybrid and reboot, then amdgpu_bl0 appears"
		if sys.Has("supergfxctl") {
			fix += "; on a supported ASUS laptop `supergfxctl -m Hybrid` switches it without a BIOS trip"
		}
		return noteRes("%s", detail).withFix(fix)
	}
	return okRes("backlight: %s", strings.Join(devs, ", "))
}

// nvidiaBacklightDead: the kernel's own tell that the dGPU has no usable
// backlight and fell back to the often-broken ACPI/EC interface.
func nvidiaBacklightDead() bool {
	n := strings.TrimSpace(captureOut("sh", "-c",
		"journalctl -k -b --no-pager 2>/dev/null | grep -ic 'no NVIDIA native backlight'"))
	return n != "" && n != "0"
}

func backlightDevices() []string {
	entries, err := os.ReadDir("/sys/class/backlight")
	if err != nil {
		return nil
	}
	out := make([]string, 0, len(entries))
	for _, e := range entries {
		out = append(out, e.Name())
	}
	return out
}

func onlyFirmwareBacklight(devs []string) bool {
	for _, d := range devs {
		if strings.TrimSpace(readFileSafe("/sys/class/backlight/"+d+"/type")) != "firmware" {
			return false
		}
	}
	return len(devs) > 0
}

// gpuDriversLoaded: loaded GPU kernel drivers, so a hybrid-GPU box is
// recognizable.
func gpuDriversLoaded() []string {
	var out []string
	for _, m := range []string{"amdgpu", "nvidia", "i915", "nouveau", "xe"} {
		if sys.Exists("/sys/module/" + m) {
			out = append(out, m)
		}
	}
	return out
}

// isLaptop: machine has a battery, i.e. an internal panel whose backlight
// we'd expect to control.
func isLaptop() bool {
	entries, err := os.ReadDir("/sys/class/power_supply")
	if err != nil {
		return false
	}
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), "BAT") {
			return true
		}
	}
	return false
}

// ---- reconciler: NVIDIA boot reliability -------------------------------------

// reconcileNvidiaModeset backports the installer's NVIDIA reliability config
// to a box running the proprietary/open nvidia modules but installed (or
// last doctored) before the fix. without it, nouveau and nvidia race for the
// card at boot, so the GPU "shows up only on some boots" -- the intermittent
// detection failure users hit. mirrors system/hardware/drivers/nvidia.sh:
// blacklist nouveau, force DRM modeset, load the modules early, then rebuild
// the initramfs so it takes effect. acts ONLY when an nvidia kernel-module
// package is installed (or the module is loaded); a box on nouveau by choice
// has no such package and stays untouched -- blacklisting nouveau there
// would break its display.

// nvidiaModprobeConf mirrors system/hardware/drivers/nvidia.sh verbatim, so
// a doctored box matches a fresh install.
const nvidiaModprobeConf = `options nvidia_drm modeset=1 fbdev=1
options nvidia NVreg_PreserveVideoMemoryAllocations=1
blacklist nouveau
options nouveau modeset=0
`

const nvidiaMkinitcpioConf = "MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)\n"

// nvidiaDriverActive: does this box use the proprietary/open nvidia driver?
// a loaded module is the clearest tell, but the bug we repair is exactly
// that nouveau won the boot race, so the module may NOT be loaded -- fall
// back to "an nvidia kernel-module package is installed". nvidia-utils
// (userspace) alone is excluded: with no module to load, writing
// MODULES=(nvidia ...) would only break the initramfs.
func nvidiaDriverActive() bool {
	for _, m := range gpuDriversLoaded() {
		if m == "nvidia" {
			return true
		}
	}
	return anyPkgInstalled("nvidia-open-dkms", "nvidia-dkms", "nvidia-open", "nvidia", "nvidia-lts", "nvidia-open-lts")
}

// nvidiaConfigOK: do the modprobe + mkinitcpio drop-ins already carry the
// reliability essentials (nouveau blacklisted, DRM modeset on, nvidia
// modules in the initramfs)? pure, so the idempotency that keeps doctor
// quiet on a healthy box -- and stops it rebuilding the initramfs every
// run -- is unit-testable.
func nvidiaConfigOK(modprobe, mkinit string) bool {
	return strings.Contains(modprobe, "blacklist nouveau") &&
		strings.Contains(modprobe, "nvidia_drm modeset=1") &&
		strings.Contains(mkinit, "nvidia_drm")
}

func reconcileNvidiaModeset(checkOnly bool) recResult {
	if !nvidiaDriverActive() {
		return okRes("no proprietary NVIDIA driver in use")
	}
	modprobe := readFileSafe("/etc/modprobe.d/nvidia.conf")
	mkinit := readFileSafe("/etc/mkinitcpio.conf.d/nvidia.conf")
	ok := nvidiaConfigOK(modprobe, mkinit)
	if ok {
		return okRes("NVIDIA modeset + nouveau blacklist in place")
	}
	if checkOnly {
		return wouldRes("NVIDIA driver in use but nouveau is not blacklisted / DRM modeset not set; the GPU can fail to come up on some boots").
			withFix("ryoku doctor  (writes /etc/modprobe.d/nvidia.conf and rebuilds the initramfs)")
	}
	if err := writeRootFile("/etc/modprobe.d/nvidia.conf", nvidiaModprobeConf, "0644"); err != nil {
		return failRes("could not write /etc/modprobe.d/nvidia.conf: %v", err).
			withFix("re-run with sudo access")
	}
	if err := writeRootFile("/etc/mkinitcpio.conf.d/nvidia.conf", nvidiaMkinitcpioConf, "0644"); err != nil {
		return failRes("could not write /etc/mkinitcpio.conf.d/nvidia.conf: %v", err).
			withFix("re-run with sudo access")
	}
	if err := rebuildInitramfs(); err != nil {
		return warnRes("wrote the NVIDIA reliability config, but the initramfs rebuild failed: %v", err).
			withFix("sudo limine-mkinitcpio  (or: sudo mkinitcpio -P)")
	}
	return fixedRes("blacklisted nouveau, enabled NVIDIA DRM modeset, and rebuilt the initramfs")
}

// rebuildInitramfs regenerates the boot image after a module/blacklist
// change. limine-mkinitcpio when present (the UKI path Ryoku uses), else
// plain mkinitcpio -P.
func rebuildInitramfs() error {
	if _, err := exec.LookPath("limine-mkinitcpio"); err == nil {
		return sys.Run("sudo", "limine-mkinitcpio")
	}
	return sys.Run("sudo", "mkinitcpio", "-P")
}
