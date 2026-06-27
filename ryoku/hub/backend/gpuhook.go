package main

// gpuhook.go: the vfio bind/unbind that libvirt triggers around the VM's life.
// /etc/libvirt/hooks/qemu calls `ryoku-hub gpu hook prepare|release <name>`; on
// prepare we move the dGPU (and its sibling functions) from its host driver to
// vfio-pci, on release we hand it back. It is dynamic (no boot-time vfio binding),
// so the dGPU is a normal host device whenever the VM is off. The bind/unbind is a
// pure ordered action list (testable) and it hard-refuses if the dGPU is currently
// driving the display.

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

// sysAction is one privileged step: a sysfs attribute write or a modprobe.
type sysAction struct {
	Kind  string // "write" | "write-ok" (ignore errors) | "modprobe"
	Path  string
	Value string
	Args  []string
}

func (a sysAction) String() string {
	switch a.Kind {
	case "modprobe":
		return "modprobe " + a.Value + " " + joinArgs(a.Args)
	default:
		return "echo " + a.Value + " > " + a.Path
	}
}

func joinArgs(a []string) string {
	out := ""
	for _, s := range a {
		out += s + " "
	}
	return out
}

func bindVfioActions(funcs []string) []sysAction {
	acts := []sysAction{{Kind: "modprobe", Value: "vfio-pci"}}
	for _, f := range funcs {
		dev := "/sys/bus/pci/devices/" + f
		acts = append(acts,
			sysAction{Kind: "write", Path: dev + "/driver_override", Value: "vfio-pci"},
			sysAction{Kind: "write-ok", Path: dev + "/driver/unbind", Value: f},
			sysAction{Kind: "write", Path: "/sys/bus/pci/drivers_probe", Value: f},
		)
	}
	return acts
}

func unbindVfioActions(funcs []string) []sysAction {
	var acts []sysAction
	for _, f := range funcs {
		dev := "/sys/bus/pci/devices/" + f
		acts = append(acts,
			sysAction{Kind: "write-ok", Path: dev + "/driver/unbind", Value: f},
			sysAction{Kind: "write", Path: dev + "/driver_override", Value: ""},
			sysAction{Kind: "write", Path: "/sys/bus/pci/drivers_probe", Value: f},
		)
	}
	return acts
}

// hookActions is the pure decision: what to do for a hook op, refusing to strip the
// GPU that is driving the screen.
func hookActions(op string, pass *GPU) ([]sysAction, error) {
	switch op {
	case "prepare", "begin", "start", "started":
		if pass.DrivesDisplay {
			return nil, fmt.Errorf("refusing: dGPU %s currently drives the display", pass.Slot)
		}
		return bindVfioActions(pass.Functions), nil
	case "release", "end", "stopped":
		return unbindVfioActions(pass.Functions), nil
	default:
		return nil, nil
	}
}

func runGpuHook(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("gpu hook needs prepare|release [vmname]")
	}
	op := args[0]
	name := ""
	if len(args) >= 2 {
		name = args[1]
	}
	vm := loadVM()
	if name != "" && name != vm.Name {
		return nil // not our VM; libvirt hooks fire for every domain
	}
	report, err := detectCapability()
	if err != nil {
		return err
	}
	if report.Passthrough == nil {
		return fmt.Errorf("no discrete GPU to pass through")
	}
	acts, err := hookActions(op, report.Passthrough)
	if err != nil {
		return err
	}
	return runActions(acts, os.Getenv("RYOKU_DRYRUN") == "1")
}

func runActions(acts []sysAction, dryRun bool) error {
	root := sysfsRoot()
	for _, a := range acts {
		if dryRun {
			fmt.Println("[dry-run]", a.String())
			continue
		}
		if err := a.apply(root); err != nil {
			return fmt.Errorf("%s: %w", a.String(), err)
		}
	}
	return nil
}

func (a sysAction) apply(root string) error {
	switch a.Kind {
	case "modprobe":
		return exec.Command("modprobe", append([]string{a.Value}, a.Args...)...).Run()
	case "write", "write-ok":
		p := a.Path
		if root != "" && root != "/" {
			p = filepath.Join(root, a.Path)
		}
		err := os.WriteFile(p, []byte(a.Value+"\n"), 0o200)
		if a.Kind == "write-ok" {
			return nil // best-effort: unbinding a device with no driver is fine
		}
		return err
	}
	return nil
}
