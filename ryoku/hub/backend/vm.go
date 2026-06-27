package main

// vm.go: the single Ryoku VM's configuration. the Hub VM panel reads + writes
// it; later phases generate a libvirt domain from it and drive its lifecycle.
// one VM in v1; the on-disk shape is a single object so a future multi-VM list
// is additive.

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// VM = the user-facing virtual-machine configuration, persisted at
// ~/.config/ryoku/vm.json.
type VM struct {
	Name      string `json:"name"`
	Guest     string `json:"guest"` // windows11 | linux | other
	IsoPath   string `json:"isoPath"`
	VirtioIso string `json:"virtioIso"` // virtio-win ISO for Windows installs
	Cores     int    `json:"cores"`
	RamMB     int    `json:"ramMb"`
	DiskPath  string `json:"diskPath"`
	DiskGB    int    `json:"diskGb"`
	Display   string `json:"display"` // looking-glass
	GpuSlot   string `json:"gpuSlot"` // dGPU PCI slot to pass through
}

func defaultVM() VM {
	return VM{
		Name:     "ryoku-win11",
		Guest:    "windows11",
		Cores:    4,
		RamMB:    8192,
		DiskGB:   64,
		Display:  "looking-glass",
		DiskPath: filepath.Join(vmDataDir(), "ryoku-win11.qcow2"),
	}
}

func vmDataDir() string {
	base := os.Getenv("XDG_DATA_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".local", "share")
	}
	return filepath.Join(base, "ryoku", "vm")
}

func vmConfigPath() string {
	base := os.Getenv("RYOKU_CONFIG_BASE")
	if base == "" {
		base = os.Getenv("XDG_CONFIG_HOME")
		if base == "" {
			base = filepath.Join(os.Getenv("HOME"), ".config")
		}
	}
	return filepath.Join(base, "ryoku", "vm.json")
}

func loadVM() VM {
	v := defaultVM()
	if b, err := os.ReadFile(vmConfigPath()); err == nil {
		_ = json.Unmarshal(b, &v)
	}
	return v
}

func saveVM(v VM) error {
	if v.Name == "" {
		return fmt.Errorf("vm name required")
	}
	// clamp to floors so a bad UI value can never produce an unbootable domain.
	if v.Cores < 1 {
		v.Cores = 1
	}
	if v.RamMB < 2048 {
		v.RamMB = 2048
	}
	if v.DiskGB < 16 {
		v.DiskGB = 16
	}
	if v.Display == "" {
		v.Display = "looking-glass"
	}
	if v.DiskPath == "" {
		v.DiskPath = filepath.Join(vmDataDir(), v.Name+".qcow2")
	}
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	p := vmConfigPath()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	return atomicWrite(p, append(b, '\n'), 0o644)
}

func runVM(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("vm needs get|save|xml")
	}
	switch args[0] {
	case "get":
		return printJSON(loadVM())
	case "save":
		if len(args) < 2 {
			return fmt.Errorf("vm save needs a json argument")
		}
		var v VM
		if err := json.Unmarshal([]byte(args[1]), &v); err != nil {
			return fmt.Errorf("vm save: bad json: %w", err)
		}
		return saveVM(v)
	case "xml":
		v := loadVM()
		if !vmWantsPassthrough(v) {
			args, err := qemuArgs(v)
			if err != nil {
				return err
			}
			fmt.Println("qemu-system-x86_64 " + strings.Join(args, " "))
			return nil
		}
		report, err := detectCapability()
		if err != nil {
			return err
		}
		if report.Passthrough == nil {
			return fmt.Errorf("no discrete GPU available to pass through")
		}
		xml, err := RenderDomain(v, report.Passthrough.Functions, kvmfrStaticMB)
		if err != nil {
			return err
		}
		fmt.Println(xml)
		return nil
	case "define":
		return vmDefine(loadVM())
	case "launch":
		return vmLaunch()
	case "stop":
		return vmStop(loadVM())
	case "status":
		return vmStatus()
	default:
		return fmt.Errorf("unknown vm subcommand: %s", args[0])
	}
}

// vmWantsPassthrough reports whether a VM should be handed the discrete GPU and
// Looking Glass over libvirt. Only the Windows 11 guest is; Linux and other
// guests run directly in QEMU (qemu.go) -- a native window, no GPU, no Looking
// Glass, no libvirt, no MUX flip.
func vmWantsPassthrough(v VM) bool { return v.Guest == "windows11" }
