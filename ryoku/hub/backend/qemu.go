package main

// qemu.go: launch a plain (non-passthrough) VM directly in QEMU with a native
// GTK window -- the window IS the VM. No libvirt, no Looking Glass, no kvmfr;
// just qemu, plus OVMF for UEFI and virglrenderer for GL when present (a SeaBIOS
// / software-GL fallback keeps it working with only qemu installed). Passthrough
// (the Windows + dGPU case) still goes through libvirt in vmrun.go.

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

const (
	ovmfCodePath = "/usr/share/edk2/x64/OVMF_CODE.4m.fd"
	ovmfVarsPath = "/usr/share/edk2/x64/OVMF_VARS.4m.fd"
)

// qemuArgs builds the qemu-system-x86_64 command line for a plain VM.
func qemuArgs(v VM) ([]string, error) {
	args := []string{
		"-name", v.Name,
		"-machine", "q35,accel=kvm",
		"-cpu", "host",
		"-enable-kvm",
		"-smp", strconv.Itoa(v.Cores),
		"-m", strconv.Itoa(v.RamMB),
		"-drive", "file=" + v.DiskPath + ",if=virtio,format=qcow2,discard=unmap",
		"-netdev", "user,id=net0",
		"-device", "virtio-net-pci,netdev=net0",
		"-device", "qemu-xhci",
		"-device", "usb-tablet",
	}
	// UEFI when OVMF is installed; otherwise QEMU's built-in SeaBIOS boots the
	// (hybrid) ISO over legacy BIOS.
	if fileExists(ovmfCodePath) {
		vars, err := ensureOvmfVars(v)
		if err != nil {
			return nil, err
		}
		args = append(args,
			"-drive", "if=pflash,format=raw,readonly=on,file="+ovmfCodePath,
			"-drive", "if=pflash,format=raw,file="+vars)
	}
	// Host-GL virtio-gpu when virglrenderer is present; plain virtio-vga else.
	if pkgInstalled("virglrenderer") {
		args = append(args, "-device", "virtio-vga-gl", "-display", "gtk,gl=on")
	} else {
		args = append(args, "-device", "virtio-vga", "-display", "gtk")
	}
	if v.IsoPath != "" {
		args = append(args, "-drive", "file="+v.IsoPath+",media=cdrom", "-boot", "order=dc,menu=on")
	}
	return args, nil
}

// ensureOvmfVars gives the VM its own writable copy of the OVMF variable store
// (UEFI boot entries), seeded from the system template on first use.
func ensureOvmfVars(v VM) (string, error) {
	dst := filepath.Join(vmDataDir(), v.Name+"_VARS.fd")
	if fileExists(dst) {
		return dst, nil
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return "", err
	}
	data, err := os.ReadFile(ovmfVarsPath)
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
	cmd := exec.Command("qemu-system-x86_64", args...)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		return err
	}
	return os.WriteFile(qemuPidPath(v), []byte(strconv.Itoa(cmd.Process.Pid)), 0o644)
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
