package main

import (
	"strings"
	"testing"
)

func TestKvmfrSizeMB(t *testing.T) {
	cases := []struct {
		w, h, want int
	}{
		{1920, 1080, 128}, // computed 32, floored to 128
		{2560, 1600, 128}, // computed 64, floored to 128
		{3840, 2160, 128}, // computed 128
		{7680, 2160, 256}, // computed 256 (above the floor)
		{640, 480, 128},   // tiny, floored
	}
	for _, tc := range cases {
		if got := KvmfrSizeMB(tc.w, tc.h); got != tc.want {
			t.Errorf("KvmfrSizeMB(%d,%d) = %d, want %d", tc.w, tc.h, got, tc.want)
		}
	}
}

func TestParsePCIAddr(t *testing.T) {
	a, err := parsePCIAddr("0000:01:00.0")
	if err != nil {
		t.Fatal(err)
	}
	if a.Domain != "0x0000" || a.Bus != "0x01" || a.Slot != "0x00" || a.Func != "0x0" {
		t.Errorf("parsePCIAddr = %+v", a)
	}
	if _, err := parsePCIAddr("garbage"); err == nil {
		t.Error("expected error for malformed slot")
	}
}

func TestRenderDomainWindows(t *testing.T) {
	vm := VM{
		Name: "ryoku-win11", Guest: "windows11",
		IsoPath: "/isos/win11.iso", VirtioIso: "/isos/virtio-win.iso",
		Cores: 6, RamMB: 16384, DiskPath: "/vm/win.qcow2",
	}
	xml, err := RenderDomain(vm, []string{"0000:01:00.0", "0000:01:00.1"}, 128)
	if err != nil {
		t.Fatal(err)
	}
	must := []string{
		"<name>ryoku-win11</name>",
		"<vcpu placement='static'>6</vcpu>",
		"<memory unit='MiB'>16384</memory>",
		"<hidden state='on'/>",        // KVM hidden from the guest
		"vendor_id state='on'",        // spoofed hypervisor vendor (code-43 insurance)
		"<smm state='on'/>",           // required for Secure Boot
		"<loader secure='yes'/>",      // Secure Boot OVMF
		"name='secure-boot'",          // firmware feature
		"<tpm model='tpm-crb'>",       // Win11 TPM
		"version='2.0'",               // TPM 2.0 via swtpm
		"slot='0x00' function='0x0'",  // dGPU
		"slot='0x00' function='0x1'",  // dGPU audio function
		"/isos/virtio-win.iso",        // virtio driver ISO attached
		"\"mem-path\":\"/dev/kvmfr0\"", // Looking Glass kvmfr
		"\"size\":134217728",          // 128 MiB
		"<memballoon model='none'/>",  // balloon disabled for LG perf
	}
	for _, s := range must {
		if !strings.Contains(xml, s) {
			t.Errorf("windows domain missing %q\n---\n%s", s, xml)
		}
	}
}

func TestRenderDomainLinux(t *testing.T) {
	vm := VM{
		Name: "ryoku-linux", Guest: "linux",
		IsoPath: "/isos/arch.iso", Cores: 4, RamMB: 8192, DiskPath: "/vm/lin.qcow2",
	}
	xml, err := RenderDomain(vm, []string{"0000:03:00.0"}, 256)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(xml, "<tpm") {
		t.Error("linux guest should not get a TPM")
	}
	if !strings.Contains(xml, "<loader secure='no'/>") {
		t.Error("linux guest should not require Secure Boot")
	}
	if strings.Contains(xml, "device='cdrom'") && strings.Contains(xml, "sdb") {
		t.Error("linux guest should not get the virtio-win ISO")
	}
	if !strings.Contains(xml, "slot='0x00' function='0x0'") {
		t.Error("linux domain missing the passthrough hostdev")
	}
	if !strings.Contains(xml, "\"size\":268435456") { // 256 MiB
		t.Error("linux domain missing the 256 MiB kvmfr size")
	}
}

func TestRenderDomainNoFunctions(t *testing.T) {
	if _, err := RenderDomain(VM{Name: "x"}, nil, 128); err == nil {
		t.Error("expected an error with no passthrough functions")
	}
}
