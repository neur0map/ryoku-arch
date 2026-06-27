package main

// vmrun.go: the VM lifecycle over libvirt (qemu:///system). define creates the disk
// and registers the domain; launch refuses unless the capability verdict is "ready"
// (the fully-automatic, zero-reboot path the user chose), starts the domain so the
// libvirt hook binds the dGPU to vfio-pci, then opens the Looking Glass window.

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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
	xml, err := RenderDomain(v, report.Passthrough.Functions, 128)
	if err != nil {
		return err
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
	report, err := detectCapability()
	if err != nil {
		return err
	}
	if msg, blocked := launchBlocker(report); blocked {
		return fmt.Errorf("%s", msg)
	}
	v := loadVM()
	if err := vmDefine(v); err != nil {
		return err
	}
	// modules-load.d loads kvmfr at boot; cover the case where the user just enabled
	// passthrough and has not rebooted.
	run("modprobe", "kvmfr", "static_size_mb=128")
	if err := virsh("start", v.Name); err != nil {
		return err
	}
	lg := exec.Command("looking-glass-client", "app:shmFile=/dev/kvmfr0")
	lg.Stdout, lg.Stderr = os.Stdout, os.Stderr
	return lg.Start()
}

// launchBlocker turns a capability verdict into a launch decision. Only "ready"
// proceeds; everything else returns the exact action the user must take, and the
// launcher never silently relogins or reboots.
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
	return virsh("shutdown", v.Name)
}

func vmStatus() error {
	v := loadVM()
	report, _ := detectCapability()
	defined := virshQuiet("dominfo", v.Name) == nil
	running := false
	if out, err := exec.Command("virsh", "-c", "qemu:///system", "domstate", v.Name).Output(); err == nil {
		running = strings.TrimSpace(string(out)) == "running"
	}
	return printJSON(map[string]any{
		"name":     v.Name,
		"defined":  defined,
		"running":  running,
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
