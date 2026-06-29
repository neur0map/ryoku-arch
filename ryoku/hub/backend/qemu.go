package main

// qemu.go: launch a plain (non-passthrough) VM directly in QEMU with a native
// GTK window -- the window IS the VM. No libvirt, no Looking Glass, no kvmfr;
// just qemu, plus OVMF for UEFI when installed (SeaBIOS legacy boot otherwise).
// The guest renders through 2D virtio-vga (no host GL), so the window behaves
// the same on any GPU. Passthrough (Windows + dGPU) still goes through libvirt
// in vmrun.go.

import (
	"encoding/json"
	"fmt"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// ovmfPairs: UEFI firmware CODE + matching VARS template, by install location.
// Probed in order so the VM finds OVMF across edk2 package layouts and distros
// rather than assuming one path. None present -> SeaBIOS legacy boot.
var ovmfPairs = [][2]string{
	{"/usr/share/edk2/x64/OVMF_CODE.4m.fd", "/usr/share/edk2/x64/OVMF_VARS.4m.fd"},
	{"/usr/share/edk2/x64/OVMF_CODE.fd", "/usr/share/edk2/x64/OVMF_VARS.fd"},
	{"/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd", "/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd"},
	{"/usr/share/edk2-ovmf/x64/OVMF_CODE.fd", "/usr/share/edk2-ovmf/x64/OVMF_VARS.fd"},
	{"/usr/share/OVMF/x64/OVMF_CODE.4m.fd", "/usr/share/OVMF/x64/OVMF_VARS.4m.fd"},
	{"/usr/share/OVMF/OVMF_CODE.fd", "/usr/share/OVMF/OVMF_VARS.fd"},
}

// ovmfPaths returns the first installed CODE+VARS firmware pair (ok=false if none).
func ovmfPaths() (code, vars string, ok bool) {
	for _, p := range ovmfPairs {
		if fileExists(p[0]) && fileExists(p[1]) {
			return p[0], p[1], true
		}
	}
	return "", "", false
}

// qemuArgs builds the qemu-system-x86_64 command line for a plain VM.
func qemuArgs(v VM) ([]string, error) {
	args := []string{
		"-name", v.Name,
		"-machine", "q35,accel=kvm",
		"-cpu", "host",
		"-enable-kvm",
		"-smp", strconv.Itoa(v.Cores),
		"-m", strconv.Itoa(v.RamMB),
		// disk as an explicit device so it can carry a bootindex. OVMF boots by
		// bootindex (passed via fw_cfg) and ignores -boot order, so without one it
		// falls back to whatever its persistent NVRAM remembers -- which goes stale
		// and lands on PXE. disk after the CD (index 2) so an attached installer ISO
		// wins until it's removed.
		"-drive", "if=none,id=disk0,file=" + v.DiskPath + ",format=qcow2,discard=unmap",
		"-device", "virtio-blk-pci,drive=disk0,bootindex=2",
		"-netdev", "user,id=net0",
		"-device", "virtio-net-pci,netdev=net0",
		"-device", "qemu-xhci",
		"-device", "usb-tablet",
	}
	// UEFI when OVMF is installed (any known location); otherwise QEMU's built-in
	// SeaBIOS boots the (hybrid) ISO over legacy BIOS.
	if code, varsTmpl, ok := ovmfPaths(); ok {
		vars, err := ensureOvmfVars(v, varsTmpl)
		if err != nil {
			return nil, err
		}
		args = append(args,
			"-drive", "if=pflash,format=raw,readonly=on,file="+code,
			"-drive", "if=pflash,format=raw,file="+vars)
	}
	// 2D virtio-gpu in a native GTK window, deliberately WITHOUT host GL (no
	// gl=on). QEMU's GTK GL path leans on the host GPU's EGL stack and is brittle
	// under Wayland, so a GL window that opened on one GPU failed to start on
	// another: exactly the hardware-specific trap to avoid. 2D virtio-vga needs no
	// host GL, so the window behaves identically on AMD, NVIDIA and Intel and
	// shows a picture for every guest, installers included. 3D belongs to the
	// passthrough path. The guest renders at the window's PHYSICAL pixels (logical
	// size times the monitor scale) so a HiDPI compositor shows it 1:1 instead of
	// upscaling; zoom-to-fit covers a manual resize; the menu bar starts hidden
	// (Ctrl+Alt+M toggles it).
	gw, gh := guestRes()
	args = append(args,
		"-device", fmt.Sprintf("virtio-vga,xres=%d,yres=%d", gw, gh),
		"-display", "gtk,zoom-to-fit=on,show-menubar=off")
	// installer ISO with bootindex 1 (ahead of the disk) so it boots first while
	// attached, deterministically -- not subject to OVMF's stale NVRAM order.
	if v.IsoPath != "" {
		args = append(args,
			"-drive", "if=none,id=cd0,media=cdrom,file="+v.IsoPath,
			"-device", "ide-cd,drive=cd0,bootindex=1")
	}
	return args, nil
}

// vmWinW, vmWinH = the VM window's logical size. MUST match the float-ryoku-vm
// rule in ryoku/hyprland/modules/window_rules.lua: the guest is rendered at this
// size times the monitor scale so its pixels map 1:1 to the window's physical
// pixels (no compositor upscaling / blur on a HiDPI display).
const vmWinW, vmWinH = 1280, 800

// guestRes returns the guest framebuffer size: the VM window's physical pixels.
func guestRes() (int, int) { return physicalRes(vmWinW, vmWinH, monitorScale()) }

// physicalRes converts a logical size to physical pixels at the given scale.
func physicalRes(w, h int, scale float64) (int, int) {
	if scale <= 0 {
		scale = 1
	}
	return int(math.Round(float64(w) * scale)), int(math.Round(float64(h) * scale))
}

// monitorScale reads the focused monitor's scale from Hyprland (RYOKU_VM_SCALE
// overrides), or 1.0 when it can't be determined (no Hyprland, headless, tests).
func monitorScale() float64 {
	if v := os.Getenv("RYOKU_VM_SCALE"); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil && f > 0 {
			return f
		}
	}
	out, err := exec.Command("hyprctl", "monitors", "-j").Output()
	if err != nil {
		return 1
	}
	var ms []struct {
		Focused bool    `json:"focused"`
		Scale   float64 `json:"scale"`
	}
	if json.Unmarshal(out, &ms) != nil {
		return 1
	}
	for _, m := range ms {
		if m.Focused && m.Scale > 0 {
			return m.Scale
		}
	}
	if len(ms) > 0 && ms[0].Scale > 0 {
		return ms[0].Scale
	}
	return 1
}

// ensureOvmfVars gives the VM its own writable copy of the OVMF variable store
// (UEFI boot entries), seeded from the system template on first use.
func ensureOvmfVars(v VM, template string) (string, error) {
	dst := filepath.Join(vmDataDir(), v.Name+"_VARS.fd")
	if fileExists(dst) {
		return dst, nil
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return "", err
	}
	data, err := os.ReadFile(template)
	if err != nil {
		return "", err
	}
	return dst, os.WriteFile(dst, data, 0o644)
}

func qemuPidPath(v VM) string { return filepath.Join(vmDataDir(), v.Name+".pid") }

// qemuLaunch starts the VM detached so this process can exit and the native
// QEMU window outlives it, then records the pid for stop/status.
func qemuLaunch(v VM) error {
	if err := ensureDisk(v); err != nil {
		return err
	}
	args, err := qemuArgs(v)
	if err != nil {
		return err
	}
	logPath := filepath.Join(vmDataDir(), v.Name+".log")
	logf, err := os.Create(logPath)
	if err != nil {
		return err
	}
	defer logf.Close()
	cmd := exec.Command("qemu-system-x86_64", args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	cmd.Stdout, cmd.Stderr = logf, logf
	if err := cmd.Start(); err != nil {
		return err
	}
	if err := os.WriteFile(qemuPidPath(v), []byte(strconv.Itoa(cmd.Process.Pid)), 0o644); err != nil {
		return err
	}
	// QEMU fails fast on a bad device, firmware or display. Give it a moment; if
	// it already exited, surface the log tail instead of a silent, windowless
	// "launch" the user cannot diagnose.
	time.Sleep(900 * time.Millisecond)
	if !qemuRunning(v) {
		tail := lastLines(readFileString(logPath), 12)
		if strings.TrimSpace(tail) == "" {
			tail = "QEMU exited immediately with no output."
		}
		return fmt.Errorf("the VM failed to start:\n%s", tail)
	}
	return nil
}

func readFileString(p string) string {
	b, _ := os.ReadFile(p)
	return string(b)
}

// lastLines keeps the final n lines of s, for a compact error tail.
func lastLines(s string, n int) string {
	lines := strings.Split(strings.TrimRight(s, "\n"), "\n")
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	return strings.Join(lines, "\n")
}

func qemuPid(v VM) int {
	data, err := os.ReadFile(qemuPidPath(v))
	if err != nil {
		return 0
	}
	pid, _ := strconv.Atoi(strings.TrimSpace(string(data)))
	return pid
}

// qemuRunning reports whether the VM's QEMU process is alive, guarding against a
// recycled pid by confirming the live process is our qemu for this VM.
func qemuRunning(v VM) bool {
	pid := qemuPid(v)
	if pid <= 0 || syscall.Kill(pid, 0) != nil {
		return false
	}
	cmdline, err := os.ReadFile(fmt.Sprintf("/proc/%d/cmdline", pid))
	if err != nil {
		return false
	}
	s := string(cmdline)
	return strings.Contains(s, "qemu-system") && strings.Contains(s, v.Name)
}

// qemuStop powers off the VM's QEMU process; closing the window does the same.
func qemuStop(v VM) error {
	if pid := qemuPid(v); pid > 0 {
		_ = syscall.Kill(pid, syscall.SIGTERM)
	}
	_ = os.Remove(qemuPidPath(v))
	return nil
}
