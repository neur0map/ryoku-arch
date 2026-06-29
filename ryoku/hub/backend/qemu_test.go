package main

import (
	"strings"
	"testing"
)

func TestQemuArgs(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir()) // contain any OVMF vars copy
	t.Setenv("RYOKU_VM_SCALE", "1")        // deterministic guest resolution (no monitor scale)
	v := VM{Name: "ryoku-vm", Guest: "linux", Cores: 4, RamMB: 8192, DiskPath: "/tmp/d.qcow2", IsoPath: "/isos/r.iso"}
	args, err := qemuArgs(v)
	if err != nil {
		t.Fatal(err)
	}
	joined := strings.Join(args, " ")
	for _, m := range []string{"-enable-kvm", "-machine q35,accel=kvm", "-display gtk", "zoom-to-fit=on", "show-menubar=off", "xres=1280,yres=800", "/tmp/d.qcow2", "/isos/r.iso", "user,id=net0"} {
		if !strings.Contains(joined, m) {
			t.Errorf("qemuArgs missing %q in: %s", m, joined)
		}
	}
	// boot must be driven by bootindex (CD ahead of disk), not -boot order, which
	// OVMF ignores in favour of its stale persistent NVRAM -> PXE. CD = index 1,
	// disk = index 2 so an attached installer ISO wins until it's removed.
	for _, m := range []string{"drive=disk0,bootindex=2", "drive=cd0,bootindex=1"} {
		if !strings.Contains(joined, m) {
			t.Errorf("qemuArgs missing %q (bootindex fix) in: %s", m, joined)
		}
	}
	if strings.Contains(joined, "-boot order") {
		t.Errorf("qemuArgs uses -boot order, which OVMF ignores; use bootindex: %s", joined)
	}
	// a plain VM must never get passthrough / Looking Glass devices.
	for _, bad := range []string{"vfio-pci", "ivshmem", "kvmfr", "looking-glass", "gl=on", "virtio-vga-gl"} {
		if strings.Contains(joined, bad) {
			t.Errorf("qemuArgs unexpectedly contains %q", bad)
		}
	}
}

func TestVMWantsPassthrough(t *testing.T) {
	if !vmWantsPassthrough(VM{Display: "passthrough"}) {
		t.Error("passthrough display should hand a GPU to the VM over libvirt")
	}
	for _, d := range []string{"windowed", "", "spice"} {
		if vmWantsPassthrough(VM{Display: d}) {
			t.Errorf("display %q should run as a plain QEMU window", d)
		}
	}
	// the guest OS must not decide passthrough on its own.
	if vmWantsPassthrough(VM{Guest: "windows11", Display: "windowed"}) {
		t.Error("a windowed Windows guest must run in a window, not passthrough")
	}
}

func TestPhysicalRes(t *testing.T) {
	cases := []struct {
		scale        float64
		wantW, wantH int
	}{
		{1.0, 1280, 800},
		{1.6, 2048, 1280}, // HiDPI: guest matches the window's physical pixels
		{2.0, 2560, 1600},
		{0, 1280, 800}, // a bad scale falls back to 1.0
	}
	for _, c := range cases {
		w, h := physicalRes(1280, 800, c.scale)
		if w != c.wantW || h != c.wantH {
			t.Errorf("physicalRes(1280,800,%v) = %dx%d, want %dx%d", c.scale, w, h, c.wantW, c.wantH)
		}
	}
}
