package main

import (
	"testing"
)

func TestVMDefaults(t *testing.T) {
	t.Setenv("RYOKU_CONFIG_BASE", t.TempDir())
	v := loadVM()
	if v.Name != "ryoku-win11" || v.Guest != "windows11" {
		t.Errorf("defaults = %+v", v)
	}
	if v.Cores != 4 || v.RamMB != 8192 || v.DiskGB != 64 {
		t.Errorf("default sizing = %+v", v)
	}
}

func TestVMRoundTrip(t *testing.T) {
	t.Setenv("RYOKU_CONFIG_BASE", t.TempDir())
	in := VM{
		Name: "ryoku-win11", Guest: "windows11", IsoPath: "/isos/win.iso",
		Cores: 8, RamMB: 16384, DiskPath: "/vm/d.qcow2", DiskGB: 120,
		Display: "looking-glass", GpuSlot: "0000:01:00.0",
	}
	if err := saveVM(in); err != nil {
		t.Fatal(err)
	}
	got := loadVM()
	if got.Cores != 8 || got.RamMB != 16384 || got.IsoPath != "/isos/win.iso" || got.GpuSlot != "0000:01:00.0" {
		t.Errorf("round-trip = %+v", got)
	}
}

func TestSaveVMClamps(t *testing.T) {
	t.Setenv("RYOKU_CONFIG_BASE", t.TempDir())
	if err := saveVM(VM{Name: "x", Cores: 0, RamMB: 100, DiskGB: 1}); err != nil {
		t.Fatal(err)
	}
	got := loadVM()
	if got.Cores != 1 || got.RamMB != 2048 || got.DiskGB != 16 {
		t.Errorf("clamps = cores %d ram %d disk %d", got.Cores, got.RamMB, got.DiskGB)
	}
	if got.DiskPath == "" {
		t.Error("disk path should default")
	}
}

func TestSaveVMRequiresName(t *testing.T) {
	t.Setenv("RYOKU_CONFIG_BASE", t.TempDir())
	if err := saveVM(VM{}); err == nil {
		t.Error("expected error for empty name")
	}
}
