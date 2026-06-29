package main

// vmrun.go: VM lifecycle. A plain (non-passthrough) VM runs directly in QEMU
// with a native GTK window (see qemu.go) -- no libvirt, no Looking Glass. A
// passthrough VM goes over libvirt (qemu:///system): define registers the
// domain, launch refuses unless the capability verdict is "ready", starts it so
// the libvirt hook binds the dGPU to vfio-pci, then opens Looking Glass.

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
)

func vmDefine(v VM) error {
	report, err := detectCapability()
	if err != nil {
		return err
	}
	if report.Passthrough == nil {
		return fmt.Errorf("no discrete GPU available to pass through")
	}
	if err := ensureDisk(v); err != nil {
		return err
	}
	xml, err := RenderDomain(v, report.Passthrough.Functions, kvmfrStaticMB)
	if err != nil {
		return err
	}
	// preserve identity across redefines: libvirt rejects a fresh UUID for an
	// existing name. reuse the current UUID so a relaunch updates in place.
	if uuid := domainUUID(v.Name); uuid != "" {
		xml = strings.Replace(xml,
			"<name>"+v.Name+"</name>",
			"<name>"+v.Name+"</name>\n  <uuid>"+uuid+"</uuid>", 1)
	}
	tmp, err := os.CreateTemp("", "ryoku-domain-*.xml")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.WriteString(xml); err != nil {
		return err
	}
	tmp.Close()
	return virsh("define", tmp.Name())
}

func ensureDisk(v VM) error {
	if v.DiskPath == "" {
		return fmt.Errorf("vm has no disk path")
	}
	if _, err := os.Stat(v.DiskPath); err == nil {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(v.DiskPath), 0o755); err != nil {
		return err
	}
	return exec.Command("qemu-img", "create", "-f", "qcow2", v.DiskPath, fmt.Sprintf("%dG", v.DiskGB)).Run()
}

func vmLaunch() error {
	v := loadVM()
	if !vmWantsPassthrough(v) {
		// plain VM: a native QEMU window, no libvirt and no Looking Glass.
		return qemuLaunch(v)
	}
	report, err := detectCapability()
	if err != nil {
		return err
	}
	if msg, blocked := launchBlocker(report); blocked {
		return fmt.Errorf("%s", msg)
	}
	if err := vmDefine(v); err != nil {
		return err
	}
	// modules-load.d loads kvmfr at boot; this covers the case where the user
	// just enabled passthrough and hasn't rebooted yet.
	run("modprobe", "kvmfr", fmt.Sprintf("static_size_mb=%d", kvmfrStaticMB))
	if err := virsh("start", v.Name); err != nil {
		return err
	}
	// detach the client so a launcher-spawned ryoku-hub can exit right away and
	// the window outlives it. fds -> /dev/null, not the caller's captured pipe.
	lg := exec.Command("looking-glass-client", "app:shmFile=/dev/kvmfr0")
	lg.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	return lg.Start()
}

// launchBlocker: capability verdict -> launch decision. only "ready" goes
// through; anything else returns the exact action the user has to take, so the
// launcher never silently relogins or reboots behind their back.
func launchBlocker(report Capability) (string, bool) {
	switch report.Verdict {
	case "ready":
		return "", false
	case "needs-relogin":
		return "Log out and back in first: Ryoku must move to the iGPU before the dGPU can join the VM.", true
	case "needs-reboot":
		return "Reboot into hybrid mode first (flip the MUX so the iGPU drives the screen), then launch.", true
	case "needs-setup":
		return "Enable passthrough in Ryoku Settings > GPU first.", true
	default:
		return "This machine cannot pass the discrete GPU to a VM.", true
	}
}

func vmStop(v VM) error {
	if !vmWantsPassthrough(v) {
		return qemuStop(v)
	}
	return virsh("shutdown", v.Name)
}

// vmRunning reports whether the VM is powered on, in either display mode: a
// windowed VM by its QEMU pid, a passthrough VM by its libvirt domain state.
// Snapshot and reset refuse while it is on, since qemu-img must own the disk.
func vmRunning(v VM) bool {
	if vmWantsPassthrough(v) {
		out, err := exec.Command("virsh", "-c", "qemu:///system", "domstate", v.Name).Output()
		return err == nil && strings.TrimSpace(string(out)) == "running"
	}
	return qemuRunning(v)
}

func vmStatus() error {
	v := loadVM()
	report, _ := detectCapability()
	// a plain VM has no persistent libvirt definition; the disk is its state.
	defined := fileExists(v.DiskPath)
	if vmWantsPassthrough(v) {
		defined = virshQuiet("dominfo", v.Name) == nil
	}
	return printJSON(map[string]any{
		"name":     v.Name,
		"defined":  defined,
		"running":  vmRunning(v),
		"verdict":  report.Verdict,
		"strategy": report.Strategy,
	})
}

func virsh(args ...string) error {
	cmd := exec.Command("virsh", append([]string{"-c", "qemu:///system"}, args...)...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	return cmd.Run()
}

func virshQuiet(args ...string) error {
	return exec.Command("virsh", append([]string{"-c", "qemu:///system"}, args...)...).Run()
}

// domainUUID returns the UUID of a defined domain, or "" if it does not exist.
func domainUUID(name string) string {
	out, err := exec.Command("virsh", "-c", "qemu:///system", "domuuid", name).Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}
