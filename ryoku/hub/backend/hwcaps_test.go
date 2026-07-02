package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// baseInputs is a capable desktop with the full stack installed: the starting
// point each scenario mutates. iGPU drives the display, dGPU is free.
func baseInputs() capInputs {
	in := capInputs{
		cpuVendor:      "AMD",
		cpuVirt:        true,
		kvm:            true,
		iommuOn:        true,
		chassis:        "desktop",
		ramTotalMB:     32000,
		ramFreeMB:      16000,
		groupOf:        map[string]int{},
		groupMembers:   map[int][]string{},
		inLibvirtGroup: true,
		tooling:        tooling{qemu: true, libvirt: true, ovmf: true, swtpm: true, lookingGlass: true, kvmfr: true, hook: true},
	}
	in.records = []gpuRecord{
		{Slot: "0000:01:00.0", Class: "discrete", Driver: "nvidia", VRAM: 8 << 30, Connected: 0, Model: "RTX 4060"},
		{Slot: "0000:00:02.0", Class: "integrated", Driver: "amdgpu", VRAM: 512 << 20, Connected: 1, Model: "Radeon 780M"},
	}
	in.groupOf["0000:01:00.0"] = 14
	in.groupMembers[14] = []string{"0000:01:00.0", "0000:01:00.1"}
	return in
}

func TestBuildCapabilityVerdicts(t *testing.T) {
	cases := []struct {
		name         string
		mutate       func(in *capInputs)
		wantStrategy string
		wantVerdict  string
	}{
		{
			name:         "desktop dgpu free, stack ready",
			mutate:       func(in *capInputs) {},
			wantStrategy: "live-bind",
			wantVerdict:  "ready",
		},
		{
			name:         "laptop hybrid, dgpu free",
			mutate:       func(in *capInputs) { in.chassis = "laptop" },
			wantStrategy: "live-bind",
			wantVerdict:  "ready",
		},
		{
			name: "laptop mux on dgpu (dgpu drives panel)",
			mutate: func(in *capInputs) {
				in.chassis = "laptop"
				in.records[0].Connected = 1 // dGPU drives the panel
				in.records[1].Connected = 0
			},
			wantStrategy: "mux-reboot",
			wantVerdict:  "needs-reboot",
		},
		{
			name: "desktop dgpu drives a monitor, igpu also has one",
			mutate: func(in *capInputs) {
				in.records[0].Connected = 1 // dGPU drives a monitor
				in.records[1].Connected = 1 // iGPU also has a monitor
			},
			wantStrategy: "relogin-then-bind",
			wantVerdict:  "needs-relogin",
		},
		{
			name: "desktop, only display is on the dgpu",
			mutate: func(in *capInputs) {
				in.records[0].Connected = 1 // dGPU drives the only monitor
				in.records[1].Connected = 0 // iGPU headless
			},
			wantStrategy: "none",
			wantVerdict:  "incapable",
		},
		{
			name: "single gpu",
			mutate: func(in *capInputs) {
				in.records = in.records[:1] // only the discrete GPU
			},
			wantStrategy: "none",
			wantVerdict:  "incapable",
		},
		{
			name:         "no cpu virtualization",
			mutate:       func(in *capInputs) { in.cpuVirt = false },
			wantStrategy: "none",
			wantVerdict:  "incapable",
		},
		{
			name: "intel iommu off is a firmware fix, not a cmdline one",
			mutate: func(in *capInputs) {
				in.cpuVendor = "Intel"
				in.iommuOn = false
			},
			wantStrategy: "none",
			wantVerdict:  "incapable",
		},
		{
			name:         "stack not installed",
			mutate:       func(in *capInputs) { in.tooling.qemu = false; in.tooling.lookingGlass = false },
			wantStrategy: "live-bind",
			wantVerdict:  "needs-setup",
		},
		{
			name:         "stack installed but not yet in libvirt group",
			mutate:       func(in *capInputs) { in.inLibvirtGroup = false },
			wantStrategy: "live-bind",
			wantVerdict:  "needs-relogin",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			in := baseInputs()
			tc.mutate(&in)
			got := buildCapability(in)
			if got.Strategy != tc.wantStrategy {
				t.Errorf("strategy = %q, want %q", got.Strategy, tc.wantStrategy)
			}
			if got.Verdict != tc.wantVerdict {
				t.Errorf("verdict = %q, want %q", got.Verdict, tc.wantVerdict)
			}
		})
	}
}

func TestIommuIsolationAndFunctions(t *testing.T) {
	in := baseInputs()
	// A non-GPU device shares the dGPU's group.
	in.groupMembers[14] = []string{"0000:01:00.0", "0000:01:00.1", "0000:02:00.0"}
	got := buildCapability(in)
	if got.Passthrough == nil {
		t.Fatal("expected a passthrough GPU")
	}
	if got.Passthrough.GroupIsolated {
		t.Error("group with an unrelated device must not be isolated")
	}
	if len(got.Passthrough.Functions) != 2 {
		t.Errorf("functions = %v, want the two 01:00.* siblings", got.Passthrough.Functions)
	}
	// A shared group is a warning, not a hard fail: still launchable.
	if got.Verdict != "ready" {
		t.Errorf("verdict = %q, want ready (isolation is a warning)", got.Verdict)
	}
	if levelOf(got.Checks, "iommu-isolation") != "warn" {
		t.Errorf("iommu-isolation level = %q, want warn", levelOf(got.Checks, "iommu-isolation"))
	}
}

func TestHostAndPassthroughSelection(t *testing.T) {
	in := baseInputs()
	got := buildCapability(in)
	if got.Host == nil || got.Host.Slot != "0000:00:02.0" {
		t.Errorf("host = %+v, want the integrated GPU", got.Host)
	}
	if got.Passthrough == nil || got.Passthrough.Slot != "0000:01:00.0" {
		t.Errorf("passthrough = %+v, want the discrete GPU", got.Passthrough)
	}
}

func TestSysfsReaders(t *testing.T) {
	root := t.TempDir()
	writeFile(t, root, "proc/cpuinfo", "vendor_id\t: AuthenticAMD\nflags\t\t: fpu vme svm lahf_lm\n")
	writeFile(t, root, "proc/meminfo", "MemTotal:       32000000 kB\nMemAvailable:   16000000 kB\n")
	writeFile(t, root, "sys/class/dmi/id/chassis_type", "10\n")
	writeFile(t, root, "sys/kernel/iommu_groups/14/devices/0000:01:00.0", "")
	writeFile(t, root, "sys/kernel/iommu_groups/14/devices/0000:01:00.1", "")
	mkdirAll(t, filepath.Join(root, "sys/bus/pci/devices/0000:01:00.0"))
	if err := os.Symlink("/x/kernel/iommu_groups/14", filepath.Join(root, "sys/bus/pci/devices/0000:01:00.0/iommu_group")); err != nil {
		t.Fatal(err)
	}
	writeFile(t, root, "dev/kvm", "")

	if v, ok := readCPUVirt(root); v != "AMD" || !ok {
		t.Errorf("readCPUVirt = %q,%v want AMD,true", v, ok)
	}
	if tot, free := readMeminfo(root); tot != 31250 || free != 15625 {
		t.Errorf("readMeminfo = %d,%d want 31250,15625", tot, free)
	}
	if c := readChassis(root); c != "laptop" {
		t.Errorf("readChassis = %q want laptop", c)
	}
	if g, ok := readIommuGroup(root, "0000:01:00.0"); !ok || g != 14 {
		t.Errorf("readIommuGroup = %d,%v want 14,true", g, ok)
	}
	if m := readGroupMembers(root, 14); len(m) != 2 {
		t.Errorf("readGroupMembers = %v want 2 entries", m)
	}
	if !fileExists(filepath.Join(root, "dev/kvm")) {
		t.Error("fileExists(/dev/kvm) = false")
	}
}

func levelOf(checks []Check, id string) string {
	for _, c := range checks {
		if c.ID == id {
			return c.Level
		}
	}
	return ""
}

func writeFile(t *testing.T, root, rel, content string) {
	t.Helper()
	p := filepath.Join(root, rel)
	mkdirAll(t, filepath.Dir(p))
	if err := os.WriteFile(p, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}

func mkdirAll(t *testing.T, dir string) {
	t.Helper()
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
}

func TestPrettyModel(t *testing.T) {
	cases := map[string]string{
		"NVIDIA Corporation AD107M [GeForce RTX 4060 Max-Q / Mobile]":         "GeForce RTX 4060",
		"Advanced Micro Devices, Inc. [AMD/ATI] Phoenix1":                     "Phoenix1",
		"Intel Corporation Raptor Lake-S GT1 [UHD Graphics 770]":              "UHD Graphics 770",
		"Advanced Micro Devices, Inc. [AMD/ATI] Navi 31 [Radeon RX 7900 XTX]": "Radeon RX 7900 XTX",
		"GeForce RTX 4060": "GeForce RTX 4060",
		"":                 "",
	}
	for in, want := range cases {
		if got := prettyModel(in); got != want {
			t.Errorf("prettyModel(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestGpuRecordsFromToolTimeout(t *testing.T) {
	dir := t.TempDir()
	bin := filepath.Join(dir, "ryoku-gpu")
	if err := os.WriteFile(bin, []byte("#!/bin/sh\nsleep 30\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("RYOKU_GPU_BIN", bin)
	old := gpuDetectTimeout
	gpuDetectTimeout = 150 * time.Millisecond
	defer func() { gpuDetectTimeout = old }()

	start := time.Now()
	if _, err := gpuRecordsFromTool(); err == nil {
		t.Fatal("expected an error when the detector hangs past the timeout")
	}
	if elapsed := time.Since(start); elapsed > 5*time.Second {
		t.Fatalf("gpuRecordsFromTool blocked for %s; the timeout did not fire", elapsed)
	}
}

func TestGpuRecordsFromToolRejectsNonJSON(t *testing.T) {
	dir := t.TempDir()
	bin := filepath.Join(dir, "ryoku-gpu")
	// an out-of-date ryoku-gpu ignores --json and prints its CARD table.
	if err := os.WriteFile(bin, []byte("#!/bin/sh\necho 'CARD    PCI    CLASS'\n"), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Setenv("RYOKU_GPU_BIN", bin)
	_, err := gpuRecordsFromTool()
	if err == nil {
		t.Fatal("expected an error for non-JSON detector output")
	}
	if !strings.Contains(err.Error(), "did not return JSON") {
		t.Fatalf("error = %q, want it to flag the out-of-date detector", err)
	}
}
