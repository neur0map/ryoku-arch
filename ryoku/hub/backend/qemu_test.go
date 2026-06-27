package main

import (
	"strings"
	"testing"
)

func TestQemuArgs(t *testing.T) {
	t.Setenv("XDG_DATA_HOME", t.TempDir()) // contain any OVMF vars copy
	v := VM{Name: "ryoku-vm", Guest: "linux", Cores: 4, RamMB: 8192, DiskPath: "/tmp/d.qcow2", IsoPath: "/isos/r.iso"}
	args, err := qemuArgs(v)
	if err != nil {
		t.Fatal(err)
	}
	joined := strings.Join(args, " ")
	for _, m := range []string{"-enable-kvm", "-machine q35,accel=kvm", "-display gtk", "/tmp/d.qcow2", "/isos/r.iso", "user,id=net0"} {
		if !strings.Contains(joined, m) {
			t.Errorf("qemuArgs missing %q in: %s", m, joined)
		}
	}
	// a plain VM must never get passthrough / Looking Glass devices.
	for _, bad := range []string{"vfio-pci", "ivshmem", "kvmfr", "looking-glass"} {
		if strings.Contains(joined, bad) {
			t.Errorf("qemuArgs unexpectedly contains %q", bad)
		}
	}
}

func TestVMWantsPassthrough(t *testing.T) {
	if !vmWantsPassthrough(VM{Guest: "windows11"}) {
		t.Error("windows11 should pass through the dGPU")
	}
	for _, g := range []string{"linux", "other", ""} {
		if vmWantsPassthrough(VM{Guest: g}) {
			t.Errorf("guest %q should run as a plain QEMU VM", g)
		}
	}
}
